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
my $contig_id;
my $SCFchem;
my $fofn;
my $html;
my $verbose;

my $validKeys  = "organism|instance|readname|read_id|contig_id|fofn|chemistry|html|verbose|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');
 
    $readname  = shift @ARGV  if ($nextword eq '-readname');

    $read_id   = shift @ARGV  if ($nextword eq '-read_id');

    $contig_id = shift @ARGV  if ($nextword eq '-contig_id');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');

    $SCFchem   = 1            if ($nextword eq '-chemistry');

    $html      = 1            if ($nextword eq '-html');

    $verbose   = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level

my $break = $html ? "<br>" : "\n";
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

my $adb = new ArcturusDatabase(-instance => $instance,
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

$read = $adb->getReadByID($read_id) if $read_id;
push @reads, $read if $read;

undef $read;
$read = $adb->getReadByName($readname) if $readname;
push @reads, $read if $read;

if ($contig_id) {
#test construction
    my @rids = (1,2,3);
    print "get reads @rids\n";
    my $reads = $adb->getReadsByID(\@rids);
    push @reads, @$reads;
    print "Reads: @reads\n";

    $adb->getReadsForContigID($contig_id);
}


my @items = ('read_id','readname','template','ligation','insertsize','clone',
             'chemistry','SCFchemistry','strand','primer','aspeddate',
             'basecaller','lqleft','lqright','slength','sequence',
             'quality','pstatus');

$logger->warning("No reads selected") if !@reads;

foreach my $read (@reads) {
    print STDERR "$break";
    undef my %L;

    $L{read_id}    = $read->getReadID;
    $L{readname}   = $read->getReadName;

    $L{template}   = $read->getTemplate;
    $L{ligation}   = $read->getLigation;
    $L{insertsize} = $read->getInsertSize;
    $L{clone}      = $read->getClone || '';
   
    $L{chemistry}  = $read->getChemistry;
    if ($SCFchem && (my $ta = $read->getTraceArchiveIdentifier)) {
# get full chemistry from SCF file, if present
        if (!defined($rdir)) {
            my $PR = new PathogenRepository();
            $rdir = $PR->getAssemblyDirectory($organism);
            $rdir =~ s?/assembly??;
        }
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

    my $sequence   = $read->getSequence;
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

# finally, comments, if any

    undef my $comment;
    if (my $comments = $read->getComment()) {
        foreach my $comment (@$comments) {
            printf ("%12s  %-20s  ",'comment',$comment);
            print $break;
        }
    }
}

exit;

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
print "chemistry: recovery activated$break" unless $chemistry;
    $chemistry = `/nfs/pathsoft/arcturus/dev/cgi-bin/orecover.sh $command` unless $chemistry;

    if ($chemistry =~ /.*\sDYEP\s*\=\s*(\S+)\s/) {
        $chemistry = $1;
        if ($chemistry =~ /Tag/) {
            undef $chemistry; # triggered by "Tag not present"
        }
    }
    else {
        undef $chemistry;
    }

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
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-fofn\t\tfilename with list of readnames to be included\n";
    print STDERR "-filter\t\tprocess only those readnames matching pattern or substring\n";
    print STDERR "-readnamelike\t  idem\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}












