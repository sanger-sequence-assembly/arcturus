#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use FileHandle;

use Logging;

#----------------------------------------------------------------
# test input parameter
#----------------------------------------------------------------

my $organism;
my $instance;
my $alias;
my $schema;
my $projid;
my $group;
my $rootdir;

my $shell = 'bash';
my $and_so_on = '"$@"';

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-(organism|instance|schema|group|project|shell|rootdir|alias)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance = shift @ARGV  if ($nextword eq '-instance');
    $organism = shift @ARGV  if ($nextword eq '-organism');
    $alias    = shift @ARGV  if ($nextword eq '-alias');
    $schema   = shift @ARGV  if ($nextword eq '-schema');
    $group    = shift @ARGV  if ($nextword eq '-group');
    $projid   = shift @ARGV  if ($nextword eq '-project');
    $shell    = shift @ARGV  if ($nextword eq '-shell');
    $rootdir  = shift @ARGV  if ($nextword eq '-rootdir');
}

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing project schema") if ($projid && !$schema);

&showUsage("Missing project ID")     if ($schema && !$projid);

$group = $organism unless $group;

#----------------------------------------------------------------
# test if the database exists
#----------------------------------------------------------------

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$adb->disconnect();

my $logger = new Logging();

#----------------------------------------------------------------
# move to work directory
#----------------------------------------------------------------

my $ARC_DEV_ROOT = $ENV{ARC_DEV_ROOT};

my $rootdirectory = $rootdir;
unless ($rootdirectory) {
    $rootdirectory = `pfind -q -u $alias`        if $alias;
    $rootdirectory = `pfind -q -u $organism` unless $alias;
    exit unless $rootdirectory;
}

if ($rootdirectory =~ /.*nfs.+nfs/) {
# multiple directories specified
    if ($rootdirectory =~ ?.*(/nfs[^n\s]+$organism)[\b/].*?) {
        $rootdirectory = $1;
    }
    else {
	$logger->error("can't decode directory information:\n$rootdirectory");
	exit 1;
    }
}

$logger->info("root $rootdirectory");

unless ($rootdirectory) {
    $logger->error("unable to locate organism $organism");
    exit 1;
}
 
$rootdirectory .= '/arcturus';

unless (-e $rootdirectory) {
    mkdir($rootdirectory); 
    unless (-e $rootdirectory) {
        $logger->error("Failed to create directory $rootdirectory");
        exit 1;
    }
    chmod(0775,$rootdirectory);

}

#----------------------------------------------------------------
# write out the wrappers
#----------------------------------------------------------------

# 1: create the scripts in arcturus/transfer

my $directory = $rootdirectory.'/transfer';

unless (-e $directory) {
    mkdir($directory);
    unless (-e $directory) {
        $logger->error("Failed to create directory $directory");
    }
    chmod(0775,$directory);
}

chdir($directory);
# just to be sure, test if the work directory exists
my $pwd = `pwd`;
#if ($pwd =~ /$organism\/arcturus\/transfer/) {
if ($pwd =~ /$rootdirectory\/transfer/) {

    $logger->warning("Finishing scripts are created in directory $pwd",ss=>1);

    &writeTransferScripts("requestRead",$organism,$instance);

    &writeTransferScripts("requestContig",$organism,$instance);
    &writeTransferScripts("grantContigRequest",$organism,$instance);
    &writeTransferScripts("cancelContigRequest",$organism,$instance);
    &writeTransferScripts("rejectContigRequest",$organism,$instance);
    &writeTransferScripts("deferContigRequest",$organism,$instance);
    &writeTransferScripts("executeContigRequest",$organism,$instance);
    &writeTransferScripts("listContigRequest",$organism,$instance);
    $logger->warning("DONE");
}
else {
    $logger->error("failed to access work directory $directory");
}

# write checkin/checkout

# 2: create the scripts in utils

$directory = $rootdirectory.'/utils';
mkdir($directory) unless (-e $directory);
chmod(0775,$directory);

chdir($directory);
# just to be sure, test if the work directory exists
$pwd = `pwd`;
unless ($pwd =~ /$rootdirectory\/utils/) {
    die "failed to locate work directory $directory";
}

print STDOUT "\nUtility scripts are created in directory $pwd\n";
    

&writeProjectScripts($organism,$instance);

&writeContigScripts($organism,$instance);

&writeReadScripts($organism,$instance,$schema,$projid);
 
&writeUserScripts($organism,$instance);

&writeAssemblyScripts($organism,$instance);
   
print STDOUT "DONE\n";

&removeredundentwrappers();

# 3: create import-export directory
    
$directory = $rootdirectory.'/import-export';
mkdir($directory) unless (-e $directory);

