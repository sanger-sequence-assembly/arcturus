#!/usr/local/bin/perl -w

use strict;

use FileHandle;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# variable definitions
#----------------------------------------------------------------

my ($organism,$instance);

my ($project,$assembly,$templateproject,$templateassembly, $ignore,$lock); # arcturus contig data

$project = 'all'; # default
$ignore  = 'PROBLEMS';

my ($nomask,$namelike,$namenotlike,$aspedbefore,$aspedafter); # read data

my ($minmatch,$minscore,$masklevel,$penalty,$noraw); # cross match params

$minmatch  = 50;    # 30 to 50  preselects matches of at least this size kmer
$minscore  = 100;   # 50 to 100 for standard scoring matrix 
$masklevel = 100;   # alternative: 0 
$penalty   = -3;    # conside changing penalty insert from -3 to -5

my ($contig,$testread,$caffile,$confirm); # assembler params

my ($fuzz, $partial, $nosingle, $ftest); # crossmatch output filtering

my $filterdomain; # read placement

my ($renew,$verbose,$debug); # control

#----------------------------------------------------------------
# parse command line parameters
#----------------------------------------------------------------

my $validKeys  = "organism|o|instance|i|"
               . "project|p|assembly|a|"
               . "templateproject|tp|templateassembly|ta|"
               . "lock|ignore|"
               . "minmatch|mm|minscore|ms|masklevel|ml|" # crossmatch control
               . "fuzz|partial|filtertest|ft|multiplematchesonly|mmo|fd|filterdomain|" # cm output filter
               . "contig|read|caf|" # test options and output
               . "refresh|confirm|verbose|info|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                          
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism  = shift @ARGV;
    }

    if ($nextword eq '-project'  || $nextword eq '-p') {
        $project   = shift @ARGV;
        die "Missing project identifier" unless defined($project);
    }

    if ($nextword eq '-assembly' || $nextword eq '-a') {
        $assembly  = shift @ARGV;
        die "Missing assembly identifier" unless defined($assembly);
    }

    if ($nextword eq '-tp'  || $nextword eq '-templateproject') {
        $templateproject  = shift @ARGV;
        die "Missing template project identifier" unless defined($templateproject);
    }

    if ($nextword eq '-ta' || $nextword eq '-templateassembly') {
        $templateassembly  = shift @ARGV;
        die "Missing assembly identifier" unless defined($templateassembly);
    }

    $lock          = 1            if ($nextword eq '-lock');

    $ignore        = shift @ARGV  if ($nextword eq '-ignore');

# renew (build from scratch) option

    $renew         = 1            if ($nextword eq '-refresh');

# crossmatch parameters

    if ($nextword eq '-minmatch'  || $nextword eq '-mm') {
        $minmatch  = shift @ARGV;
    }

    if ($nextword eq '-minscore'  || $nextword eq '-ms') {
        $minscore  = shift @ARGV;
    }

    if ($nextword eq '-masklevel' || $nextword eq '-ml') {
        $masklevel = shift @ARGV;
        $masklevel = 0 unless ($masklevel > 0);
    }

    $noraw         = 1            if ($nextword eq '-noraw');

# filtering options
    
    $fuzz          = shift @ARGV  if ($nextword eq '-fuzz');

    $partial       = 1            if ($nextword eq '-partial');

    if ($nextword eq '-multiplematchesonly' || $nextword eq '-mmo') {
        $nosingle  = 1;
    }          

    if ($nextword eq '-filterdomain'        || $nextword eq '-fd') {
        $filterdomain = 1;
    }
  
# test options

    if ($nextword eq '-filtertest'  || $nextword eq '-ft') {
        $ftest     = shift @ARGV;
        $ftest     = 1 unless defined $ftest;
    }

    $contig        = shift @ARGV  if ($nextword eq '-contig');
    $testread      = shift @ARGV  if ($nextword eq '-read');
    $caffile       = shift @ARGV  if ($nextword eq '-caf');

#

    $confirm       = 1            if ($nextword eq '-confirm');

