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

my $lineLimit;             # specifying a line limit implies test mode 
my $cnFilter = '';         # test contig names for this substring or RE
my $cnBlocker;             # contig name blocker, ignore contig names of age 0
my $minOfReads = 2;        # default require at least 2 reads per contig
my $readTags;              # default ignore read contents and tags, only mapping
my $origin;

my $assembly;              # ?? not really necessary
my $projectname;           # projectname for which the data are to be loaded
my $projectID;             # alternatively the project ID

my $lowMemory;             # specify to minimise memory usage
my $usePadded = 0;         # 1 to allow a padded assembly
my $consensus;             # load consensus sequence
my $noload = 1; # CHANGE to 0
my $list = 0;
my $batch = 0;

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|cafdefault|out|consensus|" .
                 "projectname|project_id|test|minimum|filter|ignore|list|" .
                 "frugal|padded|readtags|noload|verbose|batch|info|help";


while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $projectname      = shift @ARGV  if ($nextword eq '-projectname');

    $projectID        = shift @ARGV  if ($nextword eq '-project_id');

    $lineLimit        = shift @ARGV  if ($nextword eq '-test');

    $consensus        = 1            if ($nextword eq '-consensus');

    $logLevel         = 0            if ($nextword eq '-verbose'); 

    $logLevel         = 2            if ($nextword eq '-info'); 

    $minOfReads       = shift @ARGV  if ($nextword eq '-minimum');

    $cnFilter         = shift @ARGV  if ($nextword eq '-filter'); 

    $readTags         = 1            if ($nextword eq '-readtags');

    $usePadded        = 1            if ($nextword eq '-padded');

    $origin           = shift @ARGV  if ($nextword eq '-origin');

    $lowMemory        = 1            if ($nextword eq '-frugal');

    $cafFileName      = shift @ARGV  if ($nextword eq '-caf');

    $cafFileName      = 'default'    if ($nextword eq '-cafdefault');

    $cnBlocker        = 1            if ($nextword eq '-ignore');

    $outputFile       = shift @ARGV  if ($nextword eq '-out');

    $noload           = 1            if ($nextword eq '-noload');

    $list             = 1            if ($nextword eq '-list');

    $batch            = 1            if ($nextword eq '-batch');

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging($outputFile);

$logger->setFilter($logLevel) if defined $logLevel; # set reporting level

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

&showUsage("Unknown organism '$organism'") unless $adb;

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

my $project;

if ($projectname || $projectID) {
# to be completed: get info for a name from the assembly
    $project = $adb->getProject(projectname=>$projectname) if $projectname;
    $project = $adb->getProject(project_id=>$projectID) if (!$project && $projectID);
# return an Assembly object from the database, which must have a default
# project name
# what if an assembly is defined? and no project, get the default project
# TO BE TESTED
    
    &showUsage("Unknown project ".($projectname || $projectID) ) unless $project;
    $logger->info("Project ".$project->getProjectName." identified") if $project;
}
#exit;

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


    my $FTAGS = &tagList('FTAGS');
    my $STAGS = &tagList('STAGS');
    my $ETAGS = &tagList('ETAGS');

$logger->info("Read a maximum of $lineLimit lines")      if $lineLimit;
$logger->info("Contig (or alias) name filter $cnFilter") if $cnFilter;
$logger->info("Contigs with fewer than $minOfReads reads are NOT dumped") if ($minOfReads > 1);

# setup a buffer for read(name)s to be ignored

undef my %rnBlocker;

# objectType = 0 : no object is being scanned currently
#            = 1 : a read    is being parsed currently
#            = 2 : a contig  is being parsed currently

my $objectType = 0;
my $objectName = '';
my $buildReads = 0;
my $buildContigs = 1;

# assume default unpadded caf file

my $isUnpadded = 1 - $usePadded; 
my $isTruncated = 0;

$logger->info("Parsing CAF file $cafFileName");

undef my $record;
my $lineCount = 0;

my $DNASequence = '';
my $BaseQuality = '';

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

