#!/usr/local/bin/perl -w

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


use strict;

use ArcturusDatabase;

use FileHandle;
use Logging;
use PathogenRepository;

#use Hexify qw(Hexify);

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $readname;
my $read_id;
my $seq_id;
my $version;
my $unassembled;
my $SCFchem;
my $caf;
my $fasta;
my $fastq;
my $quality;
my $mask;
my $clip;
my $screen;
my $fofn;
my $verbose;
my $notags;
my $debug;
my $full;
my $all;

my $validKeys  = "organism|o|instance|i|readname|read_id|seq_id|version|".
                 "unassembled|fofn|chemistry|caf|fasta|quality|fastq|full|all|".
                 "clip|mask|screen|notags|verbose|debug|help|h";

while (defined(my $nextword = shift @ARGV)) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                         
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }  
 
    $readname    = shift @ARGV  if ($nextword eq '-readname');

    $read_id     = shift @ARGV  if ($nextword eq '-read_id');

    $seq_id      = shift @ARGV  if ($nextword eq '-seq_id');

    $version     = shift @ARGV  if ($nextword eq '-version');

    $unassembled = 1            if ($nextword eq '-unassembled');

    $fofn        = shift @ARGV  if ($nextword eq '-fofn');

    $SCFchem     = 1            if ($nextword eq '-chemistry');

    $mask        = shift @ARGV  if ($nextword eq '-mask');

    $clip        = shift @ARGV  if ($nextword eq '-clip');

    $screen      = 1            if ($nextword eq '-screen');

    $fasta       = 1            if ($nextword eq '-fasta');

    $fastq       = 1            if ($nextword eq '-fastq');

    $caf         = 1            if ($nextword eq '-caf');

    $full        = 1            if ($nextword eq '-full');

    $all         = 1            if ($nextword eq '-all');

    $quality     = 1            if ($nextword eq '-quality');

    $notags      = 1            if ($nextword eq '-notags');

    $verbose     = 1            if ($nextword eq '-verbose');

    $debug       = 1            if ($nextword eq '-debug');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

$SCFchem = 0 if ($fasta || $caf || $fastq);
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level

$logger->setDebugStream('STDOUT',list=>1) if $debug; 

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism eq 'default' || $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message

    &showUsage("Missing organism database") unless $organism;

    &showUsage("Missing database instance") unless $instance;

    &showUsage("Organism '$organism' not found on server '$instance'");
}

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection
 
my $URL = $adb->getURL;

$adb->setLogger($logger);

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------

$fofn = &getNamesFromFile($fofn) if $fofn;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $rdir;
my @reads;

my %options;
$options{seq_id}   = $seq_id    if defined($seq_id);
$options{read_id}  = $read_id   if defined($read_id);
$options{readname} = $readname  if defined($readname);
$options{version}  = $version   if defined($version);

my $read;
if (defined($seq_id) || defined($read_id) || defined($readname)) {
    $read = $adb->getRead(%options);
    push @reads, $read if $read;
}

if ($fofn) {
    $version = 0 unless defined($version);
    foreach my $rid (@$fofn) {
        $read = $adb->getReadByName  ($rid,$version) if ($rid =~ /\D/);
        $read = $adb->getReadByReadID($rid,$version) if ($rid !~ /\D/);
        push @reads, $read if $read;
    }
}

if ($unassembled) {
    my $readids = $adb->getIDsForUnassembledReads();

    if ($caf || $fasta) {
        my $reads = $adb->getReadsByReadID($readids);
        $adb->getSequenceForReads($reads);
        push @reads, @$reads;
    }
    else {
# list read IDs only
        print "Reads: @$readids\n";
    }
}

# full listing

my @items = ('read_id','readname','seq_id','version',
             'template','ligation','insertsize','clone',
             'chemistry','SCFchemistry','strand','primer','aspeddate',
             'basecaller','lqleft','lqright','slength','qlength','sequence',
             'shash','quality','qhash','align-to-SCF','traceserver','pstatus');