# reporting

    $verbose       = 1            if ($nextword eq '-verbose'); 
    $verbose       = 2            if ($nextword eq '-info'); 
    $debug         = 1            if ($nextword eq '-debug'); 

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardFilter(1) if $verbose; # reporting level

$logger->setBlock('debug',unblock=>1) if $debug;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism && $organism eq 'default' || 
    $instance && $instance eq 'default') {
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

#---------------

my $projectfasta     = "/tmp/$organism.p.fas";  # for projects to be tested
my $projectquality   = "/tmp/$organism.p.qual";
my $templatefasta    = "/tmp/$organism.t.fas";  # for projects tested against
my $templatequality  = "/tmp/$organism.t.qual";
my $xmatchoutput     = "/tmp/$organism.crossmatch";
my $xmatchfilter     = "/tmp/$organism.crossmatchfilter";

if ($project !~ /\,/) {
    $xmatchoutput =~ s/cross/${project}.cross/;
    $xmatchfilter =~ s/cross/${project}.cross/;
}

if ($templateproject !~ /\,/) {
    $xmatchoutput =~ s/cross/${templateproject}.cross/;
    $xmatchfilter =~ s/cross/${templateproject}.cross/;
}

my $arcturus_root = "/software/arcturus";

#------------------------------------------------------------------------------
# 1 : export the projects to be tested
#------------------------------------------------------------------------------

unless (-f $projectfasta && !$renew) {

    &mySystem("rm -f ${projectfasta}*") if (-f $projectfasta);

    my $command = "$arcturus_root/utils/project-export "
                . "-organism $organism -instance $instance "
                . "-fasta $projectfasta "
                . "-gap4name -qc ";
    $command   .= "-project $project "        if $project;
    $command   .= "-ignore $ignore "          if $ignore;
    $command   .= "-lock "                    if $lock;
    $command   .= "-verbose"                  if $verbose;

    $logger->warning("exporting test contigs to $projectfasta",ss=>1);
    $logger->info($command,skip=>1);

    exit 1 if &mySystem($command);
}

#------------------------------------------------------------------------------
# 2 : export all or selected template contigs as fasta file
#------------------------------------------------------------------------------

unless ( -f $templatefasta && !$renew) {

    my $exclude = $ignore;
    $exclude .= ',' if $exclude;
    $exclude .= $project;

    my $command = "$arcturus_root/utils/project-export "
                . "-organism $organism -instance $instance "
                . "-fasta $templatefasta "
                . "-gap4name -qc ";
    $command   .= "-project $templateproject " if $templateproject;
    $command   .= "-ignore $exclude "          if $exclude;
    $command   .= "-lock "                     if $lock;
    $command   .= "-verbose"                   if $verbose;

    $logger->warning("exporting template contigs to $templatefasta",ss=>1);
    $logger->info($command,skip=>1);

    exit 1 if &mySystem($command);
}

#------------------------------------------------------------------------------
# 3 : run crossmatch to get cross.lis file
#------------------------------------------------------------------------------

unless (-f $xmatchoutput && !$renew) {

    &mySystem("rm -f $xmatchoutput") if (-f $xmatchoutput);

    my $command = "cross_match $templatefasta $projectfasta "
                . "-minmatch $minmatch -minscore $minscore "
                . "-masklevel  $masklevel -discrep_lists ";
    $command   .= "-raw" unless $noraw;
    $command   .= "> $xmatchoutput ";

    $logger->warning("cross matching contigs and reads",ss=>1);
    $logger->info($command,skip=>1);

    if (&mySystem($command)) {
	&mySystem("rm -f $xmatchoutput");
        exit 1;
    }
}

#------------------------------------------------------------------------------
# 4 : run xmatch-segments filter on xmatchoutput file
#------------------------------------------------------------------------------

unless ((-f $xmatchfilter && ! -z $xmatchfilter) && !$ftest) {
#unless ((-f $xmatchfilter && ! -z $xmatchfilter) && !$renew && !$ftest) {

    &mySystem("rm -f $xmatchfilter") if (-f $xmatchfilter);

    my $command = "$arcturus_root/utils/xmatch-filter "
    	        . "-in  $xmatchoutput "
                . "-out $xmatchfilter ";
    $command   .= "-fuzz $fuzz "  if $fuzz;
    $command   .= "-partials 1 "  if $partial;
    $command   .= "-test $ftest " if $ftest;
    $command   .= "-nosingle 1"   if $nosingle; # only multiple matches

    $logger->warning("filtering cross-match output",ss=>1);
    $logger->info($command,skip=>1);

    if (&mySystem($command)) {
	&mySystem("rm -f $xmatchfilter");
        exit;
    }
}

exit 0 if $ftest;

#------------------------------------------------------------------------------
# 5 : run directed-read-assembler.pl
#------------------------------------------------------------------------------

exit 0;

#------------------------------------------------------------------------------

sub mySystem {
     my ($cmd) = @_;

     my $res = 0xffff & system($cmd);
     return 0 if ($res == 0);

     printf STDERR "system(%s) returned %#04x: ", $cmd, $res;

     if ($res == 0xff00) {
         print STDERR "command failed: $!\n";
         return 1;
     } 
     elsif ($res > 0x80) {
         $res = 8;
         print STDERR "exited with non-zero status $res\n";
     }
     else {
         my $sig = $res & 0x7f;
         print STDERR "exited through signal $sig";
         if ($res & 0x80) {print STDERR " (core dumped)"; }
         print STDERR "\n";
     }
     return 2;
}

#------------------------------------------------------------------------------

sub showUsage {
    my $text = shift;

    print STDERR "\n";
    print STDERR "Assemble selected reads into existing contig in a 7 step process\n";
    print STDERR "\n";
    print STDERR "1 : get (selected) contigs from database in fasta format\n";
    print STDERR "2 : get (selected) free reads from database in fasta format\n";
    print STDERR "     by default low quality sequence is masked with 'x'\n";
    print STDERR "3 : cross_match these data sets against each other\n";
    print STDERR "4 : filter the cross-match output to obtain a list of read placings\n";
    print STDERR "\n";
    print STDERR "Intermediate results from each step are stored in /tmp\n";
    print STDERR "Existing intermediate results are used on re-running this script\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $text \n" if $text;
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus organism database\n" unless $organism;
        print STDERR "-instance\tArcturus database instance\n" unless $instance;
        print STDERR "\n";
    }
    print STDERR "OPTIONAL PARAMETERS for contig selection:\n";
    print STDERR "\n";
    print STDERR "-p\t\t(project) project, or c-s list of projects, with test contigs\n";
    print STDERR "-a\t\t(assembly:1) assembly, required in case of ambiguity\n";
    print STDERR "-tp\t\t(templateproject:ALL) project, or c-s list, with test contigs\n";
    print STDERR "-ta\t\t(templateassembly:1) assembly, required in case of ambiguity\n";
    print STDERR "-ignore\t\t(:PROBLEMS) comma-separated list of projects to ignore\n";
    print STDERR "-lock\t\tAcquire lock on project(s); ignore already locked ones\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for crossmatch control (re: man cross_match):\n";
    print STDERR "\n";
    print STDERR "-minmatch\t(mm:50)\n";
    print STDERR "-minscore\t(ms:100)\n";
    print STDERR "-masklevel\t(ml:100) 0, 100 or 101\n";
#    print STDERR "-penalty\t\t(:-3)\n"; # not operational
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for results filtering:\n";
    print STDERR "\n";
    print STDERR "-fuzz\t\tmismatch allowed on read cover; default 1, use up to 5\n";
    print STDERR "-partial\taccept partial matches of reads at end of contigs\n";
#    print STDERR "-mmo\t\t(multiplematchesonly) select contigs having more than one match\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for output control and testing:\n";
    print STDERR "\n";
    print STDERR "-refresh\tforces rebuild of all intermediate results\n";
    print STDERR "-verbose\t\n";
    print STDERR "\n";
    print STDERR "-ft\t\t(filtertest) set to 1,2 to list results of filtering and abort\n";
    print STDERR "-caf\t\texport new contigs in caf format on file specified\n";
    print STDERR "-contig\t\tcontig name filter to select contig(s) for processing\n";
    print STDERR "\n";

    exit 1;
}

#------------------------------------------------------------------------------
