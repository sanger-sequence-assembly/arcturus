#!/usr/local/bin/perl -w

use strict;

use FileHandle;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# variable definitions
#----------------------------------------------------------------

my ($organism,$instance);

my ($project,$assembly,$fopn,$lock, $ignore); # arcturus contig data

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

my ($renew,$verbose,$debug); # control

#----------------------------------------------------------------
# parse command line parameters
#----------------------------------------------------------------

my $validKeys  = "organism|o|instance|i|"
               . "project|p|assembly|a|fopn|lock|"  # contig selection & export
               . "namelike|nl|namenotlike|nnl|aspedbefore|ab|aspedafter|aa|"
               . "nomasksequence|nms|" # read selection & export
               . "minmatch|mm|minscore|ms|masklevel|ml|" # crossmatch control
               . "fuzz|partial|filtertest|ft|multiplematchesonly|mmo|" # cm output filter
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

    $lock          = 1            if ($nextword eq '-lock');

    $fopn          = shift @ARGV  if ($nextword eq '-fopn');

    $ignore        = shift @ARGV  if ($nextword eq '-ignore');

# unassembled reads selection

    if ($nextword eq '-namelike'    || $nextword eq '-nl') {
        $namelike    = shift @ARGV;
    }

    if ($nextword eq '-namenotlike' || $nextword eq '-nnl') {
        $namenotlike = shift @ARGV;
    }

    if ($nextword eq '-aspedbefore' || $nextword eq '-ab') {
	$aspedbefore = shift @ARGV;
    }

    if ($nextword eq '-aspedafter'  || $nextword eq '-aa') {
	$aspedafter  = shift @ARGV;
    }

    if ($nextword eq '-nomasksequence' || $nextword eq '-nms') {
        $nomask      = 1;
    }  

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
  
# test options

    if ($nextword eq '-filtertest'  || $nextword eq '-ft') {
        $ftest     = shift @ARGV;
        $ftest     = 1 unless defined $ftest;
    }

    $contig        = shift @ARGV  if ($nextword eq '-contig');
    $testread      = shift @ARGV  if ($nextword eq '-read');
    $caffile       = shift @ARGV  if ($nextword eq '-caf');
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

my $contigfasta      = "/tmp/$organism.c.fas";
my $contigquality    = "/tmp/$organism.c.qual";
my $uareadfasta      = "/tmp/$organism.r.fas";
my $xmatchoutput     = "/tmp/$organism.crossmatch";
my $xmatchfilter     = "/tmp/$organism.crossmatchfilter";
my $readqmaskdata    = "/tmp/$organism.r.mask.lis";

my $arcturus_root = "/software/arcturus";

#------------------------------------------------------------------------------
# 1 : export the (selected) contigs as fasta file
#------------------------------------------------------------------------------

unless ( -f $contigfasta && !$renew) {
# later replace by new-contig-export
    my $command = "$arcturus_root/utils/project-export "
                . "-organism $organism -instance $instance "
                . "-fasta $contigfasta "
                . "-gap4name -qc ";
    $command   .= "-project $project "       if $project;
    $command   .= "-ignore $ignore "         if $ignore;
    $command   .= "-fopn $fopn "             if $fopn;
    $command   .= "-lock"                    if $lock;
    $command   .= "-quality $contigquality " if $nomask;
    $command   .= "-verbose"                 if $verbose;

    $logger->warning("exporting current contigs to $contigfasta",ss=>1);
    $logger->info($command,skip=>1);

    exit 1 if &mySystem($command);
}

#------------------------------------------------------------------------------
# 2 : export the (selected) unassembled reads
#------------------------------------------------------------------------------

unless (-f $uareadfasta && !$renew) {

    &mySystem("rm -f ${uareadfasta}*") if (-f $uareadfasta);

    my $command = "$arcturus_root/utils/getunassembledreads "
                . "-o $organism -i $instance "
                . "-fasta $uareadfasta ";
    $command   .= "-mask x "                     unless $nomask;
    $command   .= "-namelike    '$namelike' "    if $namelike;
    $command   .= "-namenotlike '$namenotlike' " if $namenotlike;
    $command   .= "-aspedbefore '$aspedbefore' " if $aspedbefore;
    $command   .= "-aspedafter  '$aspedafter' "  if $aspedafter;
# nosingletons ?
    $command   .= "-verbose"                     if $verbose;

    $logger->warning("exporting unssembled reads to $uareadfasta",ss=>1);
    $logger->info($command,skip=>1);

    exit 1 if &mySystem($command);
}

#------------------------------------------------------------------------------
# 3 : run crossmatch to get cross.lis file
#------------------------------------------------------------------------------

