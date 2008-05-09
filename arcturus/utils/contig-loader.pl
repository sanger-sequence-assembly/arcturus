#!/usr/local/bin/perl -w

use strict; # Constraint variables declaration before using them

use ArcturusDatabase;
use Read;
use Contig;
use Mapping;
use Project;
use Tag;

use FileHandle;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;
my $cafFileName;
my $gap4name;

my $lineLimit;             # specifying a line limit implies test mode 
my $cnFilter = '';         # test contig names for this substring or RE
my $cnBlocker;             # contig name blocker, ignore contig names of age 0
my $rnBlocker;             # ignore reads like pattern
my $minOfReads = 1;        # default load all contigs, including single-read
my $loadreadtags = 1;      # default load read tags
my $readtaglist;           # allows specification of individual tags
my $contigtag = 2;         # contig tag processing
my $origin;

my $assembly;
my $pidentifier;           # projectname for which the data are to be loaded
my $pinherit = 'readcount'; # project inheritance method
my $isdefault = 0;

my $noacquirelock = 0;
my $autolockmode = 1;

my $lowMemory;             # specify to minimise memory usage
my $usePadded = 0;         # 1 to allow a padded assembly
my $consensus;             # load consensus sequence
my $noload = 0; # CHANGE to 0
my $notest = 0;
my $list = 0;
my $batch = 0;
my $debug = 0;
my $contigtagdebug = 0;

my $readrepair;

my $safemode = 0;

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|cafdefault|out|consensus|"
               . "project|defaultproject|test|minimum|filter|ignore|list|"
               . "gap4name|g4n|repair|"
               . "setprojectby|spb|readtaglist|rtl|noreadtags|nrt|"
               . "noacquirelock|nal|dounlock|"
               . "ignorereadnamelike|irnl|contigtagprocessing|ctp|notest|"
               . "frugal|padded|noload|safemode|verbose|batch|info|help|debug|contigtagdebug";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $pidentifier      = shift @ARGV  if ($nextword eq '-project');

    $noacquirelock    = 1            if ($nextword eq '-noacquirelock');
    $noacquirelock    = 1            if ($nextword eq '-nal');

    $autolockmode     = 0            if ($nextword eq '-dounlock');

    $pidentifier      = shift @ARGV  if ($nextword eq '-defaultproject');
    $isdefault        = 1            if ($nextword eq '-defaultproject');

    $lineLimit        = shift @ARGV  if ($nextword eq '-test');

    $readrepair       = 1            if ($nextword eq '-repair');

    $consensus        = 1            if ($nextword eq '-consensus');

    $logLevel         = 0            if ($nextword eq '-verbose'); 

    $logLevel         = 2            if ($nextword eq '-info'); 

    $debug            = 1            if ($nextword eq '-debug'); 

    $contigtagdebug   = 1            if ($nextword eq '-contigtagdebug');

    $minOfReads       = shift @ARGV  if ($nextword eq '-minimum');

    $cnFilter         = shift @ARGV  if ($nextword eq '-filter'); 

    $loadreadtags     = 0            if ($nextword eq '-noreadtags');
    $loadreadtags     = 0            if ($nextword eq '-nrt');

    $usePadded        = 1            if ($nextword eq '-padded');

    $origin           = shift @ARGV  if ($nextword eq '-origin');

    $lowMemory        = 1            if ($nextword eq '-frugal');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $cafFileName      = 'default'    if ($nextword eq '-cafdefault');

    $gap4name         = shift @ARGV  if ($nextword eq '-gap4name');

    $cnBlocker        = 1            if ($nextword eq '-ignore');

    $rnBlocker        = shift @ARGV  if ($nextword eq '-ignorereadnamelike');
    $rnBlocker        = shift @ARGV  if ($nextword eq '-irnl');

    $contigtag        = shift @ARGV  if ($nextword eq '-ctp');
    $contigtag        = shift @ARGV  if ($nextword eq '-contigtagprocessing');

    $readtaglist      = shift @ARGV  if ($nextword eq '-readtaglist');
    $readtaglist      = shift @ARGV  if ($nextword eq '-rtl');

    $outputFile       = shift @ARGV  if ($nextword eq '-out');

    $noload           = 1            if ($nextword eq '-noload');

    $notest           = 1            if ($nextword eq '-notest');

    $pinherit         = shift @ARGV  if ($nextword eq '-setprojectby');
    $pinherit         = shift @ARGV  if ($nextword eq '-spb');

    $list             = 1            if ($nextword eq '-list');

    $batch            = 1            if ($nextword eq '-batch');

    $safemode         = 1            if ($nextword eq '-safemode');

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

$outputFile = 'STDOUT' if ($noload && !$outputFile);

my $logger = new Logging($outputFile);
 
$logger->setStandardFilter($logLevel) if $logLevel; # set reporting level

$logger->setDebugStream('STDOUT',list=>1);

$logger->setBlock('debug',unblock=>0) unless $debug;

$logger->setBlock('special',unblock=>1) if $debug; # defaults to STDOUT

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage(0,"Missing organism database") unless $organism;

&showUsage(0,"Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
	   	                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}

$adb->setLogger($logger);

#----------------------------------------------------------------
# test the CAF file name
#----------------------------------------------------------------
        
&showUsage("Missing CAF file name") unless ($cafFileName || $batch);

if ($cafFileName && $cafFileName eq 'default') {
# use the default assembly caf file in the assembly repository
    my $PR = new PathogenRepository();
    $cafFileName = $PR->getDefaultAssemblyCafFile($organism);
    $logger->info("Default CAF file used: $cafFileName"); 
}

# test existence of the caf file

