#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase::ADBRead;

use FileHandle;
use Logging;
use PathogenRepository;

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
my $mask;
my $fofn;
my $verbose;

my $validKeys  = "organism|instance|readname|read_id|seq_id|".
                 "unassembled|fofn|chemistry|caf|fasta|".
                 "mask|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance    = shift @ARGV  if ($nextword eq '-instance');
      
    $organism    = shift @ARGV  if ($nextword eq '-organism');
 
    $readname    = shift @ARGV  if ($nextword eq '-readname');

    $read_id     = shift @ARGV  if ($nextword eq '-read_id');

    $seq_id      = shift @ARGV  if ($nextword eq '-seq_id');

    $version     = shift @ARGV  if ($nextword eq '-version');

    $unassembled = 1            if ($nextword eq '-unassembled');

    $fofn        = shift @ARGV  if ($nextword eq '-fofn');

    $SCFchem     = 1            if ($nextword eq '-chemistry');

    $mask        = shift @ARGV  if ($nextword eq '-mask');

    $fasta       = 1            if ($nextword eq '-fasta');

    $caf         = 1            if ($nextword eq '-caf');

    $verbose     = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}

$SCFchem = 0 if ($fasta || $caf);
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level

my $break = "\n";
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

my $adb = new ADBRead(-instance => $instance,
		      -organism => $organism);

if ($adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------

$fofn = &getNamesFromFile($fofn) if $fofn;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $rdir;
my $read;
my @reads;

$version = 0 unless defined($version);

$read = $adb->getRead(read_id=>$read_id, version=>$version) if $read_id;
push @reads, $read if $read;

undef $read;
$read = $adb->getReadByName($readname, $version) if $readname;
push @reads, $read if $read;

undef $read;
$read = $adb->getReadBySequenceID($seq_id) if $seq_id;
push @reads, $read if $read;

if ($fofn) {
    foreach my $name (@$fofn) {
        $read = $adb->getReadByName($name,0);
        push @reads, $read if $read;
    }
}


if ($unassembled) {

    my $readids = $adb->getUnassembledReads();

    if ($caf || $fasta) {
        my $reads = $adb->getReadsByReadID($readids);
        $adb->getSequenceForReads($reads);
        push @reads, @$reads;
    }
    else {
# list read IDs only
        print "Reads: @$readids\n";
#        exit 0;
    }
}


my @items = ('read_id','readname','seq_id','version',
             'template','ligation','insertsize','clone',
             'chemistry','SCFchemistry','strand','primer','aspeddate',
             'basecaller','lqleft','lqright','slength','sequence',
             'quality','align-to-SCF','pstatus');

$logger->warning("No reads selected") if !@reads;

my %option;
$option{qualitymask} = $mask if $mask;

foreach my $read (@reads) {

    $read->writeToCaf(*STDOUT,%option) if $caf;

    $read->writeToFasta(*STDOUT,*STDOUT,%option) if $fasta;

    next if ($caf || $fasta);

    if ($SCFchem && !defined($rdir)) {
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
    if ($rdir && (my $ta = $read->getTraceArchiveIdentifier)) {
# get full chemistry from SCF file, if present
        $ta =~ s/\~\w+\///; # remove possibly added ~name
        $L{SCFchemistry} = &SCFchemistry($rdir,$ta);
    }
    $L{strand}     = $read->getStrand;
    $L{primer}     = $read->getPrimer;

    $L{aspeddate}  = $read->getAspedDate;
    $L{basecaller} = $read->getBaseCaller;
    $L{lqleft}     = $read->getLowQualityLeft;
    $L{lqright}    = $read->getLowQualityRight;

# list section until now

    foreach my $item (@items) {
        my $value = $L{$item};
        next unless defined $value;
        printf ("%12s  ",$item);
        if (ref($value) eq 'ARRAY') {
            print "@$value".$break;
        }
        else {
            print $value.$break;
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
    }

    my $quality    = $read->getQuality;
    if (defined($quality)) {
        $L{quality} = '';
# output in lines of 20 numbers
        my $nl = 25;
	my @bq = @{$quality};
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
    if ($aligns && scalar(@$aligns) > 1) {
        foreach my $align (@$aligns) {
            printf ("%12s  %4d - %4d     %4d - %4d $break",@$aligns);
        }
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

sub readNamesFromFile {
    my $file = shift; # file name

    &showUsage(0,"File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage(0,"Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

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
    print STDERR "-chemistry\t(no value) Extended chemistry information".
                 " (slow, not with -caf or -fasta)\n";
    print STDERR "-caf\t\t(no value) Output in caf format\n";
    print STDERR "-fasta\t\t(no value) Output in fasta format\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
