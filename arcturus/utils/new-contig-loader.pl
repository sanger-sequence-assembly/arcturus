#!/usr/local/bin/perl -w

#----------------------------------------------------------------
# CAF file parser, building Contig instances and components
#----------------------------------------------------------------

use strict; # Constraint variables declaration before using them

use ContigFactory::ContigFactory;
use ReadFactory::TraceServerReadFactory;

use ArcturusDatabase;
use Project;

use FileHandle;
use Logging;

require Mail::Send;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;

# the data source

my $caffilename;            # must be specified
my $gap4dbname;             # default 'projectname.0' ??

# caf file processing

my $frugal = 1 ;            # (default) build object instances using minimal memory
my $linelimit;              # specifying a line limit implies test mode 
my $readlimit;              # scan until this number of reads is found
my $parseonly;              # only parse the file (test mode)
my $blocksize = 20;

# contig specification

my $contignamefilter;       # test contig names for this string / regular expr.
my $minnrofreads = 1;       # minimum number of reads required in a contig
my $maxnrofreads;           # maximum number of reads required in a contig
my $withoutparents;

my $breakcontig = 1;        # on consistence test failure try to split contig

my $origin;
my $acceptpadded = 0;       # 1 to allow a padded assembly
my $safemode = 0;           # readback last written data to verify storage
my $contigload = 1;         # (default) load assembled contigs (including tags)
my $contigtest = 0;         # test contig against the database
my $consensus;              # to store consensus sequence from caf file
my $acceptversionzero;      # read version o is use if no sequence available

# contig tags

my $ctagtypeaccept;         # accepted contig tags (list or regular experession)
#my $ctagtypereject;        # rejected contig tags (list or regular experession)
my $loadcontigtags;         # use when no contig loading
my $testcontigtags;         # active when no contig loading; implies test only
my $echocontigtags;         # list the contig tags found; implies no loading
my $listcontigs;
#my $inherittags;
my $annotationtags;         # default CDS,FCDS
my $finishingtags;          # default REPT,RP20

# reads

my $readload = 1;           # default load missing reads
my $consensusread = 'con';  # default consensus read name (re: read load mode)
my $noaspedcheck;           # (re: read load mode)

# read tags

my $rtagtypeaccept = 'default'; 
my $loadreadtags = 1;       # (default) load new read tags found on caf file
my $echoreadtags;           # list the read tags found; implies no loading
my $syncreadtags;           # retired readtags which are NOT in the current lis

# project

my $pidentifier = 'BIN';    # projectname for which the data are to be loaded
my $assembly;               # may be required in case of ambiguity
my $pinherit = 'readcount'; # project inheritance method, default on number of reads

my $projectlock;            # if set acquire lock on project first ? shoulb always
my $autolockmode = 1;

# output

my $loglevel;             
my $logfile;
my $outfile;
my $minerva;
my $mail;

my $debug = 0;
my $usage;

#------------------------------------------------------------------------------

my $development = 0;
if ($development) {
    $contigload = 0;
    $loadcontigtags = 0;
    $loadreadtags = 0;
}

$rtagtypeaccept = 'default';

#------------------------------------------------------------------------------

my $validkeys  = "organism|o|instance|i|"

               . "caf|stdin|gap4name|"
               . "nofrugal|nf|linelimit|ll|readlimit|rl|"
               . "blocksize|bs|"

               . "padded|safemode|maximum|minimum|filter|withoutparents|wp|"
               . "testcontig|tc|noload|notest|parseonly|nobreak|consensus|"

               . "noloadreads|nlr|doloadreads|dlr|"
               . "consensusreadname|crn|noaspedcheck|nac|"
               . "acceptversionzero|avz|"

               . "contigtagtype|ctt|noloadcontigtags|nlct|showcontigtags|sct|"
               . "loadcontigtags|lct|testcontigtags|tct|listcontig|list|"
               . "annotationtags|ats|finishingtags|fts|"

               . "readtagtype|rtt|noloadreadtags|nlrt|showreadtags|srt|"
               . "loadreadtags|lrt|synchronisereadtags|syncrt|"

               . "assignproject|ap|defaultproject|dp|setprojectby|spb|"
               . "projectlock|pl|dounlock|project|p|noprojectlock|npl|"
               . "assembly|a|"

               . "outputfile|out|log|minerva|verbose|info|debug|memory|help|h";

#------------------------------------------------------------------------------
# parse the command line input; options overwrite eachother; order is important
#------------------------------------------------------------------------------