if ($cafFileName) {
    &showUsage("CAF file $cafFileName does not exist") unless (-e $cafFileName);
}

#----------------------------------------------------------------
# if no project is defined, the loader allocates by inheritance
#----------------------------------------------------------------

my $project = 0;

my $override = 0;
unless ($pidentifier) {
# prime for default project search
    $pidentifier = "BIN";
    $override = 1;
}

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
        $adb->disconnect();
        exit 1 unless $override; # exit with error status
        $logger->warning("No default project available");
    }

    if ($projects && @$projects > 1) {
        $logger->warning("ambiguous project identifier $pidentifier ($m)");
        $adb->disconnect();
        exit 1 unless $override; # exit with error status
    }

    $project = $projects->[0] if ($projects && @$projects >= 1);

    $pinherit = 'project' unless ($isdefault || $override);

    if ($project) {
        my $message = "Project '".$project->getProjectName."' accepted ";
        $message .= "as assigned project" unless ($isdefault || $override);
        $message .= "as default project" if ($isdefault || $override);
        $logger->warning($message);
    }
}

unless ($project || $noacquirelock) {
    $logger->error("Undefined project");
    exit 1; # exit with error status
}

# test validity of project inheritance specification
 
my @projectinheritance = ('project','none',
                          'readcount','contiglength','contigcount');
my $identified = 0;
foreach my $imode (@projectinheritance) {
    $identified = 1 if ($pinherit eq $imode);
}
unless ($identified) {
    $logger->error("Invalid project inheritance option: $pinherit");
    $logger->error("Options available: none, readcount, contiglength, contigcount");
    $adb->disconnect() if $adb;
    exit 1; # exit with error status
}

print "readnameblocker $rnBlocker\n" if $rnBlocker;

#----------------------------------------------------------------
# open file handle for input CAF file
#----------------------------------------------------------------

my $CAF;
if ($cafFileName) {
    $CAF = new FileHandle($cafFileName, "r");
}
else {
    $CAF = *STDIN;
    $cafFileName = "STDIN";
}
       
&showUsage("Invalid caf file name") unless $CAF;

#----------------------------------------------------------------
# acquire lock on project
#----------------------------------------------------------------

my $lockedonentry;

unless ($noacquirelock) {

# Here only probe the current lock status; if locked do not unlock afterwards

    $lockedonentry = $project->getLockedStatus();

# now try to acquire the lock; if already locked this will only succeed if
# this user already owns the lock
     
    my ($lockstatus,$msg) = $project->acquireLock();
    unless ($lockstatus) {
	$logger->error("Project $pidentifier could not be locked: $msg");
        $logger->error("import ABORTED");
        $adb->disconnect() if $adb;
        exit 1; # exit with error status
    }
    $logger->warning($msg);
}

#----------------------------------------------------------------
# ignore already loaded contigs? then get them from the database
#----------------------------------------------------------------

$cnBlocker = $adb->getExistingContigs() if $cnBlocker;
$cnBlocker = {} unless $cnBlocker; # ensure it's a hash reference

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# allocate basic objects

my ($read, $mapping, $contig);

my (%contigs, %reads, %mappings);

# set-up tag selection

my $FTAGS = &tagList('FTAGS');
my $STAGS = &tagList('STAGS');
my $ETAGS = &tagList('ETAGS');

my $readtagmode = 0;

if (!$readtaglist) {
    $readtaglist = "$FTAGS|$STAGS|$ETAGS";
}
elsif ($readtaglist eq 'default') {
    $readtaglist = '\w{3,4}';
}
else {
    $readtagmode = 1;
}

$logger->info("Read a maximum of $lineLimit lines")      if $lineLimit;
$logger->info("Contig (or alias) name filter $cnFilter") if $cnFilter;
$logger->info("Contigs with fewer than $minOfReads reads are NOT dumped") if ($minOfReads > 1);

$logger->warning("readtags selected $readtaglist") if $readtagmode;

# setup a buffer for read(name)s to be ignored

undef my %rnBlocked;

# objectType = 0 : no object is being scanned currently
#            = 1 : a read    is being parsed currently
#            = 2 : a contig  is being parsed currently

my $objectType = 0;
my $objectName = '';
my $buildReads = 0;
my $buildContigs = 1;

my $dictionaries;

# assume default unpadded caf file

my $isUnpadded = 1 - $usePadded; 
my $isTruncated = 0;

$logger->info("Parsing CAF file $cafFileName");

undef my $record;
my $lineCount = 0;

my $DNASequence = '';
my $BaseQuality = '';
	
my $accumulatedrecord = '';