# test for padded/unpadded keyword and its consistence

    if ($record =~ /([un]?)padded/i) {
# test consistence of character
        my $unpadded = $1 || 0;
        if ($isUnpadded <= 1) {
            $isUnpadded = ($unpadded ? 2 : 0); # on first entry
            $logger->info("is not Padded set to $isUnpadded ");
            if (!$isUnpadded && !$usePadded) {
                $logger->severe("Padded assembly not accepted");
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
            elsif ($objectName =~ /contig/i) {
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
            elsif ($objectName =~ /contig/i) {
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
            if ($contigs{$objectName} || $objectName =~ /contig/i) {
                $objectType = 0 if !$consensus;
                $objectType = 0 if $cnBlocker->{$objectName};
            }
# for read we reject if it is already known that there are no edits
            elsif ($read = $reads{$objectName}) {
# we consider an existing read only if the number of SCF-alignments is NOT 1
	        my $align = $read->getAlignToTrace();
                $objectType = 0 if ($isUnpadded && $align && scalar(@$align) == 1);
#	         my $aligntotracemapping = $read->getAlignToTraceMapping();
#                $objectType = 0 if ($isUnpadded && $aligntotracemapping
#                                && ($aligntotracemapping->hasSegments() == 1));
            }
# for DNA and Quality 
            elsif ($rnBlocker{$objectName}) {
                $objectType = 0;
	    }
        }
        next;
    }
       
# the next block handles a special case where 'Is_contig' is defined after 'assembled'

    if ($objectName =~ /contig/i && $record =~ /assemble/i && abs($objectType) != 2) {
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
        if ($rnBlocker{$objectName}) {
# no, don't want it; does the read already exist?
            $read = $reads{$objectName};
            if ($read && $lowMemory) {
                $read->DESTROY;
                delete $reads{$objectName};
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
                if ($isUnpadded && $entry == 2) {
                    $logger->info("Edited read $objectName detected ($lineCount)");
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
        }   
        elsif ($record =~ /Clone_vec\s+(\w+)\s(\d+)\s+(\d+)\s+\"([\w\.]+)\"/i) {
            $read->addCloningVector([$4, $2, $3]);
        }
# further processing a read Read TAGS and EDITs
        elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
            my $type = $1; my $trps = $2; my $trpf = $3; my $info = $4;
#print STDERR "read Tag ($record) \n";
# test for a continuation mark (\n\); if so, read until final mark
            while ($info =~ /\\n\\\s*$/) {
                if (defined($record = <$CAF>)) {
                    chomp $record;
                    $info .= $record;
                    $lineCount++;
                }
                else {
                    $info .= '"'; # closing quote
                }
            }

# print STDERR "TAG info: $info \n" if ($info =~ /\\n\\/); exit if ($type eq 'OLIG');
 
            $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;

	    $logger->finest("READ tag: $type $trps $trpf $info") if $noload;

            my $tag = new Tag('readtag');
            $tag->setType($type);
            $tag->setPosition($trps,$trpf);
            $tag->setStrand('Forward');
            $tag->setComment($info);

            if ($type eq 'OLIG' || $type eq 'AFOL') {
# test info for sequence specification
                if ($info =~ /([ACGT]{5,})/) {
                    $logger->info("Read Tag $type DNA '$1'");
                    $tag->setDNA($1);
                }
# pick up the oligo name
                if ($type eq 'OLIG' && $info =~ /\b([opt]?\d+)\s*$/) {
                    my $name = $1;
                    $name =~ s/^0/o/; # correct typo 0 for o
#print "OLIG detected: $info -> $name\n";
                    $tag->setTagSequenceName($name);
                }
                if ($type eq 'AFOL' && $info =~ /oligoname\s*(\w+)/i) {
                    $tag->setTagSequenceName($1);
                }
		$logger->info("Missing oligo name in read tag for ".
                        $read->getReadName()) unless $tag->getTagSequenceName();
            }
            elsif ($type eq 'REPT') {
# pickup the repeat name
		if ($info =~ /^\s*([\w\-]+)\s/i) {
                    $tag->setTagSequenceName($1);
		}
                else {
		    $logger->info("Missing repeat name in read tag for ".
                            $read->getReadName());
                }
            }
            $read->addTag($tag);
        }
        elsif ($record =~ /Tag/ && $record =~ /$ETAGS/) {
           $logger->info("READ EDIT tag detected but not processed: $record");
        }
        elsif ($record =~ /Tag/) {
           $logger->warning("READ tag not recognized: $record");
        }
# EDIT tags TO BE TESTED
	elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*replaced\s+(\w+)\s+by\s+(\w+)\s+at\s+(\d+)/) {
            $logger->warning("error in: $record |$1|$2|$3|$4|$5|") if ($1 != $2);
            my $tag = new Tag(type=>'edit');
	    $tag->editReplace($5,$3.$4);
            $read->addTag($tag);
        }
        elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*deleted\s+(\w+)\s+at\s+(\d+)/) {
            $logger->warning("error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
            my $tag = new Tag(type=>'edit');
	    $tag->editDelete($4,$3); # delete signalled by uc ATCG
            $read->addTag($tag);
        }
        elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*inserted\s+(\w+)\s+at\s+(\d+)/) {
            $logger->warning("error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
            my $tag = new Tag(type=>'edit');
	    $tag->editDelete($4,$3); # insert signalled by lc atcg
            $read->addTag($tag);
        }
        elsif ($record =~ /Note\sINFO\s(.*)$/) {
	    $logger->warning("NOTE detected $1 but not processed");
        }
# finally
        elsif ($record !~ /SCF|Sta|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
            $logger->warning("not recognized ($lineCount): $record");
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
$positions[0] = invert($positions[0]);
$positions[1] = invert($positions[1]);
                my $entry = $mapping->addAssembledFrom(@positions); 
# $entry returns number of alignments: add Mapping and Read for first
                if ($entry == 1) {
                    $contig->addMapping($mapping);
                    $contig->addRead($read);
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
        elsif ($record =~ /Tag\s+($FTAGS|$STAGS)\s+(\d+)\s+(\d+)(.*)$/i) {
# detected a contig TAG
            my $type = $1; my $tcps = $2; my $tcpf = $3; 
            my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
$logger->warning("CONTIG tag: $record\n'$type' '$tcps' '$tcpf' '$info'") if $noload;
            my $tag = new Tag('contigtag');
            $contig->addTag($tag);
            $tag->setType($type);
            $tag->setPosition($tcps,$tcpf);
            $tag->setStrand('Forward');
            $tag->setComment($info);
            if ($info =~ /([ACGT]{5,})/) {
                $tag->setDNA($1);
            }
# pickup repeat name
            if ($type eq 'REPT') {
		if ($info =~ /^\s*(r[\w\-]+)\s/i) {
$logger->warning("TagSequenceName $1") if $noload;
                    $tag->setTagSequenceName($1);
		}
                else {
		    $logger->info("Missing repeat name in contig tag for ".
                            $contig->getContigName());
                }
            }
        }
        elsif ($record =~ /Tag/) {
            $logger->warning("CONTIG tag not recognized: ($lineCount) $record");
        }
        else {
            $logger->warning("ignored: ($lineCount) $record");
        }
    }

    elsif ($objectType == -2) {
# processing a contig which has to be ignored: inhibit its reads to save memory
        if ($record =~ /Ass\w+from\s(\S+)\s(.*)$/) {
            $rnBlocker{$1}++; # add read in this contig to the read blocker list
            $logger->fine("read $1 blocked") unless (keys %rnBlocker)%100;
# remove existing Read instance
            $read = $reads{$1};
            if ($read && $lowMemory) {
                delete $reads{$1};
                $read->DESTROY;
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
 
my $number = 0;
foreach my $identifier (keys %contigs) {
# minimum number of reads test
    my $contig = $contigs{$identifier};
    if ($contig->getNumberOfReads() < $minOfReads) {
        $logger->warning("$identifier has less than $minOfReads reads");
        next;
    }         
    $contig->setOrigin($origin);

    unless ($isUnpadded) {
# convert padded reads and mappings into unpadded representation
        my $reads = $contig->getReads();
        my $mappings = $contig->getMappings();
        if ($reads && @$reads && $mappings && @$mappings) {
            my $namelookup = {};
            for (my $i = 0 ; $i < scalar(@$mappings) ; $i++) {
                $namelookup->{$mappings->[$i]->getMappingName()} = $i;
	    }

            foreach my $paddedread (@$reads) {
                my $mappingnumber = $namelookup->{$paddedread->getReadName};
		my $paddedmapping = $mappings->[$mappingnumber];
                unless ($paddedmapping) {
                    print STDERR "missing mapping for read ".
                        $paddedread->getReadName."\n";
                    next;
                }
# convert the padded read / mapping to unpadded representations
                my $intermediate = new PaddedRead($paddedread);
                $intermediate->setPadded();
                $mappings->[$mappingnumber] = $intermediate->dePad($paddedmapping);
                $paddedread = $intermediate->exportAsRead();
	    }
	}
	else {
            print STDERR "Cannot convert to unpadded contig ".
		$contig->getContigName()."\n";
            next;
	}
	$contig->writeToCaf(*STDOUT) if $list;
exit; # test
    }

    my ($added,$msg) = $adb->putContig($contig,$project,$noload); # return 0 fail

    $logger->info("Contig $identifier with ".$contig->getNumberOfReads.
                  " reads : status $added, $msg");

      # $adb->clearLastContig() unless $added;
    delete $contigs{$identifier} if $added;
}

# test again

$nc = scalar (keys %contigs);
$logger->info("$nc contigs skipped") if $nc;

# add the Read tags

if ($readTags) {

    my @reads;
    foreach my $identifier (keys %reads) {
        my $read = $reads{$identifier};
        push @reads, $read;
#        if ($noload) {
        my $tags = $read->getTags();
        next unless ($tags && @$tags);
        foreach my $tag (@$tags) {
#            $tag->writeToCaf(*STDOUT) if $noload;
        }
    }
    my $autoload = 1;
    my $success = $adb->putTagsForReads(\@reads,$autoload); # unless $noload;
    $logger->info("putTagsForReads success = $success");
}

# finally update the meta data for the Assembly and the Organism

# $adb->updateMetaData;

exit(0);

#------------------------------------------------------------------------
# subroutines
#------------------------------------------------------------------------

sub invert {
    my $value = shift;
#    $value = 50000 - $value;
#    $value = 21000 + $value;
    return $value;
}

sub tagList {
# e.g. list = tagList('FTAGS')
    my $name = shift;

# Finishers tags

    my @FTAGS = ('FINL','FINR','ANNO','FICM','RCMP','POLY','STSP',
                 'STSF','STSX','STSG','COMM','RP20','TELO','REPC',
                 'WARN','DRPT','LEFT','RGHT','TLCM','ALUS','VARI',
                 'CpGI','NNNN','SILR','IRPT','LINE','REPA','REPY',
                 'REPZ','FICM','VARD','VARS','CSED','CONS');

# software TAGS

    my @STAGS = ('ADDI','AFOL','AMBG','CVEC','SVEC','FEAT','REPT',
                 'MALX','MALI','XMAT','OLIG','COMP','STOP','PCOP',
                 'LOW' ,'MOSC','STOL');

# edit tags

    my @ETAGS = ('EDIT','DONE','MISS','MASK','UNCL','CONF','CLIP');

    my $list  = eval "join '|',\@$name";
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {

    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-caf\t\tcaf file name OR\n";
    print STDERR "-cafdefault\t(alternative to -caf) use the default caf file name\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
#    print STDERR "-NULL\t\t(no value) to direct output to /dev/null\n";
    print STDERR "-instance\teither prod (default) or 'dev'\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-projectname\tproject name\n";
    print STDERR "-project_id\tproject ID (alternative to above)\n";
    print STDERR "-minimum\tnumber of reads per contig\n";
    print STDERR "-filter\t\tcontig name substring or regular expression\n";
    print STDERR "-out\t\toutput file, default STDOUT\n";
    print STDERR "-test\t\tnumber of lines parsed of the CAF file\n";
    print STDERR "-readtags\t\tprocess read tags\n";
    print STDERR "-noload\t\tskip loading into database (test mode)\n";
#    print STDERR "-ignore\t\t(no value) contigs already processed\n";
    print STDERR "-frugal\t\t(no value) minimise memory usage\n";
    print STDERR "-verbose\t\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}