while (my $nextword = shift @ARGV) {

    $nextword = lc($nextword);

    if ($nextword !~ /\-($validkeys)\b/) {
        &showUsage("Invalid keyword '$nextword' \n($validkeys)");
    }

    if ($nextword eq '-i' || $nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    elsif ($nextword eq '-o' || $nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }

# input specification

    if ($nextword eq '-caf') {
        $caffilename  = shift @ARGV; # specify input file
    }
    elsif ($nextword eq '-stdin') {
        $caffilename  = 0;           # input with "<" operator or from pipe
    }

    $gap4dbname       = shift @ARGV  if ($nextword eq '-gap4name');

# caf file processing

    if ($nextword eq '-nf' || $nextword eq '-nofrugal') {
        $frugal       = 0;
    }            
    elsif ($nextword eq '-ll'    || $nextword eq '-linelimit' ) {
        $linelimit    = shift @ARGV; 
    } 
    elsif ($nextword eq '-rl' || $nextword eq '-readlimit') {
        $readlimit    = shift @ARGV; 
    }
 
    if ($nextword eq '-po' || $nextword eq '-parseonly') {
        $parseonly    = 1;
#	$readload     = 0;
    }

    if ($nextword eq '-padded') {
	$acceptpadded   = 1;
        $consensus      = 1;
    }    

# contig selection and processing

    $minnrofreads     = shift @ARGV  if ($nextword eq '-minimum');
    $maxnrofreads     = shift @ARGV  if ($nextword eq '-maximum');
    $contignamefilter = shift @ARGV  if ($nextword eq '-filter'); 

    if ($nextword eq '-bs' || $nextword eq '-blocksize') {
        $blocksize    = shift @ARGV;
        $blocksize = 1 if ($blocksize <= 0);
    } 

    if ($nextword eq '-wp' || $nextword eq '-withoutparents') {
        $withoutparents = 1;
    } 

    $consensus        = 1  if ($nextword eq '-consensus');

    if ($nextword eq '-nl' || $nextword eq '-noload') {
        $contigload     = 0;
        $loadcontigtags = 0;
	$readload       = 0;
        $loadreadtags   = 0;
    }
    elsif ($nextword eq '-nt' || $nextword eq '-notest') { # redundent
        $contigtest     = 0;            
    }
    elsif ($nextword eq '-tc' || $nextword eq '-testcontig') {
        $contigtest     += 1;
        $contigload     = 0;
        $loadcontigtags = 0;
        $loadreadtags   = 0;
    }
    elsif ($nextword eq '-listcontig' || $nextword eq '-list') {
	$listcontigs    = shift @ARGV;
    }

    $origin             = shift @ARGV  if ($nextword eq '-origin');
    $safemode           = 1            if ($nextword eq '-safemode');
    $breakcontig        = 0            if ($nextword eq '-nobreak');

# loading (missing) reads from input file

    if ($nextword eq '-avz' || $nextword eq '-acceptversionzero') {
	$acceptversionzero = 1; # use with Phusion assembly
    }

    if ($nextword eq '-nlr' || $nextword eq '-noloadreads') {
	$readload       = 0; # switch off autoload of missing reads
    }

    if ($nextword eq '-dlr' || $nextword eq '-doloadreads') {
	$readload       = 1; # switch on autoload of missing reads
    }

    if ($nextword eq '-crn' || $nextword eq '-consensusreadname') {
	$consensusread  = shift @ARGV;
    }

    if ($nextword eq '-nac' || $nextword eq '-noaspedcheck') {
	$noaspedcheck   = shift @ARGV;
    }

# contig tags

    if ($nextword eq '-ctt' || $nextword eq '-contigtagtype') {
        $ctagtypeaccept = shift @ARGV;
    }
    elsif ($nextword eq '-nlct' || $nextword eq '-noloadcontigtags') {
        $loadcontigtags = 0;            
    }
    elsif ($nextword eq '-lct'  || $nextword eq '-loadcontigtags') {
        $loadcontigtags = 1;            
    }
    elsif ($nextword eq '-tct'  || $nextword eq '-testcontigtags') {
        $loadcontigtags = 0;
        $testcontigtags = 1;            
    }
    elsif ($nextword eq '-sct'  || $nextword eq '-showcontigtags') {
        $loadcontigtags = 0;
        $echocontigtags = 1;            
    }

    if ($nextword eq '-ats' || $nextword eq '-annotationtags') {
        $annotationtags = shift @ARGV;
    }
    if ($nextword eq '-fts' || $nextword eq '-finishingtags') {
        $finishingtags = shift @ARGV;
    }

# read tags

    if ($nextword eq '-rtt' || $nextword eq  '-readtagtype') {
        $rtagtypeaccept = shift @ARGV;
    }
    elsif ($nextword eq '-nlrt' || $nextword eq '-noloadreadtags') {
        $loadreadtags = 0;            
    }
    elsif ($nextword eq '-lrt'  || $nextword eq '-loadreadtags') {
#        $loadreadtags = 1 unless defined $loadreadtags; # ? why          
        $loadreadtags = 1;            
    }
    elsif ($nextword eq '-srt'  || $nextword eq '-showreadtags') {
        $loadreadtags = 0;
        $echoreadtags = 1;            
    }
    if ($nextword eq 'synchronisereadtags' || $nextword eq 'syncrt') {
        $syncreadtags = 1;
    } 

# project ('assignproject' forces its use, by-passing inheritance)

    if ($nextword eq '-a' || $nextword eq '-assembly') {
        $assembly     = shift @ARGV;
    }
    elsif ($nextword eq '-ap' || $nextword eq '-assignproject' ||
           $nextword eq '-p'  || $nextword eq '-project') {
        $pidentifier  = shift @ARGV;
        $pinherit     = 'project';
    }
    elsif ($nextword eq '-dp'  || $nextword eq '-defaultproject') {
        $pidentifier  = shift @ARGV;
    }
    elsif ($nextword eq '-pl'  || $nextword eq '-projectlock') {
        $projectlock  = 1;
    }
    elsif ($nextword eq '-npl' || $nextword eq '-noprojectlock') {
        $projectlock  = 0;
    }
    elsif ($nextword eq '-spb' || $nextword eq'-setprojectby') {
        $pinherit     = shift @ARGV;
    }

    $autolockmode     = 0  if ($nextword eq '-dounlock'); # default 1

# reporting

    $loglevel         = 0  if ($nextword eq '-verbose'); # info, fine, finest
    $loglevel         = 2  if ($nextword eq '-info');    # info
    $debug            = 1  if ($nextword eq '-debug');   # info, fine
    $usage            = 1  if ($nextword eq '-memory');  # info, fine

    $logfile          = shift @ARGV  if ($nextword eq '-log');
    $outfile          = shift @ARGV  if ($nextword eq '-out');

    &showUsage(0) if ($nextword eq '-h' || $nextword eq '-help');
}

#----------------------------------------------------------------
# test the CAF file name
#----------------------------------------------------------------
        
&showUsage("Missing CAF file name") unless defined($caffilename);

# test existence of the caf file

&showUsage("CAF file $caffilename does not exist") unless (-f $caffilename);

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardStream($logfile,append=>1) if $logfile; # default STDOUT

$logger->setStandardFilter($loglevel) if defined $loglevel; # reporting level

$logger->setSpecialStream($outfile,list=>1,timestamp=>1) if $outfile;

$logger->setPrefix("#MINERVA") if $minerva;

if ($debug) {
    $logger->stderr2stdout();
    $logger->setBlock('debug',unblock=>1);
}

$logger->listStreams() if defined $loglevel; # test

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($projectlock) { # || $contigload
    &showUsage("Missing project identifier") unless $pidentifier;
}

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

    &showUsage("Invalid organism '$organism' on server '$instance'");
}

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection

unless ($adb->verifyArcturusUser(list=>1)) { # error message to STDERR
    $adb->disconnect();
    exit 1;
}

$adb->setLogger($logger);

ContigFactory->setLogger($logger);

#----------------------------------------------------------------
# if no project is defined, the loader allocates by inheritance
#----------------------------------------------------------------

my $project = 0;

# if no project identifier, use BIN as default project

$pidentifier = "BIN" unless $pidentifier;

