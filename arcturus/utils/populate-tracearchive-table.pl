#!/usr/local/bin/perl -w

#----------------------------------------------------------------
# Script to populate TRACEARCHIVE table 
# Uses trace files in experiment directory for Sanger reads
#----------------------------------------------------------------

use strict;

use ArcturusDatabase::ADBRead;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $verbose;
my $subdir;
my $filter;
my $limit;
my $inspect;

my $validKeys  = "organism|instance|limit|subdir|filter|verbose|inspect|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $subdir    = shift @ARGV  if ($nextword eq '-subdir');

    $filter    = shift @ARGV  if ($nextword eq '-filter');

    $limit     = shift @ARGV  if ($nextword eq '-limit');
 
    $verbose   = 1            if ($nextword eq '-verbose');
 
    $inspect   = 1            if ($nextword eq '-inspect');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

my $adb = new ADBRead (-instance => $instance,
		       -organism => $organism);

if ($adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------
     
# get root directory

$logger->info("Finding repository root directory");
my $PR = new PathogenRepository();
my $rootdir = $PR->getAssemblyDirectory($organism);
if ($rootdir) {
    $rootdir =~ s?/assembly??;
    $logger->warning("Repository found at: $rootdir" );
}
else {
    $logger->severe("Failed to determine root directory .. ");
    exit;
}
  
# get all readids without tracearchive reference (and sanger style name)

my $ntr = $inspect ? 0 : 1;
my $names = $adb->getListOfReadNames(noTraceRef=>$ntr, onlySanger=>1);
my $nr = scalar(@$names);
$logger->warning("$nr readnames to be processed found in database $organism");

exit unless $nr; 
 
my %include;
foreach my $name (@$names) {
    $include{"${name}SCF"}++ if ($name =~ /\./); # accept Sanger names only
} 

# find the files in the experiment directory

my $accepted = &expSCFFileFinder($rootdir,$subdir,$limit,\%include,$filter);

my $added = 0;
foreach my $scffile (sort keys %$accepted) {
    my $readname = $scffile;
    $readname =~ s/SCF//;
    $logger->info("adding $readname $accepted->{$scffile}");
    if (my $read = $adb->getReadByName($readname)) {
        $read->setTraceArchiveIdentifier($accepted->{$scffile});
        next if $inspect; # no loading
        my ($s,$t) = $adb->putTraceArchiveIdentifierForRead($read);
        $logger->severe($t) unless $s;
        $added++ if $s;
    }
    else {
        $logger->severe("Could not retrieve read $readname");
    }
}

$logger->warning("$added trace file references added");

exit;
 
#------------------------------------------------------------
# scan directories and build list of exp file names 
#------------------------------------------------------------

sub expSCFFileFinder {

    my $root    = shift;
    my $subdir  = shift; # subdirectory (filter)
    my $limit   = shift || 10000;
    my $include = shift;
    my $filter  = shift; # filename filter

# set up a list of directories to scan for files

    my @dirs;
    $logger->info("Scanning root directory $root");
    if (opendir ROOT, $root) {
        $subdir = "0" unless defined($subdir);
        my @files = readdir ROOT;
        foreach my $file (@files) {
            next unless (-d "$root/$file");
            next unless ($file =~ /\w*$subdir\w*/);
            push @dirs, $file;
        }
        closedir ROOT;
    }
    else {
        $logger->severe("Failed to open directory $root");
    }

    $logger->severe("No (sub)directories matching description") unless @dirs;

# go through each directory in turn to collect files that look like exp files

    my $counted = 0;
    my %accepted;
    foreach my $subdir (@dirs) {
        my $dir = "$root/$subdir";
	$logger->info("Scanning directory $dir");
        if (opendir DIR, $dir) {
            my @files = readdir DIR;
            foreach my $file (@files) {
                last if ($counted >= $limit);
                next if ($file !~ /SCF$/);
                next if (-d $file);
                next if ($filter && $file !~ /\w*$filter\w*/);
# accept the file if it is in the include list; else do Sanger format test
                if ($include && defined($include->{$file})) {
                    $accepted{$file} = "$subdir/$file";
                    $counted++;
                }
                elsif ($include) {
                    next;
                }
                elsif ($file =~ /[\w\-]+\.[a-z]\d[a-z]\w*/) {
                    $accepted{$file} = "$subdir/$file";
                    $counted++;
                }
            }
            closedir DIR;
            last unless ($counted < $limit);
        }               
        else {
            $logger->warning("Failed to open directory $dir");
        }
    }
    return \%accepted;
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
    print STDERR "-subdir\t\tsubdirectory filter\n";
    print STDERR "-filter\t\tfilename filter\n";
    print STDERR "-limit\t\tmaximum number of entries to be processed\n";
    print STDERR "-inspect\t(no value) test mode\n";
    print STDERR "-verbose\t(no value)\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