while (defined($record = <$CAF>)) {

# line counter; signal every 100000-st line

    $lineCount++;
    $logger->info("Processing line $lineCount") unless $lineCount%100000;

# deal with (possible) line limit

    if ($lineLimit && $lineCount > $lineLimit) {
        $logger->warning("Scanning terminated because of line limit $lineLimit");
        $isTruncated = 1;
        $lineCount--;
        last;
    }

# skip empty records

    chomp $record;
    next if ($record !~ /\S/);
#print "$lineCount $record \n";

# extend the record if it ends in a continuation mark

    my $extend;
    while ($record =~ /\\n[\\]?\s*$/) {
        if (defined($extend = <$CAF>)) {
            chomp $extend;
            $record .= $extend;
            $record =~ s/\\n\\\s*\"/\"/; # remove redundent continuation mark
            $lineCount++;
        }
        else {
            $record .= '"' if ($record =~ /\"/); # closing quote
        }
    }
    $record =~ s/\\n[\\]?\s*\"\s*$/\"/; # remove redundent continuation mark

# test for padded/unpadded keyword and its consistence

    if ($record =~ /([un]?)padded/i) {
# test consistence of character
        my $unpadded = $1 || 0;
        if ($isUnpadded <= 1) {
            $isUnpadded = ($unpadded ? 2 : 0); # on first entry
#            $logger->info("is not Padded set to $isUnpadded ");
            if (!$isUnpadded && !$usePadded) {
                $logger->severe("Padded assembly not accepted");
                $isTruncated = 1;
                last;
            }
        }
        elsif (!$isUnpadded && $unpadded || $isUnpadded && !$unpadded) {
            $logger->severe("Inconsistent padding specification at line $lineCount");
            last; # fatal
        }
        next;
    }

# the main dish : recognizing the begin of a new object with definition of a name

    if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:?\s*(\S+)/) {
# a new object is detected
        my $newObjectType = $1;
        my $newObjectName = $2;
# process the existing object, if there is one
        if ($objectType == 2) {
            $logger->fine("END scanning Contig $objectName");
        }
# objectType 1 needs no further action here
        elsif ($objectType == 3) {
# DNA data. Get the object, given the object name
# print "loading DNA sequence for $objectName\n'$DNASequence'\n\n";
            $DNASequence =~ s/\s//g; # clear all blank space
            if ($read = $reads{$objectName}) {
                $read->setSequence($DNASequence);
            }
            elsif ($contig = $contigs{$objectName}) {
                $contig->setSequence($DNASequence);
            }
            elsif ($objectName =~ /Contig/) {
                $contig = new Contig($objectName);
                $contigs{$objectName} = $contig;
                $contig->setSequence($DNASequence);
            }
            else {
                $read = new Read($objectName);
                $reads{$objectName} = $read;
                $read->setSequence($DNASequence);
            }     
        }
        elsif ($objectType == 4) {
# base quality data. Get the object, given the object name
            $BaseQuality =~ s/\s+/ /g; # clear redundent blank space
            $BaseQuality =~ s/^\s|\s$//g; # remove leading/trailing
            my @BaseQuality = split /\s/,$BaseQuality;
            if ($read = $reads{$objectName}) {
                $read->setBaseQuality ([@BaseQuality]);
            }
            elsif ($contig = $contigs{$objectName}) {
                $contig->setBaseQuality ([@BaseQuality]);
            }
            elsif ($objectName =~ /Contig/) {
                $contig = new Contig($objectName);
                $contigs{$objectName} = $contig;
                $contig->setBaseQuality ([@BaseQuality]);
            }
            else {
                $read = new Read($objectName);
                $reads{$objectName} = $read;
                $read->setBaseQuality ([@BaseQuality]);
            }
        }
# prepare for the new object
        $DNASequence = '';
        $BaseQuality = '';
        $objectName = $newObjectName;
# determine object type, first from existing inventories
        $objectType = 0;
# initialisation of contig and read done below (Is_contig, Is_read); there 0 suffices
        $objectType = 3 if ($newObjectType eq 'DNA');
        $objectType = 4 if ($newObjectType eq 'BaseQuality');
# now test if we really want the sequence data
        if ($objectType) {
# for contig, we need consensus option on
            if ($contigs{$objectName} || $objectName =~ /Contig/) {
                $objectType = 0 if !$consensus;
                $objectType = 0 if $cnBlocker->{$objectName};
            }
# for read we reject if it is already known that there are no edits
            elsif ($read = $reads{$objectName}) {
# we consider an existing read only if the number of SCF-alignments is NOT 1
	        my $align = $read->getAlignToTrace();
#                $objectType = 0 if ($isUnpadded && $align && scalar(@$align) == 1);
#	         my $aligntotracemapping = $read->getAlignToTraceMapping();
#                $objectType = 0 if ($isUnpadded && $aligntotracemapping
#                                && ($aligntotracemapping->hasSegments() == 1));
            }
# for DNA and Quality 
            elsif ($rnBlocked{$objectName}) {
                $objectType = 0;
	    }
        }
        next;
    }
       
# the next block handles a special case where 'Is_contig' is defined after 'assembled'

    if ($objectName =~ /Contig/ && $record =~ /assemble/i && abs($objectType) != 2) {
# decide if this contig is to be included
        if (!$cnBlocker->{$objectName} && 
           ($cnFilter !~ /\S/ || $objectName =~ /$cnFilter/)) {
            $logger->fine("NEW contig $objectName: ($lineCount) $record");
            if (!($contig = $contigs{$objectName})) {
# create a new Contig instance and add it to the Contigs inventory
                $contig = new Contig($objectName);
                $contigs{$objectName} = $contig;
            }
            $objectType = 2;
        }
        else {
            $logger->fine("Contig $objectName SKIPPED");
            $objectType = -2;
        }
        next;
    }

# the next block handles the standard contig initiation

    if ($record =~ /Is_contig/ && $objectType == 0) {
# decide if this contig is to be included
        if (!$cnBlocker->{$objectName} && 
           ($cnFilter !~ /\S/ || $objectName =~ /$cnFilter/)) {
            $logger->fine("NEW contig $objectName: ($lineCount) $record");
            if (!($contig = $contigs{$objectName})) {
# create a new Contig instance and add it to the Contigs inventory
                $contig = new Contig($objectName);
                $contigs{$objectName} = $contig;
            }
            $objectType = 2;
        }
        else {
            $logger->fine("Contig $objectName SKIPPED") ;
            $objectType = -2;
        }
    } 
   
# standard read initiation

    elsif ($record =~ /Is_read/) {
# decide if this read is to be included
        if ($rnBlocked{$objectName}) {
# no, don't want it; does the read already exist?
            $read = $reads{$objectName};
            if ($read && $lowMemory) {
                delete $reads{$objectName};
                undef $read;
            } 
            $objectType = 0;
        }
        else {
            $logger->fine("NEW Read $objectName: ($lineCount) $record");
# get/create a Mapping instance for this read
            $mapping = $mappings{$objectName};
            if (!defined($mapping)) {
                $mapping = new Mapping($objectName);
                $mappings{$objectName} = $mapping;
            }
# get/create a Read instance for this read if needed (for TAGS)
            $read = $reads{$objectName};
            if (!defined($read)) {
                $read = new Read($objectName);
                $reads{$objectName} = $read;
            }
# undef the quality boundaries
            $objectType = 1;
        }           
    }

#------------------------------------------------------------------------------------ 

    elsif ($objectType == 1) {
# parsing a read, the Mapping object is defined here; Read may be defined
        $read = $reads{$objectName};
# processing a read, test for Alignments and Quality specification
        if ($record =~ /Align\w+\s+((\d+)\s+(\d+)\s+(\d+)\s+(\d+))\s*$/) {
# AlignToSCF for both padded and unpadded files
            my @positions = split /\s+/,$1;
            if (scalar @positions == 4) {
                my $entry = $read->addAlignToTrace([@positions]);
# temporary fix for consensus read with bad align to trace info 
#                if ($entry == 2 && $objectName =~ /^contig/) {
#                    $logger->warning("align-to-scf specification for "
#                                    ."consensus read $objectName corrected");
#                    undef $read->{alignToTrace};
#		}
                if ($entry == 2 && $isUnpadded) {
                    $logger->info("Edited read $objectName detected ($lineCount)");
# on first encounter load the read item dictionaries
                    $adb->populateLoadingDictionaries() unless $dictionaries;
                    $dictionaries = 1;
                }
            }
            else {
                $logger->severe("Invalid alignment: ($lineCount) $record",2);
                $logger->severe("positions: @positions",2);
            }
        }
        elsif ($record =~ /Clipping\sQUAL\s+(\d+)\s+(\d+)/i) {
# low quality boundaries $1 $2
            $read->setLowQualityLeft($1);
            $read->setLowQualityRight($2);
        }
        elsif ($record =~ /Clipping\sphrap\s+(\d+)\s+(\d+)/i) {
# should be a special testing method on Reads?, or maybe here
#            $read->setLowQualityLeft($1); # was level 1 is not low quality!
#            $read->setLowQualityRight($2);
        }
        elsif ($record =~ /Seq_vec\s+(\w+)\s(\d+)\s+(\d+)\s+\"([\w\.]+)\"/i) {
            $read->addSequencingVector([$4, $2, $3]);
# skip if continuation marks appear
            while ($record =~ /\\n\\\s*$/ || $record =~ /\\n\s*$/) {
                if (defined($record = <$CAF>)) {
                    $lineCount++;
                }
            }
        }   
        elsif ($record =~ /Clone_vec\s+(\w+)\s(\d+)\s+(\d+)\s+\"([\w\.]+)\"/i) {
            $read->addCloningVector([$4, $2, $3]);
        }
# further processing a read Read TAGS and EDITs
        elsif ($record =~ /Tag\s+($readtaglist)\s+(\d+)\s+(\d+)(.*)$/i) {
# elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
            my $type = $1; my $trps = $2; my $trpf = $3; my $info = $4;
# test for a continuation mark (\n\); if so, read until no continuation mark
	    $accumulatedrecord = '';
            while ($record =~ /\\n\\\s*$/ || $record =~ /\\n\s*$/) {
                $accumulatedrecord .= $record;
print STDERR "Extending Tag record ($lineCount)  .. SHOULD NOT OCCUR!!\n";
                if (defined($record = <$CAF>)) {
                    chomp $record;
                    $info .= $record;
                    $lineCount++;
                }
                else {
                    $info .= '"'; # closing quote
                }
            }
# cleanup $info
            $info =~ s/\s+\"([^\"]+)\".*$/$1/; # remove wrapping quotes
            $info =~ s/^\s+//; # remove leading blanks
            my ($change,$inew) = &cleanup_comment($info);
            $info = $inew if $change;
            $logger->info("new info after cleanup: $info") if $change;

#$logger->warning("READ tag: $type $trps $trpf $info") if $noload;

            my $tag = new Tag('read');
            $tag->setType($type);
            $tag->setPosition($trps,$trpf);
            $tag->setStrand('Forward');

            my $readname = $read->getReadName();
            if (($type eq 'OLIG' || $type eq 'AFOL') && $info && $info =~ /\S/) {
# test info for sequence specification
                my ($DNA,$inew) = &get_oligo_DNA($info);
                if ($DNA) {
                    $tag->setDNA($DNA);
                    my $length = length($DNA);
# test the length against the position specification
                    if ($trps == $trpf) {
                        $logger->warning("oligo length error ($trps $trpf) ".
                                         "for $info near line $lineCount \n".
                                         "tag *ignored* for read $readname");
 			next;
                    }
                    elsif ($trpf-$trps+1 != $length) {
                        $logger->info("oligo length mismatch ($trps $trpf $length) ".
                                      "for $info near line $lineCount");
                    }
# test if the DNA occurs twice in the data
                    if ($inew) {
			$logger->info("Multiple DNA info removed from ".
                                      "$type tag for read $readname");
                        $info = $inew;
                        $logger->info("new info after DNA removal: $info");
                    }
                }
# process oligo names
                if ($type eq 'OLIG') {
# clean up name (replace possible ' oligo ' string by 'o')
                    $info =~ s/\boligo[\b\s*]/o/i;
# replace blank space by \n\ if at least one \n\ already occurs
                    $info =~ s/\s+/\\n\\/g if ($info =~ /\\n\\/);
# get the oligo name from the $info data
                    my $sequence = $tag->getDNA();
                    my ($name,$inew) = &decode_oligo_info($info,$sequence);
                    if ($name) {
                        $tag->setTagSequenceName($name);
                        if ($inew) {
                            $info = $inew;
                            $logger->info("decode new oligo info again\n$info");
                           ($name,$inew) = &decode_oligo_info($info,$sequence);
                            $info = $inew if $inew;
                            $logger->info("cleaned oligo info:\n$info") if $inew;
			}
                    }
                    else {
                        $logger->warning("Failed to decode OLIGO info:\n$info");
                    }
		}
                elsif ($type eq 'AFOL' && $info =~ /oligoname\s*(\w+)/i) {
                    $tag->setTagSequenceName($1);
                }


                unless ($tag->getTagSequenceName()) {
		    $logger->warning("Missing oligo name in read tag for "
                           . $read->getReadName()." (line $lineCount)");
                    next; # don't load this tag
	        }
            }
# special action for repeat tags
            elsif ($type eq 'REPT') {
		if ($info =~ /^\s*(\S+)\s/i) {
                    $tag->setTagSequenceName($1);
		}
                else {
		    $logger->info("Missing repeat name in read tag for ".
                        $read->getReadName());
                }
            }
# all others, general comment cleanup: double newline, quotation etc.
            else {
                if ($type eq 'ADDI' && $trps != 1) {
                    $logger->info("Invalid ADDI tag ignored for ".
                        $read->getReadName());
                    next; # don't accept this tag
		}
	    }

            $tag->setTagComment($info);
            $read->addTag($tag);

        }
        elsif ($record =~ /Tag/ && $record =~ /$ETAGS/) {
           $logger->info("READ EDIT tag detected but not processed: $record") unless $readtagmode;
        }
        elsif ($record =~ /Tag/) {
           $logger->warning("READ tag not recognized: $record") unless $readtagmode;
        }
# EDIT tags TO BE TESTED (NOT OPERATIONAL AT THE MOMENT)
	elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*replaced\s+(\w+)\s+by\s+(\w+)\s+at\s+(\d+)/) {
            $logger->warning("error in: $record |$1|$2|$3|$4|$5|") if ($1 != $2);
            my $tag = new Tag('read');
	    $tag->editReplace($5,$3.$4);
            $read->addTag($tag);
        }
        elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*deleted\s+(\w+)\s+at\s+(\d+)/) {
            $logger->warning("error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
            my $tag = new Tag('read');
	    $tag->editDelete($4,$3); # delete signalled by uc ATCG
            $read->addTag($tag);
        }
        elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*inserted\s+(\w+)\s+at\s+(\d+)/) {
            $logger->warning("error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
            my $tag = new Tag('read');
	    $tag->editDelete($4,$3); # insert signalled by lc atcg
            $read->addTag($tag);
        }
        elsif ($record =~ /Note\sINFO\s(.*)$/) {

	    my $trpf = $read->getSequenceLength();
#            my $tag = new Tag('read');
#            $tag->setType($type);
#            $tag->setPosition($trps,$trpf);
#            $tag->setStrand('Forward');
#            $tag->setTagComment($info);
	    my $r = $record;
#	    $logger->warning("NOTE detected: $r but not processed") if $noload;
	    $logger->info("NOTE detected: $r but not processed") unless $noload;
        }
# finally
        elsif ($record !~ /SCF|Sta|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
            $logger->warning("not recognized ($lineCount): $record") unless $readtagmode;
            $logger->warning("accumulated record:\n$accumulatedrecord");
	    $accumulatedrecord = '';
        }
    }

    elsif ($objectType == 2) {
# parsing a contig, get constituent reads and mapping
        if ($record =~ /Ass\w+from\s+(\S+)\s+(.*)$/) {
# an Assembled from alignment, identify the Mapping for this readname ($1)
            $mapping = $mappings{$1};
            if (!defined($mapping)) {
                $mapping = new Mapping($1);
                $mappings{$1} = $mapping;
            }
# identify the Read for this readname ($1), else create
            $read = $reads{$1};
            if (!defined($read)) {
                $read = new Read($1);
                $reads{$1} = $read;
            }
# add the alignment to the Mapping 
            my @positions = split /\s+/,$2;
            if (scalar @positions == 4) {
#$positions[0] = 50000 - $positions[0];
#$positions[1] = 21000 + $positions[1];
                my $entry = $mapping->addAssembledFrom(@positions); 
# $entry returns number of alignments: add Mapping and Read for first
                if ($entry == 1) {
                    unless ($rnBlocker && $read->getReadName =~ /$rnBlocker/) {
                        $contig->addMapping($mapping);
                        $contig->addRead($read);
                    }
                }
# test number of alignments: padded allows only one record per read, unpadded multiple records
                if (!$isUnpadded && $entry > 1) {
                    $logger->severe("Multiple assembled_from in padded assembly ($lineCount) $record");
                    undef $contigs{$objectName};
                    last;
                }
            }
            else {
                $logger->severe("Invalid alignment: ($lineCount) $record");
                $logger->severe("positions: @positions",2);
            }
        }
        elsif ($record =~ /Tag\s+($readtaglist)\s+(\d+)\s+(\d+)(.*)$/i) {
#        elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
# detected a contig TAG
            my $type = $1; my $tcps = $2; my $tcpf = $3; 
            my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
# test for a continuation mark (\n\); if so, read until no continuation mark
                while ($info =~ /\\n\\\s*$/ || $info =~ /\\n\s*$/) {
                    if (defined($record = <$CAF>)) {
                        chomp $record;
                        $info .= $record;
                        $lineCount++;
                    }
                    else {
                        $info .= '"'; # closing quote
                    }
                }
                $logger->info("CONTIG tag detected: $record\n"
                            . "'$type' '$tcps' '$tcpf' '$info'") if $contigtagdebug;
#$logger->info("CONTIG tag: $record\n'$type' '$tcps' '$tcpf' '$info'") if $noload;
            my $tag = new Tag('contig');
            $contig->addTag($tag);
            $tag->setType($type);
            $tag->setPosition($tcps,$tcpf);
            $tag->setStrand('Unknown');
            $tag->setTagComment($info);
            if ($info =~ /([ACGT]{5,})/) {
                $tag->setDNA($1);
            }
# preprocess COMM and REPT tags
            if ($type eq 'REPT' || $type eq 'COMM') {
# remove possible offset info (lost on inheritance)
                $info =~ s/\,\s*offset\s+\d+//i if ($info =~ /Repeats\s+with/);
	    }
# special for repeats: pickup repeat name
            if ($type eq 'REPT') {
# try to find the name of the repeat
		if ($info =~ /^\s*(\S+)\s+from/i) {
                    $logger->info("TagSequenceName $1") if $noload;
                    $tag->setTagSequenceName($1);
		}
# no name found, try alternative
                elsif ($info !~ /Repeats\s+with/) {
# try to generate one based on possible read mentioned
                    if ($info =~ /\bcontig\s+(\w+\.\w+)/) {
                        $logger->info("TagSequenceName read $1") if $noload;
                        $tag->setTagSequenceName($1);   
	            }
# nothing useful found                
                    else {
		       $logger->warning("Missing repeat name in contig tag for ".
                              $contig->getContigName().": ($lineCount) $record") if $contigtagdebug;
		    }
                }
            }
        }
        elsif ($record =~ /Tag/) {
            $logger->warning("CONTIG tag not recognized: ($lineCount) $record") unless ($readtagmode && $contigtagdebug);
        }
        else {
            $logger->warning("ignored: ($lineCount) $record");
        }
    }

    elsif ($objectType == -2) {
# processing a contig which has to be ignored: inhibit its reads to save memory
        if ($record =~ /Ass\w+from\s(\S+)\s(.*)$/) {
            $rnBlocked{$1}++; # add read in this contig to the read blocker list
            $logger->fine("read $1 blocked") unless (keys %rnBlocked)%100;
# remove existing Read instance
            $read = $reads{$1};
            if ($read && $lowMemory) {
                delete $reads{$1};
                undef $read;
            }
        }
    }

    elsif ($objectType == 3) {
# accumulate DNA data
        $DNASequence .= $record;
    }

    elsif ($objectType == 4) {
# accumulate BaseQuality data
        $BaseQuality .= ' '.$record;
    }

    elsif ($objectType > 0) {
	$logger->info("ignored: ($lineCount) $record (t=$objectType)") if ($record !~ /sequence/i);
    }