if ($pidentifier) {
# collect project specification
    my %poptions;
    $poptions{project_id}  = $pidentifier if ($pidentifier !~ /\D/); # a number
    $poptions{projectname} = $pidentifier if ($pidentifier =~ /\D/); # a name
    if (defined($assembly)) {
        $poptions{assembly_id}  = $assembly if ($assembly !~ /\D/); # a number
        $poptions{assemblyname} = $assembly if ($assembly =~ /\D/); # a name
    }

    my ($projects,$m) = $adb->getProject(%poptions);
    unless ($projects && @$projects) {
        $logger->warning("Unknown project $pidentifier ($m)");
        $logger->severe("Missing default project");
        $adb->disconnect();
        exit 0;
    }

    if ($projects && @$projects > 1) {
        $logger->severe("ambiguous project identifier $pidentifier ($m)");
        $adb->disconnect();
        exit 0;
    }

    $project = $projects->[0];

    if ($project) {
        my $message = "Project '".$project->getProjectName."' accepted ";
        $message .= "as assigned project" if ($pinherit eq 'project');
        $message .= "as default project"  if ($pinherit ne 'project');
        $logger->warning($message);
    }
}

# test validity of project inheritance specification (re: ADBContig->putContig)
 
my %projectinheritance = (project => 1     , none => 1       , # fixed project
                          contiglength => 1, contigcount => 1, # inherit modes
                          readcount => 1);                     # inherit mode
 
unless ($projectinheritance{$pinherit}) {
    print STDERR "Invalid project inheritance option: $pinherit\n" .
       "Options available: none, readcount, contiglength, contigcount\n";
    $adb->disconnect();
    exit 0;
}

#----------------------------------------------------------------
# acquire a lock on the project
#----------------------------------------------------------------

# default behaviour : if project is locked, abort, unless ignore lock flag  

my $lockstatusfound;

if ($projectlock) {
# test if the project is locked
    $lockstatusfound = $project->getLockedStatus();

    if ($lockstatusfound) {
# project is locked; check if locked by current script user
        my $lockowner = $project->getLockOwner();
        my $scriptuser = $adb->getArcturusUser();
        unless ($lockowner eq $scriptuser) {
            $logger->error("Project $pidentifier is locked by $lockowner");
# prepare mail message
            $logger->error("import ABORTED");
            $adb->disconnect();
            exit 1;
	}
    }
# acquire the lock
    my ($lockstatus,$msg) = $project->acquireLock();
    unless ($lockstatus) {
        $logger->error("Project $pidentifier could not be locked: $msg");
        $logger->error("import ABORTED");
        $adb->disconnect();
        exit 1;
    }
# ?? $lockstatusfound = 1;
}

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# set-up tag selection

if (!$rtagtypeaccept || $rtagtypeaccept eq 'default') {
# use standard pattern to catch all tag types
    $rtagtypeaccept = '\w{3,4}';
}
elsif ($rtagtypeaccept eq 'standard') {
# no specification: use pre-defined list of accepted tags
    my $FTAGS = &tagList('FTAGS');
    my $STAGS = &tagList('STAGS');
    my $ETAGS = &tagList('ETAGS');
    $rtagtypeaccept = "$FTAGS|$STAGS|ETAGS";
}
else {
# replace any non-word symbol by '|' to act as separator in a list 
    $rtagtypeaccept =~ s/\W/|/g; 
    $logger->warning("readtags selected : $rtagtypeaccept");
}

#------------------------------------------------------------------------------
# collect options for contig factory
#------------------------------------------------------------------------------

my %poptions;

$poptions{acceptpadded} = 1           if $acceptpadded;
$poptions{linelimit} = $linelimit     if $linelimit;
$poptions{readlimit} = $readlimit     if $readlimit;
$poptions{consensus} = 1              if $consensus;

$poptions{progress}  = 1;
$poptions{silent}    = 1 unless defined($loglevel);

$poptions{contignamefilter} = $contignamefilter  if $contignamefilter;
$poptions{readtaglist}      = $rtagtypeaccept    if $rtagtypeaccept;
$poptions{contigtaglist}    = $ctagtypeaccept    if $ctagtypeaccept;

$poptions{blockobject} = {}; # hash table for read and contig names to ignore
# $poptions{nrofreads} = 100000; # approximate maximum nr of reads to be used

my %readtagoptions;

$readtagoptions{load} = 1 if $loadreadtags;
$readtagoptions{sync} = 1 if $syncreadtags;
$readtagoptions{echo} = 1 if $echoreadtags;
# print STDOUT "l $loadreadtags  s  $syncreadtags  e $echoreadtags\n";

my %contigtagoptions;

$contigtagoptions{load} = 1 if $loadcontigtags;
$contigtagoptions{test} = 1 if $testcontigtags;
$contigtagoptions{echo} = 1 if $echocontigtags;

ContigFactory->setLogger($logger);

Contig->setLogger($logger);

#------------------------------------------------------------------------------
#  
#------------------------------------------------------------------------------

$logger->info("contigs to be loaded")         if $contigload;
$logger->info("contigs to be tested")         if $contigtest;

$logger->info("contig tags to be loaded")     if $loadcontigtags; 
$logger->info("contig tags to be listed")     if $echocontigtags; 

$logger->info("read tags to be loaded")       if $loadreadtags; 
$logger->info("read tags to be listed")       if $echoreadtags; 
$logger->info("read tags to be synchronised") if $syncreadtags; 

$origin = 'Arcturus CAF parser' unless $origin;
$origin = 'Other' unless ($origin eq 'Arcturus CAF parser' ||
                          $origin eq 'Finishing Software');

if ($minnrofreads > 1) {
    $logger->info("Contigs with fewer than $minnrofreads reads are ignored");
}

$logger->monitor("Initial",memory=>1,timing=>1) if $usage;

#------------------------------------------------------------------------------
# in frugal mode: parse the input file and build an inventory of the caf file
#------------------------------------------------------------------------------

my $inventory = {};

my @inventory;

$adb->populateLoadingDictionaries(); # for edited or missing reads (should be in ADBREAD)

my $readversionhash = {};
$poptions{readversionhash} = $readversionhash;

my $uservhashlocal = 1; 

my @contiginventory;

