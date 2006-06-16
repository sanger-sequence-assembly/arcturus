package ContigFactory;

use strict;

use Contig;

use Logging;

# ----------------------------------------------------------------------------
# building Contig instances from a Fasta file
# ----------------------------------------------------------------------------

sub fastaFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $FASTA = shift; # file handle to the fasta file 
    my %options = @_;

    my $fastacontigs = [];

    undef my $contig;
    my $sequence = '';

    my $line = 0;
    my $report = $options{report};
    while (defined (my $record = <$FASTA>)) {

        $line++;
        if ($report && ($line%$report == 0)) {
            print STDERR "processing line $line\n";
	}

        if ($record !~ /\S/) {
            next; # empty
	}
# new contig 
        elsif ($record =~ /\>(\S+)/) {
# add existing contig to output stack
            if ($contig && $sequence) {
                $contig->setSequence($sequence);
                push @$fastacontigs, $contig;
	    }
# open a new contig object
            $contig = new Contig();
# assign name
            my $contigname = $1;
            $contig->setContigName($contigname);
# and reset sequence
            $sequence = '';
	}

        elsif ($contig) {
# append DNA string to existing sequence
            $record =~ s/\s+//g; # remove blanks
	    $sequence .= $record;
        }
        else {
            print STDERR "Ignore data: $record\n";
	}
    }
# add the last one to the stack 
    push @$fastacontigs, $contig if $contig;

    return $fastacontigs;
}

#-----------------------------------------------------------------------------
# building Contigs from CAF file 
#-----------------------------------------------------------------------------

sub cafFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $caffile = shift; # caf file name or 0 
    my $logger  = shift;
    my %options = @_;

# logfile

    $logger = new Logging('STDOUT') unless (ref($logger) eq 'Logging');

# options   

    my $lineLimit = $options{linelimit}  || 0; # test purposes
    my $progress  = $options{progress}   || 0; # true or false  signal progress STDERR
    my $usePadded = $options{usepadded}  || 0; # true or false  allow padded contigs
    my $consensus = $options{consensus}  || 0; # true of false  build consensus
    my $lowMemory = $options{lowmemory}  || 0; # true or false  minimise memory

# set-up tag selection

    my $readtaglist = $options{readtaglist};
    my $readtagmode = $options{readtagmode};
my $ETAGS = $options{edittags};

# object filters

    my $rnBlocker = $options{readblock}    || 0; # read name filter pattern ??
    my $cnBlocker = $options{contigblock}  || 0; # externally defined hash  ??
    my $cnFilter  = $options{contigfilter} || 0; 

#----------------------------------------------------------------
# open file handle for input CAF file
#----------------------------------------------------------------

    my $CAF;
    if ($caffile) {
        $CAF = new FileHandle($caffile, "r");
    }
    else {
        $CAF = *STDIN;
        $caffile = "STDIN";
    }

    unless ($CAF) {
	$logger->severe("Invalid CAF file specification $caffile");
        return undef;
    }

    my $fileSize;
    if ($progress) {
# get number of lines in the file
        my @counts = `wc $caffile`;
        $progress = $counts[0]/20;
        $fileSize = $counts[0];
    }

#----------------------------------------------------------------------
# allocate basic objects and object counters
#----------------------------------------------------------------------

    my ($read, $mapping, $contig);

    my (%contigs, %reads, %mappings);

    undef my %rnBlocked; # internal tracking of blocking for low memory

# objectType = 0 : no object is being scanned currently
#            = 1 : a read    is being parsed currently
#            = 2 : a contig  is being parsed currently

    my $objectType = 0;
    my $objectName = '';