# go to next record
}

$CAF->close();

# here the file is parsed and Contig, Read, Mapping and Tag objects are built
    
$logger->info("$lineCount lines processed of CAF file $cafFileName");
$logger->warning("Scanning of CAF file $cafFileName was truncated") if $isTruncated;

my $nc = scalar (keys %contigs);
my $nm = scalar (keys %mappings);
my $nr = scalar (keys %reads);

$logger->info("$nc Contigs, $nm Mappings, $nr Reads built");

# now test the contigs and enter them and their maps into the database

# testing the reads (should go in adb as part of putContig)

$origin = 'Arcturus CAF parser' unless $origin;
$origin = 'Other' unless ($origin eq 'Arcturus CAF parser' ||
                          $origin eq 'Finishing Software');
 
my $loaded = 0;
my $lastinsertedcontig = 0;
foreach my $identifier (keys %contigs) {

    my $contig = $contigs{$identifier};

    if ($noload && $notest) {
	last unless $list;
        $contig->writeToCaf(*STDOUT);
        next;
    }

# minimum number of reads test

    if ($contig->getNumberOfReads() < $minOfReads) {
        $logger->warning("$identifier has less than $minOfReads reads");
        next;
    }

# weedout duplicate tags

    $contig->getTags(0,sort=>'full',merge=>1);

    $contig->setOrigin($origin);

    $contig->toUnPadded(nonew=>1) unless $isUnpadded;
#   $contig->writeToCaf(*STDOUT) if $list;

# test consensus reads (to be separate subroutine)

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
        next unless ($readrepair);
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

# load

    my ($added,$msg) = $adb->putContig($contig, $project,
                                       noload  => $noload,
                                       setprojectby => $pinherit,
                                       dotags  => $contigtag);

    $logger->info("Contig $identifier with ".$contig->getNumberOfReads.
                  " reads : status $added, $msg") if $added;
    $logger->warning("Contig $identifier with ".$contig->getNumberOfReads.
                     " reads not added:\n$msg\nContig id =".
                     ($contig->getContigID || 0)) unless $added;

    if ($added) {
# what about tags? better in ADBContig
        delete $contigs{$identifier};
        $lastinsertedcontig = $added;
        undef $contig;
        $loaded++;
    }
    else {
#        $adb->clearLastContig();
    }
    
}