if ($frugal) { # this whole block should go to a contig "factory"
# scan the file and make an inventory of objects
    my %options = (progress=>1,linelimit=>$linelimit);

    $logger->monitor("before inventory",memory=>1,timing=>1) if $usage;

    $inventory = ContigFactory->cafFileInventory($caffilename,%options);
    unless ($inventory) {
        $logger->severe("Could not make an inventory of $caffilename");
        exit 0;
    }
    my $nrofobjects = scalar(keys %$inventory) - 1;
    $logger->warning("$nrofobjects objects found on file $caffilename ");

# get contig names, count reads 

    my @readnames;
    
    @inventory = sort keys %$inventory; # better: sort on position in file

    my @contignames;
    foreach my $objectname (@inventory) { 
# ignore non-objects
        my $objectdata = $inventory->{$objectname};
# Read and Contig objects have data store as a hash; if no hash, ignore 
        next unless (ref($objectdata) eq 'HASH');

        my $objecttype = $objectdata->{Is};

        if ($objecttype =~ /contig/) {
            push @contignames,$objectname;
	}
        elsif ($objecttype =~ /read/) {
	    push @readnames,$objectname;
	}
        elsif ($objecttype =~ /assembly/) {
# here potential to process assembly information
	    next;
	}
	else {
            $logger->warning("Invalid object type $objecttype for $objectname");
	    next;
	}
# debugging stuff
#        next unless ($objectname =~ /Contig/);
#        next unless $debug;
#        $logger->debug(ContigFactory->listInventoryForObject($objectname),
#                                                              prefix=>0);
    }

    $logger->warning(scalar(@contignames)." contigs, "
                     .scalar(@readnames)." reads");

# test the readnames against reads in the database

    if (@readnames) {

        my %toptions = (readload=>$readload);
        $toptions{consensusread} = $consensusread if $consensusread;
        $toptions{noaspedcheck}  = $noaspedcheck  if $noaspedcheck;
        my $missing = &testreadsindatabase(\@readnames,%toptions);
        if ($missing) {
   	    $logger->warning("$missing reads still missing");
# abort in this case
	    $adb->disconnect();
	    exit 1;
	}

	$logger->warning("All reads identified in database");

# here build the read/version hashes for reads in the list, or defer to later

        unless ($uservhashlocal) {
#$logger->warning("building read version hash 1");
           ($readversionhash,$missing) = $adb->getReadVersionHash(\@readnames);
            if ($missing && @$missing) {
        	$logger->warning(scalar(@$missing)." reads still missing "
                                 ."or with undefined hashes in database");
            }
            $logger->warning("keys ".scalar(keys %$readversionhash));
        }
    }
    else {
        $logger->warning("CAF file $caffilename has no reads");
    }

    @contiginventory = @contignames;

    $logger->monitor("after inventory",memory=>1,timing=>1) if $usage;
}

$logger->flush();

my $fullscan = 0;

my $reads = []; # for reads with tags

my $blockobject = $poptions{blockobject};

my $loaded = 0;
my $missed = 0;
my $lastinsertedcontig = 0;