#my $buildReads = 0;

    undef my $record;
    my $lineCount = 0;
    my $truncated = 0;
    my $isUnpadded = 1 - $usePadded;

    my $DNASequence = '';
    my $BaseQuality = '';

    $logger->info("Parsing CAF file $cafFileName");

    while (defined($record = <$CAF>)) {

#--------------------------------------------------------------
# line count processing: report progress and/or test line limit
#--------------------------------------------------------------

        $lineCount++;
        if ($progress && !($lineCount%$progress)) {
            my $fraction = sprintf ("%5.2f", $lineCount/$fileSize);           
            print STDERR "$fraction completed .....\r";
	}

# deal with (possible) line limit

        if ($lineLimit && $lineCount > $lineLimit) {
            $logger->warning("Scanning terminated because of line limit $lineLimit");
            $truncated = 1;
            $lineCount--;
            last;
        }

# skip empty records

        chomp $record;
        next if ($record !~ /\S/);

#--------------------------------------------------------------
# checking padded/unpadded status and its consistence
#--------------------------------------------------------------

        if ($record =~ /([un]?)padded/i) {
# test consistence of character
            my $unpadded = $1 || 0;
            if ($isUnpadded <= 1) {
                $isUnpadded = ($unpadded ? 2 : 0); # on first entry
                if (!$isUnpadded && !$usePadded) {
                    $logger->severe("Padded assembly is not accepted");
                    last; # fatal
                }
            }
            elsif (!$isUnpadded && $unpadded || $isUnpadded && !$unpadded) {
                $logger->severe("Inconsistent padding specification at line "
                               ."$lineCount");
                last; # fatal
            }
            next;
        }

# the main dish : detect the begin of a new object with definition of a name

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
                    if ($isUnpadded && $align && scalar(@$align) == 1) {
                        $objectType = 0;
		    }
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

        if ($objectName =~ /contig/i && $record =~ /assemble/i 
                                     && abs($objectType) != 2) {
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

#-----------------------------------------------------------------------------------

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
# on first encounter load the read item dictionaries
#                    $adb->populateLoadingDictionaries() unless $dictionaries;
#                    $dictionaries = 1;
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
            elsif ($record =~ /Tag\s+($readtaglist)\s+(\d+)\s+(\d+)(.*)$/i) {

                my $type = $1; my $trps = $2; my $trpf = $3; my $info = $4;
# test for a continuation mark (\n\); if so, read until no continuation mark
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

# build a new read Tag instance

                my $tag = new Tag('readtag');
                $tag->setType($type);
                $tag->setPosition($trps,$trpf);
                $tag->setStrand('Forward');
                $tag->setTagComment($info);

# and create a new ReadTag factory object, to process and test the tag info

                my $readtag = new ReadTag($tag); # invoke the read tag "factory"
                $readtag->cleanup(); # clean-up the tag info
                if ($type eq 'OLIG' || $type eq 'AFOL') {        
# oligo, staden(AFOL) or gap4 (OLIG)
                    my ($warning,$report) = $readtag->processOligoTag();
                    $logger->info($report) if $warning;
                    unless ($tag->getTagSequenceName()) {
		        $logger->warning("Missing oligo name in read tag for "
                               . $read->getReadName()." (line $lineCount)");
                        next; # don't load this tag
	            }
	        }
                elsif ($type eq 'REPT') {
# repeat read tags
                    unless ($readtag->processRepeatTag()) {
	                $logger->info("Missing repeat name in read tag for ".
                                       $read->getReadName());
                    }
                }
	        elsif ($type eq 'ADDI') {
# chemistry read tag
                    unless ($readtag->processAdditivesTag()) {
                        $logger->info("Invalid ADDI tag ignored for ".
                                       $read->getReadName());
                        next; # don't accept this tag
                    }
 	        }

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
                my $tag = new Tag('edittag');
	        $tag->editReplace($5,$3.$4);
                $read->addTag($tag);
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*deleted\s+(\w+)\s+at\s+(\d+)/) {
                $logger->warning("error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
                my $tag = new Tag('edittag');
	        $tag->editDelete($4,$3); # delete signalled by uc ATCG
                $read->addTag($tag);
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*inserted\s+(\w+)\s+at\s+(\d+)/) {
                $logger->warning("error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
                my $tag = new Tag('edittag');
	        $tag->editDelete($4,$3); # insert signalled by lc atcg
                $read->addTag($tag);
            }
            elsif ($record =~ /Note\sINFO\s(.*)$/) {

	        my $trpf = $read->getSequenceLength();
#            my $tag = new Tag('readtag');
#            $tag->setType($type);
#            $tag->setPosition($trps,$trpf);
#            $tag->setStrand('Forward');
#            $tag->setTagComment($info);
	        my $r = $record;
#	    $logger->warning("NOTE detected: $r but not processed") if $noload;
#	    $logger->info("NOTE detected: $r but not processed") unless $noload;
            }
# finally
            elsif ($record !~ /SCF|Sta|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
                $logger->warning("not recognized ($lineCount): $record") unless $readtagmode;
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
# an asssembled from record
                    my $entry = $mapping->addAssembledFrom(@positions); 
# $entry returns number of alignments: add Mapping and Read for first
                    if ($entry == 1) {
                        unless ($rnBlocker && $read->getReadName =~ /$rnBlocker/) {
                            $contig->addMapping($mapping);
                            $contig->addRead($read);
                        }
                    }
# test number of alignments: padded allows only one record per read,
#                            unpadded may have multiple records per read
                    if (!$isUnpadded && $entry > 1) {
                        $logger->severe("Multiple assembled_from in padded "
                                       ."assembly ($lineCount) $record");
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
#$logger->info("CONTIG tag: $record\n'$type' '$tcps' '$tcpf' '$info'") if $noload;
                my $tag = new Tag('contigtag');
                $contig->addTag($tag);
                $tag->setType($type);
                $tag->setPosition($tcps,$tcpf);
                $tag->setStrand('Unknown');
                $tag->setTagComment($info);
                if ($info =~ /([ACGT]{5,})/) {
                    $tag->setDNA($1);
                }
# pickup repeat name
                if ($type eq 'REPT') {
		    if ($info =~ /^\s*(\S+)\s+from/i) {
#$logger->info("TagSequenceName $1") if $noload;
                        $tag->setTagSequenceName($1);
	            }
                    else {
		        $logger->warning("Missing repeat name in contig tag for ".
                                 $contig->getContigName().": ($lineCount) $record");
                    }
                }
	    }
            elsif ($record =~ /Tag/) {
                $logger->warning("CONTIG tag not recognized: ($lineCount) $record") unless $readtagmode;
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
            if ($record !~ /sequence/i) {
        	$logger->info("ignored: ($lineCount) $record (t=$objectType)");
            } 
        }
# go to next record
    }

    $CAF->close();

# here the file is parsed and Contig, Read, Mapping and Tag objects are built
    
    $logger->warning("Scanning of CAF file $caffile was truncated") if $truncated;
    $logger->info("$lineCount lines processed of CAF file $caffile");

    my $nc = scalar (keys %contigs);
    my $nm = scalar (keys %mappings);
    my $nr = scalar (keys %reads);

    $logger->info("$nc Contigs, $nm Mappings, $nr Reads built");

# return an array reference 

    my $contigs = [];
    foreach my $key (keys %contigs) {
        push @$contigs, $contigs{$key};
    }

    return $contigs;
}

#-----------------------------------------------------------------------------

1;