# test again

$nc = scalar (keys %contigs);
$logger->info("$nc contigs skipped") if $nc;
$logger->info("$loaded contigs loaded");

# add import mark if contigs were loaded ? perhaps after safemode ?

if ($loaded && $project) {
    unless ($gap4name) {
        $gap4name = `pawd`;
        chomp $gap4name if $gap4name;
    }
    $project->setGap4Name($gap4name);
    $project->markImport(); 
}

# add the Read tags

if ($loadreadtags) {

    my @reads;
    foreach my $identifier (keys %reads) {
        my $read = $reads{$identifier};
        next unless $read->hasTags();
        push @reads, $read;
    }

    my $success = $adb->putTagsForReads(\@reads,autoload=>1);
    $logger->info("putTagsForReads success = $success");
}
elsif ($noload) {
    $logger->warning("Read Tags Listing\n");
    foreach my $identifier (keys %reads) {
        my $read = $reads{$identifier};
        my $tags = $read->getTags();
        next unless ($tags && @$tags);
        $logger->warning("read ".$read->getReadName." : tags ".scalar(@$tags));
        foreach my $tag (@$tags) {
            $logger->info($tag->writeToCaf()) if $list;
        }
        my $tagstobeloaded;
        unless ($notest) {
            $tagstobeloaded = $adb->putTagsForReads([($read)],noload=>1);
	}
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

# add hoc edited reads processing (debugging)

    foreach my $identifier (keys %reads) {
        my $read = $reads{$identifier};
        my $tags = $read->getTags();
        foreach my $tag (@$tags) {
#            $logger->info($tag->writeToCaf());
        }
        next unless $read->isEdited();
#        $read->writeToCaf(*STDOUT);
   }

# read-back lastly inserted contig (meta data) to check on OS cache dump

if ($lastinsertedcontig && $safemode) {
# pause to be sure the OS cache of the server has emptied 
# and the data have to be read back from disk.
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
        $adb->disconnect();
	exit 1; # exit with error status and leave project locked
    }
}

# finally update the meta data for the Assembly and the Organism

# $adb->updateMetaData;

unless ($lockedonentry && $autolockmode) {
# the project was not locked before; return project to this state
    $project->releaseLock() || $logger->severe("could not release lock");
}

$adb->disconnect();

exit 0;  # no errors

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------

sub tagList {
# e.g. list = tagList('FTAGS')
    my $name = shift;

# Finishers tags

    my @FTAGS = ('FINL','FINR','ANNO','FICM','RCMP','POLY','STSP',
                 'STSF','STSX','STSG','COMM','RP20','TELO','REPC',
                 'WARN','DRPT','LEFT','RGHT','TLCM','ALUS','VARI',
                 'CpGI','NNNN','SIL' ,'IRPT','LINE','REPA','REPY',
                 'REPZ','FICM','VARD','VARS','CSED','CONS','EXON',
                 'SILR','DIFF','FWGS','FCDS');

# software TAGS

    my @STAGS = ('ADDI','AFOL','AMBG','CVEC','SVEC','FEAT','REPT',
                 'MALX','MALI','XMAT','OLIG','COMP','STOP','PCOP',
                 'LOW' ,'MOSC','STOL','TEST','CLIP','IGNS','IGNC',
                 'ASIT');

# edit tags

    my @ETAGS = ('EDIT','DONE','MISS','MASK','UNCL','CONF','CLIP');

    my $list  = eval "join '|',\@$name";
}

sub decode_oligo_info {
    my $info = shift || '';
    my $sequence = shift || '';

my $DEBUG = 0;
print STDOUT "\ndecode_oligo_info  $info ($sequence) \n" if $DEBUG;

    my $change = 0;
# clean up name (replace possible ' oligo ' string by 'o')
    $change = 1 if ($info =~ s/^\<\w+\>//i); # delete a possible place holder
    $change = 1 if ($info =~ s/\boligo[\b\s*]/o/i);
    $change = 1 if ($info =~ s/\s+/\\n\\/g);
    $change = 1 if ($info =~ s/(\\n\\){2,}/\\n\\/g); # multiple \n\ by one
# clean up stretches of text between \n\
    $change++ if ($info =~ s/ig\\n\\pk/ig-pk/);
    if ($info =~ /(pcr.+)\\n\\seq/) {
        my $clutter = $1;
        my $cleanup = $clutter;
        $cleanup =~ s/\\n\\/-/g;
	$cleanup = qw($cleanup);
	$clutter = qw($cleanup);
        $change = 1 if ($info =~ s/$clutter/$cleanup/);

    }

# split $info on blanks and \n\ separation symbols

#    my @info = split /\s+|\\n[\\]?/,$info;
    my @info = split /\s+|\\n\\/,$info;

# cleanup empty flags= specifications

    foreach my $part (@info) {
        if ($part =~ /flags\=(.*)/) {
            my $flag = $1;
            unless ($flag =~ /\S/) {
 #               $info =~ s/\\n[\\]?flags\=\s*//;
                $info =~ s/\\n\\flags\=\s*//;
                $change = 1;
            }
        }
    }

    my $name;
    my $qwsequence = qw($sequence);
    if (defined($sequence) && $info =~ /^\s*(\d+)\b(.*?)$qwsequence/) {
# the info string starts with a number followed by the sequence
        $name = "o$1";
        $change++ if ($info =~ s/^\s*(\d+)\b/$name/);
    }
    elsif ($info !~ /serial/ && $info =~ /\b([opt]\d+)\b/) {
# the info contains a name like o1234 or t1234
        $name = $1;
    }
    elsif ($info !~ /serial/ && $info =~ /[^\w\.]0(\d+)\b/) {
        $name = "o$1"; # correct typo 0 for o
    }
    elsif ($info =~ /\b(o\w+)\b/ && $info !~ /\bover\b/i && $info !~ /\bof\b/i) {
# the info contains a name like oxxxxx
        $name = $1;
    }
# try its a name like 17H10.1
    elsif ($info && $info =~ /^(\w+\.\w{1,2})\b/) {
        $name = $1;
    }
# try with the results of the split
    elsif ($info[0] && $info[0] !~ /\=/ && $info =~ /^([a-zA-Z]\w+)\b/i) {
# the info string starts with a name like axx..
        $name = $1;
    }
    elsif (defined($sequence) && defined($info[1]) && $info[1] eq $sequence) {
        $name = $info[0];
        $name = "o$name" unless ($name =~ /\D/);
    }

print STDOUT "name ".($name || '')." (change $change) \n" if $DEBUG;
print STDOUT "DECODED\n\n" if ($DEBUG && $name && !$change);

    return ($name,0) if ($name && !$change); # no new info
    return ($name,$info) if $name; # info modified


# name could not easily be decoded: try one or two special possibilities


    foreach my $part (@info) {
        if ($part =~ /serial\#?\=?(.*)/) {
            my $number = $1;
print STDOUT "number $number \n" if $DEBUG;
            if (defined($number) && $number =~ /\w/) {
# generate a name based on the information following '=' (mostly a number)
                $name = "o$number"; 
# replace the serial field by the name
                $info =~ s/$part/$name/;
            }
            else {
# remove the part from the info (it contains no information)
                $info =~ s/$part//;
	    }
print "info: $info, name ".($name || '')."\n" if $DEBUG;
	    $change++;
	}
    }

print STDOUT "name ".($name || '')." (change $change) \n" if $DEBUG;

    return ($name,$info) if $name;

# or see if possibly the name and sequence fields have been interchanged

    if (defined($info[1]) && $info[1] =~ /^\w+\.\w{1,2}\b/) {
# name and sequence possibly interchanged
print STDOUT "still undecoded info: $info  (@info)\n" if $DEBUG;
        $name = $info[1];
        $info[1] = $info[0];
        $info[0] = $name;
#        $info = join ('\\n',@info);
        $info = join ('\\n\\',@info);
print STDOUT "now decoded info: $info ($name)\n" if $DEBUG;
        return $name,$info;
    }

# still no joy, try info field that looks like a name (without = sign etc.)

    foreach my $part (@info) {
        next if ($part =~ /\=/);
# consider it a name if the field starts with a character
        if ($part =~ /\b([a-zA-Z]\w+)\b/) {
            my $save = $1;
# avoid repeating information
            $name  = $save if ($name && $save =~ /$name/);
            $name .= $save unless ($name && $name =~ /$save/);
        }
    }

#    $info =~ s/\\n[\\]+\s*$name\s*$// if $name; # chop off name at end, if any
    $info =~ s/\\n\\\s*$name\s*$// if $name; # chop off name at end, if any

# if the name is still blank substitute a placeholder
            
    $name = '<oligo>' unless $name; # place holder name

# put the name upfront in the info string

    $info = "$name\\n\\".$info;
    $info =~ s/\\n\\[\s*|o]\\n\\/\\n\\/g; # cleanup

    return ($name,$info);
}

sub get_oligo_DNA {
    my $info = shift;

    if ($info =~ /([ACGT\*]{5,})/i) {
        my $DNA = $1;
        my $dna = qw($DNA);
# test if the DNA occurs twice in the data
        if ($info =~ /$dna[^ACGT].*(sequence\=)?$dna/i) {
# multiple occurrences of DNA to be removed ...
            $info =~ s/($dna[^ACGT].*?)(sequence\=)?$dna/$1/i;
            return $DNA,$info;
        }
	return $DNA,0; # no change
    }
    return 0,0; # no DNA
}

sub cleanup_comment {
    my $comment = shift;

    my $changes = 0;

    $changes = 1 if ($comment =~ s/^\s+|\s+$//g); # clip leading/trailing blanks

    $changes = 1 if ($comment =~ s/\s+(\\n\\)/$1/g); # delete blanks before \n\

    $changes = 1 if ($comment =~ s/(\\n\\)\-(\\n\\)/-/g); # - between \n\

    $changes = 1 if ($comment =~ s/(\\n\\){2,}/\\n\\/g); # delete repeats

    $changes = 1 if ($comment =~ s/\\n\\\s*$//); # delete trailing newline

    $changes = 1 if ($comment =~ s?\\/?/?g);

    return $changes,$comment;
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

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
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-caf\t\tcaf file name OR\n";
    print STDERR "-cafdefault\tuse the default caf file name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for project inheritance:\n";
    print STDERR "\n";
    print STDERR "-setprojectby\treadcount,contigcount,contiglength or none\n";
    print STDERR "-project \tproject  ID or name (overrides setprojectby)\n";
    print STDERR "-assembly\tassembly ID or name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for tag processing:\n";
    print STDERR "\n";
    print STDERR "-ctp\t\tcontigtagprocessing (depth of inheritance, def 1)\n";
    print STDERR "-noreadtags\tdo not process read tags\n";
    print STDERR "-rtl\t\t(readtaglist) process specified read tags only\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-minimum\tnumber of reads per contig (default 1 i.e. all contigs)\n";
    print STDERR "-filter\t\tcontig name substring or regular expression\n";
    print STDERR "-out\t\toutput file, default STDOUT\n";
    print STDERR "-test\t\tnumber of lines parsed of the CAF file\n";
    print STDERR "-noload\t\tskip loading into database (test mode)\n";
    print STDERR "-notest\t\t(in combination with noload: "
                 . "skip contig processing altogether\n";
    print STDERR "-irnl\t\tignorereadnamelike (name filter) pattern\n";
#    print STDERR "-ignore\t\t(no value) contigs already processed\n";
#    print STDERR "-frugal\t\t(no value) minimise memory usage\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "-contigtagdebug\tShow debugging info for contig tags\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