while (!$fullscan) {

    my $objects = [];
    my $truncated;

#--------------------- frugal mode ----------------------------

    if ($frugal) {
# get the next block of contig names to process
        my @contignames;
        while (my $objectname = shift @contiginventory) {
# this line should be 
            next if ($contignamefilter && $objectname !~ /$contignamefilter/);
	    $logger->info("contig name $objectname");
            push @contignames,$objectname;
	    last if (@contignames >= $blocksize);
	}

        my $nc = 0;
        if (@contignames) {
# extract a list of minimal Contig with corresponding Read instances
            my $nctbe = scalar(@contignames);
            $logger->warning("block of $nctbe contigs to be extracted") unless ($nctbe == 1);
            $logger->warning("next contig ($contignames[0]) to be extracted") if ($nctbe == 1);
            $poptions{noreads} = 1 if $uservhashlocal;
            $logger->monitor("before extract ",memory=>1,timing=>1) if $usage;
            $objects = ContigFactory->contigExtractor(\@contignames,$readversionhash,
                                                                    %poptions);
# count number of contigs retrieved
            my @contigs;
            foreach my $object (@$objects) {
                push @contigs,$object if (ref($object) eq 'Contig');
	    }
# test contig count
            $nc = scalar(@contigs);
            unless ($nc == $nctbe) {
                $logger->fine("contig inventory mismatch: extracted $nc against $nctbe");
# find contigs not returned and add to inventory with unshift TO BE DEVELOPED
	    }

# unless the read hash was built previously, continue with the contig extraction

	    if ($uservhashlocal) {
                my @reads;
                my @names;
                foreach my $contig (@contigs) {
                    my $reads = $contig->getReads();
                    push @reads,@$reads if $reads;
                    foreach my $read (@$reads) {
                        push @names,$read->getReadName();
		    }
                }
# get the readversion hash and extract the reads
               ($readversionhash, my $missing) = $adb->getReadVersionHash(\@names);
#  $logger->warning(scalar(@$missing)." reads still missing "
#                  ."or with undefined hashes in database");
                my $ereads = ContigFactory->readExtractor(\@reads,$readversionhash,
                                                                  %poptions);
                unless (scalar(@$ereads) == scalar(@reads)) {
	   	    $logger->error("There are missing reads");
                }
# remove pointers to Read instances
                undef @reads;
                undef $ereads;
	    }
            $logger->monitor("after extract",memory=>1,timing=>1) if $usage;
        }
        else {
            $fullscan = 1;
#            ContigFactory->closeFile();            
	}
        $logger->monitor("frugal (next $nc contigs)",memory=>1,timing=>1) if $usage;
    }

#--------------------- full scan ----------------------------

    else {

       ($objects,$truncated) = ContigFactory->cafFileParser($caffilename,%poptions);
# the output consists of an object list of contigs and/or additional reads
        $fullscan = 1 unless $truncated;
        $fullscan = 1 if ($truncated && $linelimit && $truncated >= $linelimit);
print STDOUT "full scan $fullscan $truncated   @$objects \n";

        unless ($fullscan) {
# register contigs && reads currently returned in blocking hash
            foreach my $object (@$objects) {
                if (ref($object) eq 'Contig') {
                    $blockobject->{$object->getContigName()}++;
                    my $creads = $object->getReads();
                    push @$reads,@$creads if ($loadreadtags || $echoreadtags); # Read
                    foreach my $read (@$creads) {
                        $blockobject->{$read->getReadName()}++;
	 	    }              
                }
                elsif (ref($object) eq 'Read') {
                    $blockobject->{$object->getReadName()}++;
                    push @$reads,$object if ($loadreadtags || $echoreadtags) # Read
                }
	    }
        }
        $logger->monitor("fullscan memory usage",memory=>1,timing=>1) if $usage;
print STDOUT " end no frugal scan\n";
    }

#------------------------------------------------------------------------------
# here a new block (or all) of contigs have been extracted
#------------------------------------------------------------------------------
# don forget to load dictinaries


    $logger->flush();

    if ($parseonly && @$objects) {
        $logger->warning("block of ".scalar(@$objects)." processed ");
        undef @$objects unless ($echocontigtags || $echoreadtags);
    }

    my $reads = [];

    last unless @$objects;

    $logger->info("block of ".scalar(@$objects)." contigs to be processed");

    while (my $contig = shift @$objects) {

        next unless (ref($contig) eq 'Contig');

        my $contigname = $contig->getContigName();

        if ($listcontigs) {
             next if ($contigname !~ /$listcontigs/);
             $logger->flush();
             $contig->writeToCaf(*STDOUT);
             next;
	}

        $logger->info("Processing contig $contigname");

# here remove the references to the Contig and its Reads from the inventory

        if ($frugal) {
# delete the contig name and its reads from the inventory
            my @remove;
            push @remove,$contig->getName();
            my $reads = $contig->getReads();
            foreach my $read (@$reads) {
                push @remove,$read->getReadName();
                next unless  $read->hasSequence();
                $logger->info("read ".$read->getReadName()." has sequence!");
	    }
	    ContigFactory->removeObjectFromInventory(\@remove);
        }

#------------------------------------------------------------------------------
# collect reads for tag processing
#------------------------------------------------------------------------------

	if (keys %readtagoptions) {    
            my $creads = $contig->getReads();    
            $logger->info("contig has ".scalar(@$creads)." reads");
            foreach my $read (@$creads) {
                my $readname = $read->getName();
                $logger->fine("read $readname");
                undef $inventory->{$readname} if $frugal; # remove from inventory
                next unless $read->hasTags();
                $logger->info("read $readname has tags");
                push @$reads,$read;
	    }
	}

# register the 
 
        $contig->setOrigin($origin);

# test  minimum number and/or  maximum number of reads

        my $identifier = $contig->getContigName();

        my $nr = $contig->getNumberOfReads();

        if ($nr < $minnrofreads) {
            $logger->warning("$identifier has less than $minnrofreads reads");
            next;
        }

        if ($maxnrofreads && $nr > $maxnrofreads) {
            $logger->warning("$identifier has more than $maxnrofreads reads");
	    next;
        }

# process tags to weed out possible duplicates on input caf file

        $contig->getTags(0,sort=>'full',merge=>1);


        if ($contig->isPadded()) {
# convert padded to unpadded (NOT YET OPERATIONAL)
            unless ($contig = $contig->toUnpadded()) {
                $logger->severe("Cannot de-pad contig $identifier");
                next;
	    }
        }

# &testeditedconsensusreads($contig); 

        if ($contigload) {

	    $logger->info("Loading contig into database");

# present the contig to the database; load, including contig tags

            my %loptions = (setprojectby => $pinherit,
                            dotags  => $ctagtypeaccept);
# inherittag options ( default .. not: REPT RP20 )
            $loptions{prohibitparent} = 1    if $withoutparents;
	    $loptions{acceptversionzero} = 1 if $acceptversionzero;
	    $loptions{annotation} = $annotationtags if $annotationtags;
	    $loptions{finishing} = $finishingtags if $finishingtags;

            my ($added,$msg) = $adb->putContig($contig, $project,%loptions);

            if ($added) {
                $loaded++;
                $lastinsertedcontig = $added;
                $logger->info("Contig $identifier with $nr reads :"
                             ." status $added, $msg");
#                $loaded++ unless ...;
            }
            else {
                $logger->warning("Contig $identifier with $nr reads was not added:"
                                ."\n$msg",preskip=>1);
                $missed++;
# for discontinuous contigs: try break
                if ($msg =~ /discontinuity/i) {

                    next unless $breakcontig;

                    if ($loglevel) { # ???
                        $contig->setSequence();
                        $contig->writeToCaf(*STDOUT,noreads=>1);
                        next;
		    }
	# or try recovery
                    $logger->warning("Splitting contig with discontinuity");
                    my $contigs = $contig->break();
                    push @$objects,@$contigs if ($contigs && @$contigs > 1);
		    $contig->erase(); # enable garbage collection
                    next;
   	        }
# $adb->clearLastContig(); ?
            }
#$logger->monitor("memory usage after loading contig ".$contig->getContigName(),memory=>1);
        }

        elsif ($contigtest || $loadcontigtags || $testcontigtags) {

# present the contig to the database and compare with existing contigs

# &testeditedconsensusreads 
	    $logger->info("Testing contig against database");

            if ($contig->isValid(forimport => 1)) {

                my %toptions = (setprojectby => $pinherit,noload => 1);
                $toptions{prohibitparent} = 1 if $withoutparents;
                $toptions{nokeep} = 1 if $testcontigtags; # ??
#                           dotags  => $ctagtypeaccept);
    	        $toptions{annotation} = $annotationtags if $annotationtags;
	        $toptions{finishing} = $finishingtags if $finishingtags;

                my ($added,$msg) = $adb->putContig($contig,$project,%toptions);

                $msg = "is a new contig" unless $msg;
                my @msg = split ';',$msg;        
                $logger->warning("Status of contig $identifier with $nr reads:",preskip=>1);
                foreach my $line (@msg) {
                    $logger->warning($line);
		}
                $contig->setContigID($added) if $added;
                my $diagnose =($contigtest > 1) ? 2 : 0;
		$contig->isValid(diagnose=>$diagnose);
	        if ($contig->hasContigToContigMappings()) {
                    $logger->warning($contig->getContigName()
				     ." has contig-to-parent links");
                    my $mappings = $contig->getContigToContigMappings();
	            foreach my $mapping (@$mappings) {
	                $logger->warning($mapping->assembledFromToString || "empty link\n");
	            }
                }
                if ($diagnose) {
   		    my $parents = $contig->getParentContigs();
		    $logger->warning("parents:",ss=>1);
		    foreach my $parent (@$parents) {
                        $parent->isValid(diagnose=>$diagnose);
		    }
		}
            }
	    else {
                my $diagnosis = $contig->getStatus();
                $logger->severe("Invalid contig $identifier: $diagnosis");
	    }
        }

# dump/test/echo the contig tags

        if (keys %contigtagoptions) {

           my ($status,$msg) = &processcontigtags($contig,$identifier,
                                                          %contigtagoptions);
           $logger->info($msg)    if ($status == 1); # success
           $logger->warning($msg) if ($status == 2); # success
           $logger->severe($msg)  unless $status; # error
	}

# dump/echo the readtag

        if (@$reads && keys %readtagoptions) {

            &processreadtags($reads,%readtagoptions);
# remove references to the reads
            foreach my $read (@$reads) {
                $read->erase(); 
	    }
            undef @$reads;
        }

# destroy the contig and possible related contigs to enable garbage collection

#$logger->monitor("after processing contig ".$contig->getContigName(),memory=>1) if $usage;
        if (my $parents = $contig->getParentContigs()) {
            foreach my $parent (@$parents) {
                $parent->erase();
            }
            undef @$parents;
        }
        $contig->erase();
        undef $contig;
    }
} 