chmod(0775,$directory);

#chdir($directory);

#print STDOUT "\nIO scripts scripts are created in directory $pwd\n";

#print STDOUT "TO BE IMPLEMENTED\n";

chdir($rootdirectory);

unless (-l "split" || !(-d "../split")) {
    print STDOUT "\nIO creating split softlink in ". `pwd` ."\n";
   `ln -s ../split split`;

    unless (chdir('split')) {
        print STDOUT "\nFAILED to create/move to split directory\n";
        exit 0;
    }

    unless (-l "utils") {
        print STDOUT "\nIO creating utils softlink in ". `pwd` ."\n";
       `ln -s ../arcturus/utils utils`;
    }
}

exit 0;

#----------------------------------------------------------------
# subs creating the wrapper scripts
#----------------------------------------------------------------

sub writeTransferScripts {
    my $filename = shift;
    my $organism = shift;
    my $instance = shift;

    my $type;

    if ($filename =~ /(contig|read)/i) {
        $type = lc($1);
    }

    my $action;
    if ($filename =~ /\b(grant|cancel|reject|defer|execute)/) {
        $action = "-$1";
    }
    elsif ($filename =~ /\brequest/) {
        $action = "  "; # set true for read
        $action = "-transfer" if ($type eq 'contig');
    }
#    elsif ($filename =~ /\b(list|execute)/) {
#        $action = "-$1";
#    }
    elsif ($filename =~ /\blist/) {
        $action = "-list -trun";
    }

    return unless ($filename && $action);

    my $FILE = new FileHandle($filename,"w");
    unless ($FILE) {
	print "FAILED to create file handle for $filename\n";
        return;
    }

    print $FILE "#!/bin/$shell\n";

    print $FILE "/software/arcturus/utils/${type}-transfer-manager "
 	      . "-instance $instance -organism $organism $action $and_so_on\n";

    $FILE->close();

    chmod(0755,$filename);
}

#-----------

sub writeReadScripts {
    my $organism = shift;
    my $instance = shift;
    my $schema = shift;
    my $projid = shift;

    my $text;

    if (defined($schema) && defined ($projid)) {

        $text = "/software/arcturus/utils/read-loader "
              . "-instance $instance -organism $organism "
              . "-source Oracle -schema $schema -projid $projid "
              . "-verbose";
        &writeFILE ("oraclereadloader","$text $and_so_on ");
    }

# read-tag loader

#    $text = "/software/arcturus/utils/read-loader "
# 	  . "-instance $instance -organism $organism "
#          . "-source Expfiles -onlyloadtags -verbose";
#    &writeFILE ("addiTagLoader","$text $and_so_on ");

# read-allocation-test

    $text = "/software/arcturus/utils/read-allocation-test "
          . "-instance $instance -organism $organism";
    &writeFILE ("readAllocationTest","$text $and_so_on ");

# read loader from trace server

    $text = "/software/arcturus/utils/read-loader "
 	  . "-instance $instance -organism $organism "
          . "-source TraceServer -group $group "
          . "-minreadid auto ";
    &writeFILE ("readloader","$text $and_so_on ");

# read loader from experiment files

    $text = "/software/arcturus/utils/read-loader "
 	  . "-instance $instance -organism $organism "
          . "-source Expfiles ";
    &writeFILE ("expfilereadloader","$text $and_so_on ");

# read loader from a caf file

    $text = "/software/arcturus/utils/read-loader "
 	  . "-instance $instance -organism $organism "
          . "-source CAF ";
    &writeFILE ("cafreadloader","$text $and_so_on ");

    $text = "/software/arcturus/utils/new-contig-loader "
 	  . "-instance $instance -organism $organism "
          . "-noload ";
    &writeFILE ("bulkcafreadloader","$text $and_so_on ");

# consensus read loader from a fasta or other file

    $text = "/software/arcturus/utils/read-loader "
 	  . "-instance $instance -organism $organism "
          . "-source fastafile ";
    &writeFILE ("fastareadloader","$text $and_so_on ");

    $text = "/software/arcturus/utils/read-loader "
 	  . "-instance $instance -organism $organism "
          . "-source fastafile ";
    &writeFILE ("454consensusloader","$text $and_so_on ");

#    $text = "/software/arcturus/utils/import-consensus-reads "
    $text = "/software/arcturus/utils/import-fasta-reads "
 	  . "-instance $instance -organism $organism ";
    &writeFILE ("consensusreadloader","$text $and_so_on ");

# read-tag loader

    $text = "/software/arcturus/utils/read-tag-loader "
 	  . "-instance $instance -organism $organism "
          . "-limit 0 -tagtype CONS -read 'NODE%' "
          . "-tagtext 'Consensus generated from Illumina velvet assembly'";
    &writeFILE ("illuminatagloader","$text $and_so_on ");

    $text = "/software/arcturus/utils/read-loader "
 	  . "-instance $instance -organism $organism "
          . "-source TraceServer -group $group "
          . "-minreadid 1 -onlyloadtags -verbose";
    &writeFILE ("additagloader","$text $and_so_on ");

# unassembled reads

    $text = "/software/arcturus/utils/getunassembledreads "
	  . "-instance $instance -organism $organism ";
    &writeFILE ("unassembledreads","$text $and_so_on ");

# read list

    $text = "/software/arcturus/utils/read-list "
	  . "-instance $instance -organism $organism ";
    &writeFILE ("showread","$text $and_so_on ");

}

