#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

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
my $quality;
my $mask;
my $clip;
my $screen;
my $fofn;
my $verbose;
my $notags;

my $validKeys  = "organism|o|instance|i|readname|read_id|seq_id|version|".
                 "unassembled|fofn|chemistry|caf|fasta|quality|".
                 "clip|mask|screen|notags|verbose|help|h";

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

    $caf         = 1            if ($nextword eq '-caf');

    $quality     = 1            if ($nextword eq '-quality');

    $notags      = 1            if ($nextword eq '-notags');

    $verbose     = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

$SCFchem = 0 if ($fasta || $caf);
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
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


my @items = ('read_id','readname','seq_id','version',
             'template','ligation','insertsize','clone',
             'chemistry','SCFchemistry','strand','primer','aspeddate',
             'basecaller','lqleft','lqright','slength','sequence',
             'quality','align-to-SCF','pstatus');

if (@reads) {
    $adb->getTagsForReads([@reads]) unless $notags;
}
else {
    $logger->warning("No reads selected",ss=>1);
}

my %option;
$option{qualitymask} = $mask if $mask;

foreach my $read (@reads) {

    $read->qualityClip(threshold=>$clip) if ($clip && $clip > 0);

    $read->vectorScreen() if $screen; # after quality clip!

    $read->writeToCaf(*STDOUT,%option) if $caf;

    $read->writeToFasta(*STDOUT,*STDOUT,%option) if ($fasta && $quality);

    $read->writeToFasta(*STDOUT,undef,%option)  if ($fasta && !$quality);

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

    my $quality    = $read->getBaseQuality;
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
        print "\nAlign_to_SCF records:\n";
        foreach my $align (@$aligns) {
            printf (" %4d - %4d     %4d - %4d $break",@$align);
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
    print STDERR "\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