# process any remaining reads with tags

if (@$reads && keys %readtagoptions) {
    &processreadtags($reads,%readtagoptions);
}

# test & report for contigs missed

$logger->warning("$loaded contigs loaded");
$logger->warning("$missed contigs skipped") if $missed;

# ad import mark on the project

if ($loaded && $project) {
# Q? do you register  an import when nothing was added as an import?
#if ($project && (newcontig || $newcontigtag || $newreadtag) {
    unless ($gap4dbname) {
        $gap4dbname = `pwd`;
        chomp $gap4dbname;
    }
    $project->setGap4Name($gap4dbname); # 
    $project->markImport();
}

# read-back lastly inserted contig (meta data) to check on OS cache dump

if ($lastinsertedcontig && $safemode) {
# pause to be sure the OS cache of the server has emptied 
# and the data have to be read back from disk.
#    $adb->flushTables();
    sleep(10); 
# readback the contig (or all contigs?)
    my $contig = $adb->getContig(contig_id=>$lastinsertedcontig,
                                 metadataonly=>1);
# test project specification
    if ($contig->getProjectID() > 0) {
        $logger->severe("Safemode test PASSED");
    }
    else {      
        $logger->severe("Safemode test FAILED");
    }
}

# finally update the meta data for the Assembly and the Organism

# $adb->updateMetaData;

unless ($lockstatusfound && $autolockmode) {
# in autolock: the project was not locked before; return to this state
# not in autolock: always unlock to project after input is finished
    $project->releaseLock() || $logger->severe("could not release lock");
}

$adb->disconnect();

# send messages to users, if any

my $addressees = $adb->getMessageAddresses(1);

foreach my $user (@$addressees) {
    my $message = $adb->getMessageForUser($user);
    &sendMessage($user,$message) if $message;
}


exit 0 if $loaded;  # no errors and contigs loaded

exit 1; # no errors but no contigs loaded

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------

sub testreadsindatabase {
# returns number of reads (still) ,missing after tries to load them
    my $readnames = shift; # array reference
    my %options = @_;

    return undef unless (ref($readnames) eq 'ARRAY' && @$readnames);

# test if the reads are present in the arcturus database

    my $missingreads = $adb->getReadsNotInDatabase($readnames);

    return 0 unless ($missingreads && @$missingreads);
    
    $logger->warning(scalar(@$missingreads)." missing reads identified");

    return scalar(@$missingreads) unless $options{readload};

    $logger->warning("Trying to load ".scalar(@$missingreads)." missing reads");

# either fire off the traceserver loader script

    my $updatereads = 1;
    if ($updatereads) {
        my $arcturus_home = "/software/arcturus";
        my $import_script = "${arcturus_home}/utils/read-loader";
        my $command = "$import_script "
                    . "-instance $instance -organism $organism "
                    . "-source traceserver -group $organism "
                    . "-minreadid auto";
        &mySystem($command);
    }

# or use the TraceServer module to pull out individual reads

    else {
        my $readfactory = new TraceServerReadFactory(group=>$organism);
        my %loadoptions;
# possibly add load options ...
        foreach my $readname (@$missingreads) {
            my $read = $readfactory->getReadByName($readname);
            next if !defined($read);
            $logger->info("Storing $readname (".$read->getReadName.")");
            my ($success,$errmsg) = $adb->putRead($read, %loadoptions);
            unless ($success) {
                $logger->severe("Unable to fetch read $readname: $errmsg");
                next;
	    }
            $adb->putTraceArchiveIdentifierForRead($read);
            $adb->putTagsForReads([($read)]) if $read->hasTags();
        }
    }

# and test the missing reads again against the database

    my $stillmissing = $adb->getReadsNotInDatabase($missingreads);
    
    return 0 unless ($stillmissing && @$stillmissing);

    my $stillmissingreads = scalar(@$stillmissing);
    $logger->warning("$stillmissingreads reads remain missing");

# the reads still missing are treated as consensus reads, load from CAF file

    my $crn = $options{consensusread};
    my $nac = $options{noaspedcheck};

    while (@$stillmissing) {
        my @nameblock = splice @$stillmissing,0,1000;
	$logger->info("extracting next ".scalar(@nameblock)." reads");
        my $reads = ContigFactory->readExtractor(\@nameblock,0,fullreadscan=>1);
        unless ($reads && @$reads) {
    	    $logger->warning("FAILED to fetch any reads");
	    next;
	}
	$logger->warning(scalar(@$reads)." reads to be loaded into database ");

        foreach my $read (@$reads) {
            my $readname = $read->getReadName();
            $logger->warning("read to be stored ($readload) : $readname");
            if ($read->isEdited()) {
                undef $read->{alignToTrace};
                $logger->warning("required un-edit edited read $readname");
#                next; # ignore here, or override ?
 	    }

# move most of this to ReadFactory ? 
            unless ($read->getStrand()) {
		$read->setStrand('Forward');
		$logger->info("Strand set as 'Forward' for read $readname");
	    }

            unless ($read->getPrimer()) {
                $read->setPrimer("Custom_primer");
	    }

            unless ($read->getChemistry()) {
                $read->setChemistry("Dye_primer");
	    }

            unless ($read->getProcessStatus()) {
                $read->setProcessStatus("PASS"); # implicit in being on the gap4 export
	    }

            my %loadoptions;
            my $iscr = 0; # consensus read flag
            if (my $readtags = $read->getTags()) {
# check if the read is marked as consensus read
		foreach my $tag (@$readtags) {
                    $iscr = 1 if ($tag->getType() eq 'CONS');
		}
	    }
            
            if ($crn && ($crn eq 'all' || $readname =~ /$crn/) || $iscr) {
                $loadoptions{skipaspedcheck} = 1;
                $loadoptions{skipligationcheck} = 1;
#                $loadoptions{skipchemistrycheck} = 1;
                $loadoptions{skipqualityclipcheck} = 1;
            }
            if ($nac && ($nac eq 'all' || $readname =~ /$nac/)) {
                $loadoptions{skipaspedcheck} = 1;
            }

            next unless $readload;
            my ($status,$msg) = $adb->putRead($read,%loadoptions);
            unless ($status) {
		$logger->warning("FAILED to load read $readname : ".$msg);
		next;
	    }
            $stillmissingreads--;
        }
    }
    return $stillmissingreads; # number of reads still missing
}