#-----

sub writeContigScripts {
    my $organism = shift;
    my $instance = shift;

# contig list script

    my $text = "/software/arcturus/utils/contig-export "
	     . "-instance $instance -organism $organism ";
    &writeFILE ("showContig","$text $and_so_on ");

# contig delete scripts

    $text = "/software/arcturus/utils/contig-delete "
          . "-instance $instance -organism $organism -username arcturus_dba";

    &writeFILE ("deleteContig","$text $and_so_on ");

    &writeFILE ("deleteSingleReadParents","$text -srp  $and_so_on ");

# contig retire scripts

    $text = "/software/arcturus/utils/contig-retire "
          . "-instance $instance -organism $organism";

    &writeFILE ("retireContig","$text $and_so_on ");

# where's my contig
 
    $text = "/software/arcturus/utils/contig-family-tree "
	  . "-instance $instance -organism $organism ";
    &writeFILE ("whereIsMyContig","$text $and_so_on ");

# tag loader

    $text = "/software/arcturus/utils/annotation-tag-loader "
          . "-instance $instance -organism $organism -propagate "
          . "-swprog 0 -noload -nodebug ";
    &writeFILE ("annotagmapper","$text $and_so_on ");

    $text = "/software/arcturus/utils/new-contig-loader "
          . "-instance $instance -organism $organism ";
    &writeFILE ("caf2arcturus","$text $and_so_on ");

# repeat tagger

    $text = "/software/arcturus/utils/assembly-repeat-tagger "
#    $text = "${ARC_DEV_ROOT}/utils/assembly-repeat-tagger "
          . "-instance $instance -organism $organism "
          . "-vector ../assembly/repeats.dbs ";
    &writeFILE ("addRepeatTags","$text $and_so_on ");
}

sub writeAssemblyScripts {
    my $organism = shift;
    my $instance = shift;

    my $text;
   
# directed assembly

    $text = "/software/arcturus/utils/directed-assembly "
  	  . "-instance $instance -organism $organism "
          . "-fd "; # maybe not ??
    &writeFILE ("directedreadassembler","$text $and_so_on ");

#$ARC_DEV_ROOT/utils/crossmatch-assembly -organism BIG -instance pathogen -p ILLUMINA -tp BIG2BIN -verbose -partial 
    $text = "/software/arcturus/utils/crossmatch-assembly "
  	  . "-instance $instance -organism $organism "
          . " ";
    &writeFILE ("projectcrossmatch","$text $and_so_on ");
}

# ---