if (@reads) {
    $adb->getTagsForReads([@reads]) unless $notags;
}
else {
    $logger->warning("No reads selected",ss=>1);
}

my %option;
$option{qualitymask} = $mask if $mask;
$option{all} = 1 if $all;

foreach my $read (@reads) {

    $read->qualityClip(threshold=>$clip) if ($clip && $clip > 0);

    $read->vectorScreen() if $screen; # after quality clip!

    $read->writeToCaf(*STDOUT,%option) if $caf;

    $read->writeToFastq(*STDOUT,%option) if $fastq;

    $read->writeToFasta(*STDOUT,*STDOUT,%option) if ($fasta && $quality);

    $read->writeToFasta(*STDOUT,undef,%option)  if ($fasta && !$quality);

    next if ($caf || $fasta || $fastq);

    if ($full || $SCFchem && !defined($rdir)) {
        my $PR = new PathogenRepository();
        $rdir = $PR->getAssemblyDirectory($organism);
        $rdir =~ s?/assembly??;
        $logger->info("Assembly directory: $rdir");
    }

    &list($read,$rdir,%option);
 
}

$adb->disconnect();

exit;

#--------------------------------------------------------------------------

sub list {
    my $read = shift;
    my $rdir = shift; # if rdir defined, do full chemistry
    my %options = @_;

    my $break = "\n";

    undef my %L;

    $L{read_id}    = $read->getReadID;
    $L{readname}   = $read->getReadName;
    $L{seq_id}     = $read->getSequenceID;
    $L{version}    = $read->getVersion;

    $L{template}   = $read->getTemplate;
    $L{ligation}   = $read->getLigation;
    $L{insertsize} = $read->getInsertSize;
    $L{clone}      = $read->getClone || '';
   
    $L{chemistry}  = $read->getChemistry;
    my $ta = $read->getTraceArchiveIdentifier(asis=>1); # list info as in db
    $ta =~ s/\~\w+\/// if $ta; # remove possibly added ~name
    $L{traceserver} = $ta;
    if ($rdir && $ta) {
# get full chemistry from SCF file, if present
        $L{SCFchemistry} = &SCFchemistry($rdir,$ta);
    }
    $L{strand}     = $read->getStrand;
    $L{primer}     = $read->getPrimer;

    $L{aspeddate}  = $read->getAspedDate;
    $L{basecaller} = $read->getBaseCaller;
    $L{lqleft}     = $read->getLowQualityLeft;
    $L{lqright}    = $read->getLowQualityRight;

# sequence hashes

    $L{shash}      = &Hexify($read->getSequenceHash());
    $L{qhash}      = &Hexify($read->getBaseQualityHash());

# list section until now

    foreach my $item (@items) {
        my $value = $L{$item};
        next unless (defined ($value) || $options{all});
        printf ("%12s  ",$item);
        if (ref($value) eq 'ARRAY') {
            print "@$value".$break;
        }
        elsif (defined($value)) {
            print $value.$break;
	}
        else {
            print $break;
        }
    }     

    my $cvdata     = $read->getCloningVector;
    if ($cvdata && @$cvdata) {
        foreach my $cvd (@$cvdata) {
            printf ("%12s  %-20s  ",'cvector',$cvd->[0]);
            printf ("%6s  %5d    ",'cvleft' ,$cvd->[1]);
            printf ("%6s  %5d \n",'cvright',$cvd->[2]);
        }
    }
    else {
        printf ("%12s \n",'cvector');
    }

    my $svdata     = $read->getSequencingVector;
    if ($svdata && @$svdata) {
        foreach my $svd (@$svdata) {
            printf ("%12s  %-20s  ",'svector',$svd->[0]);
            printf ("%6s  %5d    ",'svleft' ,$svd->[1]);
            printf ("%6s  %5d \n",'svright',$svd->[2]);
        }
    }
    else {
        printf ("%12s  %-20s \n",'svector','UNKNOWN');
    }

    undef %L;

    my $sequence   = $read->getSequence(@_);
# output in blocks of 60 characters
    if (defined($sequence)) {
        $sequence =~ s/(.{60})/$1$break              /g;
        $L{sequence} = $sequence;
        $L{slength} = length($sequence);
    }

    my $quality    = $read->getBaseQuality;
    if (defined($quality)) {
        $L{quality} = '';
# output in lines of 20 numbers
        my $nl = 25;
	my @bq = @{$quality};
        $L{qlength} = scalar(@bq);
	while (my $n = scalar(@bq)) {
            my $m = ($n > ($nl-1)) ? ($nl-1) : $n-1;
            $L{quality} .= $break.'              ' if $L{quality};
	    $L{quality} .= join(' ',@bq[0..$m]);
	    @bq = @bq[$nl..($n-1)];
	}
        $L{quality} =~ s/\b(\d)\b/ $1/g;
    }
    $L{slength}    = $read->getSequenceLength;

    $L{pstatus}    = $read->getProcessStatus || '';

    foreach my $item (@items) {
        my $value = $L{$item};
        next unless defined $value;
        printf ("%12s  ",$item);
        print $value.$break;
    }

# align to scf records

    my $aligns = $read->getAlignToTrace();
    if ($aligns && scalar(@$aligns) > 0) {
        print "\nAlign_to_SCF records:\n";
        foreach my $align (@$aligns) {
            printf (" %4d - %4d     %4d - %4d $break",@$align);
        }
    }
    elsif (my $a2tmap = $read->getAlignToTraceMapping()) {
        print " ".$a2tmap->writeToString('Align_to_SCF');
    }

# finally, comments, if any

    if (my $comments = $read->getComment()) {
        foreach my $comment (@$comments) {
            printf ("%12s  %-20s  ",'comment',$comment);
            print $break;
        }
    }
}