unless (-f $xmatchoutput && !$renew) {

    &mySystem("rm -f $xmatchoutput") if (-f $xmatchoutput);

    my $command = "cross_match $contigfasta $uareadfasta "
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

unless ((-f $xmatchfilter && ! -z $xmatchfilter) && !$renew && !$ftest) {

    &mySystem("rm -f $xmatchfilter") if (-f $xmatchfilter);

#    my $command = "/nfs/team81/ejz/arcturus/development/utils/xmatch-filter.pl "
    my $command = "$arcturus_root/utils/xmatch-filter "
    	        . "-in  $xmatchoutput "
                . "-out $xmatchfilter ";
    $command   .= "-qfile $readqmaskdata " unless $nomask;
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
# 5 : run bac-end-assembler.pl
#------------------------------------------------------------------------------

my $swprog = "$arcturus_root/test/smithwaterman.x";

if (-f $xmatchfilter) {

#    my $command = "$arcturus_root/utils/directed-read-assembler "
# NOTE : rename and improve multiple placed mode of bac-end-assembler.pl
    my $command = "$arcturus_root/utils/bac-end-assembler "
                . "-o $organism -i $instance "
                . "-filename $xmatchfilter -swprog $swprog "
                . "-clip -breakmode -cleanup ";
    $command   .= "-caf $caffile "     if $caffile;
    $command   .= "-contig $contig "   if $contig;
    $command   .= "-read $testread "   if $testread;
#    $command   .= "-multiple "         if $nosingle; # to be developed
    $command   .= "-confirm "          if $confirm;
    $command   .= "-verbose "          if $verbose;

    $logger->warning("assembling reads into contigs",ss=>1);
    $logger->info($command,skip=>1);

    exit 1 if &mySystem($command);

    $logger->warning("to load new contigs : repeat with '-confirm'") unless $confirm;
}
else {
    $logger->severe("can't run assembler: missing filtered cross match output");
}


my $calculateconsensus = "/software/arcturus/utils/calculateconsensus "
	               . "-instance $instance -organism $organism "
                       . "-quiet";

&mySystem($calculateconsensus);

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
    print STDERR "5 : place each read on its contig using Smith Waterman alignment\n";
    print STDERR "6 : load the (new) contig(s) into the database\n";
    print STDERR "7 : calculate consensus sequence for newly added contig(s)\n";
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
    print STDERR "-project\t(p:ALL) project(s) of which contigs are to be used\n";
    print STDERR "-assembly\t(a:1) assembly, required in case of ambiguity\n";
    print STDERR "-ignore\t\t(:PROBLEMS) comma-separated list of projects to ignore\n";
    print STDERR "-fopn\t\tfile of project names\n";
    print STDERR "-lock\t\tAcquire lock on project(s); ignore already locked ones\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for unassembled (free) read selection:\n";
    print STDERR "\n";
    print STDERR "-namelike\t(nl)  include read name(s) matching name/pattern\n";
    print STDERR "-namenotlike\t(nnl) exclude read name(s) matching name/pattern\n";
    print STDERR "-aspedbefore\t(ab)  include reads when asped before\n";
    print STDERR "-aspedafter\t(aa)  include reads when asped after\n";
    print STDERR "-nomasksequence\t(nms) do not mask low quality read sequence\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for crossmatch control (re: man cross_match):\n";
    print STDERR "-minmatch\t(mm:50)\n";
    print STDERR "-minscore\t(ms:100)\n";
    print STDERR "-masklevel\t(ml:100) 0, 100 or 101\n";
#    print STDERR "-penalty\t\t(:-3)\n"; # not operational
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for results filtering:\n";
    print STDERR "\n";
    print STDERR "-fuzz\t\tmismatch allowed on read cover; default 1, use up to 5\n";
    print STDERR "-partials\taccept partial matches of reads at end of contigs\n";
#    print STDERR "-mmo\t\t(multiplematchesonly) select reads having more than one match\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for loading new contigs:\n";
    print STDERR "\n";
    print STDERR "-confirm\tto actually enter the new contigs into the database\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for output control and testing:\n";
    print STDERR "\n";
    print STDERR "-refresh\tforces rebuild of all intermediate results\n";
    print STDERR "-verbose\t\n";
    print STDERR "\n";
    print STDERR "-ft\t\t(filtertest) set to 1,2 to list results of filtering and abort\n";
    print STDERR "-caffile\texport new contigs in caf format on file specified\n";
    print STDERR "-contig\t\tcontig name filter to select contig(s) for processing\n";
    print STDERR "-read\t\tread name filter to select specific read(s)\n";
    print STDERR "\n";

    exit 1;
}

#------------------------------------------------------------------------------