sub writeProjectScripts {
    my $organism = shift;
    my $instance = shift;

    my $text;

# create project

    $text =  "/software/arcturus/utils/project-create "
	  . "-instance $instance -organism $organism";
    &writeFILE ("createProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-list "
          . "-instance $instance -organism $organism";
    &writeFILE ("listProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-list "
          . "-instance $instance -organism $organism -short";
    &writeFILE ("listSplitInfo","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-update "
          . "-instance $instance -organism $organism";
    &writeFILE ("updateProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/find-project-for-finishing-read "
	  . "-instance $instance -organism $organism";
    &writeFILE ("findProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/batch-job-manager "
	  . "-instance $instance -organism $organism -batch -import ";
    &writeFILE ("importProject","$text $and_so_on ");
           
    $text = "/software/arcturus/utils/batch-job-manager "
	  . "-instance $instance -organism $organism -batch -export ";
    &writeFILE ("exportProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/batch-job-manager "
	  . "-instance $instance -organism $organism -import ";
    &writeFILE ("gap4-to-arc","$text $and_so_on ");
           
    $text = "/software/arcturus/utils/batch-job-manager "
	  . "-instance $instance -organism $organism -export ";
    &writeFILE ("arc-to-gap4","$text $and_so_on ");

    $text = "/software/arcturus/utils/create-library-project "
	  . "-instance $instance -organism $organism -nogap ";
    &writeFILE ("createLibrary","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-export "
          . "-instance $instance -organism $organism -project ALL "
          . "-ignore problems,trash -fasta 0 -gap4name -preview ";
    &writeFILE ("assembly2fasta","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-export "
          . "-instance $instance -organism $organism -project ALL "
          . "-ignore problems,trash -caf 0 -gap4name -preview ";
    &writeFILE ("assembly2caf","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-export "
          . "-instance $instance -organism $organism -fasta 0 "
          . "-gap4name -qualityclip -preview ";
    &writeFILE ("project2fasta","$text $and_so_on ");

    $text = "$ENV{HOME}/arcturus/dev/utils/new-contig-export "
# $text = "/software/arcturus/utils/new-contig-export "
          . "-instance $instance -organism $organism -embl 0 "
          . "-includetags ANNO,REPT ";
    &writeFILE ("project2embl","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-lock "
	  . "-instance $instance -organism $organism ";
    &writeFILE ("lockProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/project-unlock "
	  . "-instance $instance -organism $organism ";
    &writeFILE ("unlockProject","$text $and_so_on ");

    $text = "/software/arcturus/utils/projectstatus.csh "
	  . "$instance $organism ";
    &writeFILE ("projectstatus","$text $and_so_on ");

    $text = "/software/arcturus/utils/diagnose "
	  . " ";
    &writeFILE ("diagnose","$text $and_so_on ");

    $text = "/software/arcturus/utils/diagnose "
	  . "-instance $instance -organism $organism ";
    &writeFILE ("verify","$text $and_so_on ");

# consensus

    $text = "/software/arcturus/utils/calculateconsensus "
	. "-instance $instance -organism $organism ";
    &writeFILE ("calculateConsensus","$text $and_so_on ");

    $text = "$ENV{HOME}/arcturus/dev/utils/new-contig-export "
# $text = "/software/arcturus/utils/new-contig-export "
   	  . "-instance $instance -organism $organism -embl 0 "
          . "-includetags ANNO,REPT ";
    &writeFILE ("assembly2embl","$text $and_so_on ");

# temporary test shortcuts

# $text = "/software/arcturus/utils/batch-job-manager "
    $text = "$ENV{HOME}/arcturus/dev/utils/batch-job-manager "
	  . "-instance $instance -organism $organism -batch -import ";
    &writeFILE ("testimportProject","$text $and_so_on ");
           
# $text = "/software/arcturus/utils/batch-job-manager "
    $text = "$ENV{HOME}/arcturus/dev/utils/batch-job-manager "
	  . "-instance $instance -organism $organism -batch -export ";
    &writeFILE ("testexportProject","$text $and_so_on ");
}


sub writeFinishingScript {
    my $organism = shift;
    my $instance = shift;

    my $filename = "findProject";

    my $FILE = new FileHandle($filename,"w");

    print $FILE "#!/bin/$shell\n";

    print $FILE "/software/arcturus/utils/find-project-for-finishing-read "
	      . "-instance $instance -organism $organism $and_so_on\n";

    $FILE->close();

    chmod(0755,$filename);
}

sub writeUserScripts {
    my $organism = shift;
    my $instance = shift;

    my $filename = "userAdmin";

    my $FILE = new FileHandle($filename,"w");

    unless ($FILE) {
	print "FAILED to create file handle for $filename\n";
	$pwd = `pwd`; chomp $pwd; print "Current directory: $pwd\n";
        return;
    }

    print $FILE "#!/bin/$shell\n";

    print $FILE "/software/arcturus/utils/user-manager "
	      . "-instance $instance -organism $organism $and_so_on\n";

    $FILE->close();

    chmod(0755,$filename);
}

#---------------------------------------------------------------------------
# create the wrapper script
#---------------------------------------------------------------------------

sub writeFILE {
    my $file = shift;
    my $text = shift;

    my $FILE = new FileHandle($file,"w");

    unless ($FILE) {
	print "FAILED to create file handle for $file\n($text)\n";
	$pwd = `pwd`; chomp $pwd; print "Current directory: $pwd\n";
        return;
    }

    print $FILE "#!/bin/$shell\n";

    print $FILE "$text\n";

    $FILE->close();

    chmod(0755,$file);
}

sub removeredundentwrappers {
    my @wrappers = ('consensusreadloade');

    foreach my $wrapper (@wrappers) {
        next unless (-f $wrapper);
        `rm -f $wrapper`;
    }
}

#---------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS (create utility scripts):\n";
    print STDERR "\n";
    print STDERR "-schema\t\tOracle schma name\n";
    print STDERR "-project\tOracle project ID\n";
    print STDERR "\n";
    print STDERR "-alias\t\tif pfind uses a different organism name\n";
    print STDERR "\n";

    exit(1);
}