#------------------------------------------------------------------------
# parse trace file information for full chemistry information
#------------------------------------------------------------------------

sub SCFchemistry {
# returns chemistry found in trace file
    my $root = shift;
    my $file = shift;

    my $SCFfile = "$root/$file";

    return undef unless (-e $SCFfile);

    my $test = 0;
    my $command = "/usr/local/badger/distrib-1999.0/alpha-bin/get_scf_field $SCFfile";

    my $chemistry = `$command`;

#print "Chemistry $chemistry\n";

    if ($chemistry =~ /.*\sDYEP\s*\=\s*(\S+)\s/) {
        $chemistry = $1;
        if ($chemistry =~ /Tag/) {
            $chemistry = "Not present"; # triggered by "Tag not present"
        }
    }
    else {
        $chemistry = "Not accessible";
    }
    $chemistry .= "   ($SCFfile)";

    return $chemistry;
}

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------

sub Hexify {

    use bytes;
    # First argument: data or reference to the data.
    my $data = shift;

    return '' unless defined $data;

    my $dr = ref($data) ? $data : \$data;

    my $start  = 0;             # first byte to dump
    my $lastplusone = length($$dr); # first byte not to dump
    my $align  = 1;             # align
    my $chunk  = 16;            # bytes per line
    my $first  = $start;        # number of 1st byte
    my $dups   = 0;             # output identical lines
    my $group  = 1;             # group per # bytes

    my $show   = sub { my $t = shift;
                       $t =~ tr /\000-\037\177-\377/./;
                       $t;
                 };

    # Check for second argument.
    if ( @_ ) {

        # Second argument: options hash or hashref.
        my %atts = ( align      => $align,
                     chunk      => $chunk,
                     showdata   => $show,
                     start      => $start,
                     length     => $lastplusone - $start,
                     duplicates => $dups,
                     first      => undef,
                     group      => 1,
                   );

        if ( @_ == 1 ) {        # hash ref
            my $a = shift;
#            croak($usage) unless ref($a) eq 'HASH';
            %atts = ( %atts, %$a );
        }
        elsif ( @_ % 2 ) {      # odd
#            croak($usage);
        }
        else {                  # assume hash
            %atts = ( %atts, @_ );
        }

        my $length;
        $start  = delete($atts{start});
        $length = delete($atts{length});
        $align  = delete($atts{align});
        $chunk  = delete($atts{chunk});
        $show   = delete($atts{showdata});
        $dups   = delete($atts{duplicates});
        $group  = delete($atts{group});
        $first  = defined($atts{first}) ? $atts{first}  : $start;
        delete($atts{first});

        if ( %atts ) {
            croak("Hexify: unrecognized options: ".
                  join(" ", sort(keys(%atts))));
        }

        # Sanity
        $start = 0 if $start < 0;
        $lastplusone = $start + $length;
        $lastplusone = length($$dr)
          if $lastplusone > length($$dr);
        $chunk = 16 if $chunk <= 0;
        if ( $chunk % $group ) {
            croak("Hexify: chunk ($chunk) must be a multiple of group ($group)");
        }
    }
    $group *= 2;

    #my $fmt = "  %04x: %-" . (3 * $chunk - 1) . "s  %-" . $chunk . "s\n";
    my $fmt = "  %04x: %-" . (2*$chunk + $chunk/($group/2) - 1) . "s  %-" . $chunk . "s\n";
    my $ret = "";

    if ( $align && (my $r = $first % $chunk) ) {
        # This piece of code can be merged into the main loop.
        # However, this piece is only executed infrequently.
        my $lead = " " x $r;
        my $firstn = $chunk - $r;
        $first -= $r;
        my $n = $lastplusone - $start;
        $n = $firstn if $n > $firstn;
        my $ss = substr($$dr, $start, $n);
        (my $hex = $lead . $lead . unpack("H*",$ss)) =~ s/(.{$group})(?!$)/$1 /g;
        $ret .= sprintf($fmt, $first, $hex,
                        $lead . $show->($ss));
        $start += $n;
        $first += $chunk;
    }

    my $same = "";
    my $didsame = 0;
    my $dupline = "          |\n";

    while ( $start < $lastplusone ) {
        my $n = $lastplusone - $start;
        $n = $chunk if $n > $chunk;
        my $ss = substr($$dr, $start, $n);

        if ( !$dups ) {
            if ( $ss eq $same && ($start + $n) < $lastplusone ) {
                if ( !$didsame ) {
                    $ret .= $dupline;
                    $same = $ss;
                    $didsame = 1;
                }
                next;
            }
            else {
                $same = "";
                $didsame = 0;
            }
        }
        $same = $ss;

        (my $hex = unpack("H*", $ss)) =~ s/(.{$group})(?!$)/$1 /g;
        $ret .= sprintf($fmt, $first, $hex, $show->($ss));
    }
    continue {
        $start += $chunk;
        $first += $chunk;
    }

    $ret;
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' (default) or 'dev'\n";
    print STDERR "-readname\tRead name\n";
    print STDERR "-fofn\t\tfilename with list of readnames\n";
    print STDERR "-read_id\tRead ID\n";
    print STDERR "-seq_id\t\tSequence ID\n";
    print STDERR "-unassembled\t(no value) Specify -caf or -fasta,".
                 " else only list reads\n";
    print STDERR "-mask\t\tMask low quality data with the symbol provided\n";
    print STDERR "-clip\t\tGet quality boundaries for given clip level\n";
    print STDERR "-screen\t\tAdjust quality boundaries for vector sequence\n";
    print STDERR "\n";
    print STDERR "-chemistry\t(no value) Extended chemistry information".
                 " (slow, not with -caf or -fasta)\n";
    print STDERR "\n";
    print STDERR "-caf\t\t(no value) Output in caf format\n";
    print STDERR "-fasta\t\t(no value) Output in fasta format\n";
    print STDERR "-quality\t(no value, with '-fasta') include quality values\n";
    print STDERR "-fastq\t\t(no value) Output in fasta format\n";
    print STDERR "\t\t(ALL output on STDOUT only)\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