#-------------------------------------------------------------------------------

sub testeditedconsensusreads {
    my $contig = shift;
#    my $adb = shift;

    my $reads = $contig->getReads();

    foreach my $read (@$reads) {
	next unless $read->isEdited();
# first test if the read is already present and if so its length
        my $readname = $read->getReadName();
	next unless ($readname =~ /^contig/); # consider only consensus reads
        my $readlgth = $read->getSequenceLength();
# if a version 0 already exists, compare
        if (my $dbread = $adb->getRead(readname=>$readname)) {
# if the lengths are equal, remove the align to trace data 
$logger->warning("version 0 already exists");
            if ($dbread->getSequenceLength == $readlgth) {
                undef $read->{alignToTrace};
            }
# otherwise the new read is treated as an edited read
            next;
        }
# there is no version 0: either approximately restore the original version
# or remove the alignment record to treat this read as version 0

#        next unless ($readrepair);
$logger->warning("edited read $readname");
        my $mapping = $read->getAlignToTraceMapping();
$logger->warning($mapping->toString());
        my $original = $mapping->transformString($read->getSequence());
        my $oquality = $mapping->transformArray($read->getBaseQuality());

$logger->warning("read sequence:\n".$read->getSequence());
$logger->warning("restored original:\n$original");

#        exit unless ($readname eq 'contig00143_0105');
# restore original read and put in database       
        my $originalread = new Read($readname);
        $originalread->setSequence($original);
        $originalread->setBaseQuality($oquality);
my %loadoptions;        
        my ($success,$errmsg) = $adb->putRead($read, %loadoptions);
	next if $success;
        $logger->severe("Unable to put read $readname: $errmsg");
    }
}

#-------------------------------------------------------------------------------

sub processreadtags {
    my $reads = shift; # array ref to a list of reads
    my %options = @_;

    $logger->info("Processing readtags for ".scalar(@$reads)." reads");

    if ($options{load}) { # load (new) read tags
        my $success = $adb->putTagsForReads($reads,autoload=>1);
        $logger->debug("put read tags : success = $success");
    }

    if ($options{sync}) { # load (new) tags and remove existing tags not in list
        my $success = $adb->putTagsForReads($reads,autoload=>1,synchronise=>1);
        $logger->debug("synchronise read tags : success = $success");
    }

    if ($options{echo}) {
# echoreadtags
        $logger->warning("Read Tags Listing\n");
        foreach my $read (@$reads) {
            my $tags = $read->getTags();
            my $readname = $read->getReadName();
            unless ($tags && @$tags) {
                $logger->warning("No tags (anymore) on read $readname");
	      	next;
	    }
            $logger->warning("read $readname : tags ".scalar(@$tags));
# list all tags
            foreach my $tag (@$tags) {
                $logger->warning($tag->writeToCaf());
            }
# list the tags which need to be loaded
            my $tagstobeloaded = $adb->putTagsForReads([($read)],noload=>1);
            if (ref($tagstobeloaded) eq 'ARRAY') {
                $logger->warning("Tags to be loaded : ".scalar(@$tagstobeloaded));
                foreach my $tag (@$tagstobeloaded) {
                    $logger->warning($tag->writeToCaf());
                }
            }
            else {
                $logger->info("NO tags to be loaded"); 
            }
        }
    }
}

#-------------------------------------------------------------------------------

sub processcontigtags { # per contig
    my $contig = shift; # contig instance
    my $identifier = shift; # identigfier in this script
    my %options = @_;

# returns 1 for success, 0 for failure

    unless ($contig->hasTags()) {
        return 1, "No (new) contig tags found for $identifier";
    }

    my $tags = $contig->getTags();

    if ($options{load} || $options{test}) {

# test if the contig ID is defined

        unless ($contig->getContigID()) {
	    return 0, "undefined arcturus contig ID for $identifier";
        }

        my $cid = $contig->getContigID();
        $logger->info("contig $cid has ".scalar(@$tags)." tags");

        my $newtags;

        if ($options{load}) {
            $newtags = $adb->putTagsForContig($contig,noload=>0,testmode=>1);
            return 1, "$newtags new tags added for contig $cid";
        }
	
        if ($options{test}) {
            $logger->warning("testing tags against database",ss=>1);
            $newtags = $adb->enterTagsForContig($contig);
            return 2, "$newtags new tags detected for contig $cid";
	}
    }

    if ($options{echo}) {
        $logger->warning("contig $identifier has ".scalar(@$tags)." tags");
        $logger->warning("Tags for contig ".$contig->getContigName());
        foreach my $tag (@$tags) {
            $logger->warning($tag->writeToCaf(0,annotag=>1));
	}
        return 1,"OK";
    }
}

#------------------------------------------------------------------------

sub sendMessage {
    my ($user,$message) = @_;

    print STDOUT "message to be emailed to user $user:\n$message\n\n";
$user="ejz+$user"; # temporary redirect

    my $mail = new Mail::Send;
    $mail->to($user);
    $mail->subject("Arcturus contig transfer requests");
    $mail->add("X-Arcturus", "contig-transfer-manager");
    my $handle = $mail->open;
    print $handle "$message\n";
    $handle->close;
    
}

#------------------------------------------------------------------------

sub tagList {
# e.g. list = tagList('FTAGS')
    my $name = shift;

# Finishers tags

    my @FTAGS = ('FINL','FINR','ANNO','FICM','RCMP','POLY','STSP',
                 'STSF','STSX','STSG','COMM','RP20','TELO','REPC',
                 'WARN','DRPT','LEFT','RGHT','TLCM','ALUS','VARI',
                 'CpGI','NNNN','SILR','IRPT','LINE','REPA','REPY',
                 'REPZ','FICM','VARD','VARS','CSED','CONS','EXON',
                 'SIL' ,'DIFF');

# software TAGS

    my @STAGS = ('ADDI','AFOL','AMBG','CVEC','SVEC','FEAT','REPT',
                 'MALX','MALI','XMAT','OLIG','COMP','STOP','PCOP',
                 'LOW' ,'MOSC','STOL','TEST','CLIP');

# edit tags

    my @ETAGS = ('EDIT','DONE','MISS','MASK','UNCL','CONF','CLIP');

    my $list  = eval "join '|',\@$name";
}

# The next subroutine was shamelessly stolen from WGSassembly.pm

sub mySystem {
    my ($cmd) = @_;

    my $res = 0xffff & system($cmd);
    return 0 if ($res == 0);

    printf STDERR "system(%s) returned %#04x: ", $cmd, $res;

    if ($res == 0xff00) {
	print STDERR "command failed: $!\n";
        return 1;
    }
# the next two conditions abort execution
    elsif ($res > 0x80) {
	$res >>= 8;
	print STDERR "exited with non-zero status $res\n";
    } 
    else {
	my $sig = $res & 0x7f;
	print STDERR "exited through signal $sig";
	if ($res & 0x80) {print STDERR " (core dumped)"; }
	print STDERR "\n";
    }
    exit 1;
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {

    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n\n" if $code;

    unless ($organism && $instance && $caffilename) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus organism database\n" unless $organism;
        print STDERR "-instance\tArcturus database instance\n" unless $instance;
        print STDERR "-caf\t\tcaf file name\n" unless $caffilename;
        print STDERR "\n";
    }
 
    print STDERR "OPTIONAL PARAMETERS for project inheritance:\n";
    print STDERR "\n";
    print STDERR "-spb\t\t(setprojectby) assign project to contigs based on "
                ."properties of parent\n\t\t      contigs: "
                ."readcount, contigcount, contiglength or none\n";
    print STDERR "-dp\t\t(defaultproject) ID or name of project to be used if ";
    print STDERR "the inheritance\n\t\t     mechanism does not find a project\n";
    print STDERR "-ap\t\t(assignproject) ID or name of project to which "
                ."contigs are assigned\n\t\t     (overrides setprojectby)\n";
    print STDERR "-p\t\t(project) alias of assignproject\n";
    print STDERR "-a\t\t(assembly) ID or name; required in case of "
               . "ambiguous project name\n";
    print STDERR "\n";
#    print STDERR "OPTIONAL PARAMETERS for project locking:\n";
#    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for tag processing:\n";
    print STDERR "\n";
    print STDERR "-lct\t\t(loadcontigtags) default; re-activate contig tag loading when using -noload\n";
    print STDERR "-nlct\t\t(noloadcontigtags) as it says; also active when using -noload option\n";
    print STDERR "\n";
    print STDERR "-ctt\t\t(contigtagtype)  comma-separated list of explicitly defined tags (default all)\n";
    print STDERR "-ats\t\t(annotationtags) comma-separated list of explicitly defined tags\n";
    print STDERR "-fts\t\t(finishingtags)  comma-separated list of explicitly defined tags\n";
    print STDERR "\n";
    print STDERR "-lrt\t\t(loadreadtags) default; re-activate read tag loading when using -noload\n";
    print STDERR "-nlrt\t\t(noloadreadtags) as it says; also active when using -noload option\n";
    print STDERR "\n";
    print STDERR "-rtt\t\t(readtagtype) comma-separated list of explicitly defined tags (def: all)\n";
    print STDERR "-syncrt\t\t(synchronisereadtags) load tags; retire tags which are NOT on caf file\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for tag testing:\n";
    print STDERR "\n";
    print STDERR "-tct\t\t(testcontigtags) against the database\n";
    print STDERR "-sct\t\t(showcontigtags) list contigtags found on caf file\n";
    print STDERR "\n";
    print STDERR "-srt\t\t(showreadtags) default; re-activate read tag loading when using -noload\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for read auto-loading:\n";
    print STDERR "\n";
    print STDERR "the loader will check for missing reads and if not found in the\n";
    print STDERR "database will (try to) load them from the CAF file. The reads \n";
    print STDERR "concerned are usually consensus reads, but not necessarilly. \n";
    print STDERR "Therefore the reads are tested for completeness. This test can be\n";
    print STDERR "overridden by using the -crn or -nac switches:\n";
    print STDERR "\n";
    print STDERR "-nlr\t\t(noloadreads) as it says; if reads are missing the loader terminates\n";
    print STDERR "-dlr\t\t(doloadreads) re-activate readloading from caf file (after e.g. -noload)\n";
    print STDERR "-crn\t\t(consensusreadname) explictly specifying astring matching the\n";
    print STDERR "\t\tthe readname; alternatively, use \"all\"\n";
    print STDERR "-nac\t\t(no asped date check) to suppress only this test\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for contig selection:\n";
    print STDERR "\n";
    print STDERR "-minimum\tminimum number of reads per contig\n";
    print STDERR "-maximum\tmaximum number of reads per contig\n";
    print STDERR "-filter\t\tcontig name substring or regular expression\n";
    print STDERR "\n";
    print STDERR "-wp\t\t(withoutparents) only accept contigs without parents\n";
    print STDERR "\n";
    print STDERR "-nb\t\t(nobreak) accept only contigs with continuous coverage\n";
    print STDERR "\n";
    print STDERR "-bs\t\t(blocksize) process the contigs in blocks of size specified\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for testing:\n";
    print STDERR "\n";
    print STDERR "-tc\t\t(testcontig) against the database without loading\n";
    print STDERR "-noload\t\tskip loading into database (test mode)\n";
    print STDERR "-notest\t\t(in combination with noload: "
                 . "skip contig processing altogether\n";
    print STDERR "-parseonly\ta shortcut to do just that\n";
    print STDERR "-list\t\tlist the contig(s) read from the file in caf format\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for input/output:\n";
    print STDERR "\n";
    print STDERR "-stdin\t\tread input from STDIN instead of caf file\n";
    print STDERR "\n";
    print STDERR "-log\t\tfile name for standard output (default STDOUT)\n";
    print STDERR "-out\t\t(outputfile) name for special output (e.g. listing missing reads);\n"
               . "\t\tdefault none\n";
    print STDERR "\n";
    print STDERR "-minerva\tadd a prefix to output to be recognised by Minerva\n";
    print STDERR "\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "-verbose\t(no value) for more progress info\n";
    print STDERR "-debug\t\t(no value) you don't want to do this\n";
    print STDERR "\n";
    print STDERR "-gap4name\tname entered in database import log for origin of data\n";
    print STDERR "\n";
#    print STDERR "-safemode\tread the last contig back from the database to confirm storage\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS to be deprecated:\n";
    print STDERR "\n";
    print STDERR "-ll\t\t(linelimit) number of lines parsed of the CAF file\n";
#    print STDERR "-rl\t\t(readlimit) number of reads parsed on the CAF file\n";
    print STDERR "-test\t\tnumber of lines parsed of the CAF file\n";
    print STDERR "-consensus\talso load consenmsus sequence\n";
    print STDERR "-nf\t\t(nofrugal, no value)\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
