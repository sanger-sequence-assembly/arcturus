package ContigFactory;

use strict;

use Contig;

use Mapping;

use Read;

use Tag;

use TagFactory::ReadTagFactory;

use TagFactory::ContigTagFactory;

use Clipping;

use Logging;

# ----------------------------------------------------------------------------
# building Contig instances from a Fasta file
# ----------------------------------------------------------------------------

sub fastaFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $fasfile = shift; # fasta file name
    my %options = @_;

    my $FASTA = new FileHandle($fasfile,'r'); # open for read

    return undef unless $FASTA;

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

    $FASTA->close();

    return $fastacontigs;
}

#-----------------------------------------------------------------------------
# building Contigs from CAF file 
#-----------------------------------------------------------------------------

my $LOGGER; # class variable

sub cafFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $caffile = shift; # caf file name or 0 
    my %options = @_;

# open logfile handle for output

    $LOGGER = new Logging('STDOUT') unless (ref($LOGGER) eq 'Logging');

# open file handle for input CAF file

    my $CAF;
    if ($caffile) {
        $CAF = new FileHandle($caffile, "r");
    }
    else {
        $CAF = *STDIN;
        $caffile = "STDIN";
    }

    unless ($CAF) {
	$LOGGER->severe("Invalid CAF file specification $caffile");
        return undef;
    }

#-----------------------------------------------------------------------------
# colect options   
#-----------------------------------------------------------------------------

    my $lineLimit = $options{linelimit}    || 0; # test purposes
    my $progress  = $options{progress}     || 0; # true or false progress (on STDERR)
    my $usePadded = $options{acceptpadded} || 0; # true or false allow padded contigs
    my $consensus = $options{consensus}    || 0; # true of false build consensus
    my $lowMemory = $options{lowmemory}    || 0; # true or false minimise memory

# set-up tag selection

    my $readtaglist = $options{readtaglist};
    $readtaglist =~ s/\W/|/g if ($readtaglist && $readtaglist !~ /\\/);
    $readtaglist = '\w{3,4}' unless $readtaglist; # default
    $LOGGER->fine("Read tags to be processed: $readtaglist");

    my $contigtaglist = $options{contigtaglist};
    $contigtaglist =~ s/\W/|/g if ($contigtaglist && $contigtaglist !~ /\\/);
    $contigtaglist = '\w{3,4}' unless $contigtaglist; # default
    $LOGGER->fine("Contig tags to be processed: $contigtaglist");

    my $edittags = $options{edittags} || 'EDIT';

# object filters

    my $contignamefilter = $options{contignamefilter} || ''; 

    my $readnameblocker  = $options{readnameblocker}  || ''; # test purposes

#----------------------------------------------------------------------
# allocate basic objects and object counters
#----------------------------------------------------------------------

    my ($read, $mapping, $contig);

    my (%contigs, %reads, %mappings);

    my $readblockhash = {}; # (internal) tracking of reads to be blocked (low memory)

# control switches

    my $lineCount = 0;
    my $truncated = 0;
    my $isUnpadded = 1; # default require unpadded data
    $isUnpadded = 0 if $usePadded; # allow padded, set pad status to unknown (0) 
    my $fileSize;
    if ($progress) {
# get number of lines in the file
        my $counts = `wc $caffile`;
        $counts =~ s/^\s+|\s+$//g;
        my @counts = split /\s+/,$counts;
        $progress = int ($counts[0]/20);
        $fileSize = $counts[0];
    }

# persistent variables

    my $objectType = 0;
    my $objectName = '';

    my $DNASequence = '';
    my $BaseQuality = '';

# set up the read tag factory and contig tag factory

    my $rtf = new ReadTagFactory();

    my $ctf = new ContigTagFactory();

    $LOGGER->info("Parsing CAF file $caffile");

    $LOGGER->info("Read a maximum of $lineLimit lines") if $lineLimit;

    $LOGGER->info("Contig (or alias) name filter $contignamefilter") if $contignamefilter;

    while (defined(my $record = <$CAF>)) {

#-------------------------------------------------------------------------
# line count processing: report progress and/or test line limit
#-------------------------------------------------------------------------

        $lineCount++;
        if ($progress && !($lineCount%$progress)) {
            my $fraction = sprintf ("%5.2f", $lineCount/$fileSize);           
            print STDERR "$fraction completed .....\r";
	}

# deal with (possible) line limit

        if ($lineLimit && $lineCount > $lineLimit) {
            $LOGGER->warning("Scanning terminated because of line limit $lineLimit");
            $truncated = 1;
            $lineCount--;
            last;
        }

# skip empty records

        chomp $record;
        next if ($record !~ /\S/);

#--------------------------------------------------------------------------
# checking padded/unpadded status and its consistence
#--------------------------------------------------------------------------

        if ($record =~ /([un]?)padded/i) {
# test consistence of character
            my $unpadded = $1 || 0;
            if ($isUnpadded <= 1) {
                $isUnpadded = ($unpadded ? 2 : 0); # on first entry
                if (!$isUnpadded && !$usePadded) {
                    $LOGGER->severe("Padded assembly is not accepted");
                    last; # fatal
                }
            }
            elsif (!$isUnpadded && $unpadded || $isUnpadded && !$unpadded) {
                $LOGGER->severe("Inconsistent padding specification at line "
                               ."$lineCount\n$record");
                last; # fatal
            }
            next;
        }

#---------------------------------------------------------------------------
# the main dish : detect the begin of a new object with definition of a name
# objectType = 0 : no object is being scanned currently
#            = 1 : a read    is being parsed currently
#            = 2 : a contig  is being parsed currently
#---------------------------------------------------------------------------

#$LOGGER->warning("TAG detected ($lineCount): $record") if ($record =~ /\bTag/);

        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:?\s*(\S+)/) {
# a new object is detected
            my $newObjectType = $1;
            my $newObjectName = $2;
# process the existing object, if there is one
            if ($objectType == 2) {
                $LOGGER->fine("END scanning Contig $objectName");
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
#                    $objectType = 0 if $cnBlocker->{$objectName};
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
                elsif ($readblockhash->{$objectName}) {
                    $objectType = 0;
	        }
            }
            next;
        }
       
# the next block handles a special case where 'Is_contig' is defined after 'assembled'

        if ($objectName =~ /contig/i && $record =~ /assemble/i 
                                     && abs($objectType) != 2) {
# decide if this contig is to be included
             if ($contignamefilter !~ /\S/ || $objectName =~ /$contignamefilter/) {
                $LOGGER->fine("NEW contig $objectName: ($lineCount) $record");
                if (!($contig = $contigs{$objectName})) {
# create a new Contig instance and add it to the Contigs inventory
                    $contig = new Contig($objectName);
                    $contigs{$objectName} = $contig;
                }
                $objectType = 2;
            }
            else {
                $LOGGER->fine("Contig $objectName SKIPPED");
                $objectType = -2;
            }
            next;
        }

# the next block handles the standard contig initiation

        if ($record =~ /Is_contig/ && $objectType == 0) {
# decide if this contig is to be included
            if ($contignamefilter !~ /\S/ || $objectName =~ /$contignamefilter/) {
                $LOGGER->fine("NEW contig $objectName: ($lineCount)");
                if (!($contig = $contigs{$objectName})) {
# create a new Contig instance and add it to the Contigs inventory
                    $contig = new Contig($objectName);
                    $contigs{$objectName} = $contig;
                }
                $objectType = 2;
            }
            else {
                $LOGGER->fine("Contig $objectName SKIPPED");
                $objectType = -2;
            }
        }

# standard read initiation

        elsif ($record =~ /Is_read/) {
# decide if this read is to be included
            if ($readblockhash->{$objectName}) {
# no, don't want it; does the read already exist?
                $read = $reads{$objectName};
                if ($read && $lowMemory) {
                    $read->DESTROY;
                    delete $reads{$objectName};
                } 
                $objectType = 0;
            }
            else {
                $LOGGER->finest("NEW Read $objectName: ($lineCount) $record");
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

#------------------------------------------------------------------------------

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
                        $LOGGER->info("Edited read $objectName detected ($lineCount)");
                    }
                }
                else {
                    $LOGGER->severe("Invalid alignment: ($lineCount) $record",2);
                    $LOGGER->severe("positions: @positions",2);
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

		my $tag = $rtf->makeTag($type,$trps,$trpf,TagComment => $info);

#                my $tag = new Tag('readtag');
#                $tag->setType($type);
#                $tag->setPosition($trps,$trpf);
#                $tag->setStrand('Forward');
#                $tag->setTagComment($info);

# the tag now contains the raw data read from the CAF file
# invoke ReadTagFactory to process, cleanup and test the tag info

#                $rtf->importTag($tag);
                $rtf->cleanup($tag); # clean-up the tag info
                if ($type eq 'OLIG' || $type eq 'AFOL') {        
# oligo, staden(AFOL) or gap4 (OLIG)
                    my ($warning,$report) = $rtf->processOligoTag($tag);
                    $LOGGER->fine($report) if $warning;
                    unless ($tag->getTagSequenceName()) {
		        $LOGGER->warning("Missing oligo name in read tag for "
                               . $read->getReadName()." (line $lineCount)");
                        next; # don't load this tag
	            }
	        }
                elsif ($type eq 'REPT') {
# repeat read tags
                    unless ($rtf->processRepeatTag($tag)) {
	                $LOGGER->info("Missing repeat name in read tag for "
                                  . $read->getReadName()." (line $lineCount)");
                    }
                }
	        elsif ($type eq 'ADDI') {
# chemistry read tag
                    unless ($rtf->processAdditiveTag($tag)) {
                        $LOGGER->info("Invalid ADDI tag ignored for "
                                  . $read->getReadName()." (line $lineCount)");
                        next; # don't accept this tag
                    }
 	        }
# test the comment; ignore empty comment tags
                unless ($tag->getComment() =~ /\S/) {
		    $LOGGER->severe("Empty $type read tag ignored for "
                                . $read->getReadName()." (line $lineCount)");
		    next; # don't accept this tag
		}

                $read->addTag($tag);
            }

            elsif ($record =~ /Tag/ && $record =~ /$edittags/) {
                $LOGGER->fine("READ EDIT tag detected but not processed: $record");
            }
            elsif ($record =~ /Tag/) {
                $LOGGER->info("READ tag not recognized: $record");
            }
# EDIT tags TO BE TESTED (NOT OPERATIONAL AT THE MOMENT)
       	    elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*replaced\s+(\w+)\s+by\s+(\w+)\s+at\s+(\d+)/) {
                $LOGGER->warning("readtag error in: $record |$1|$2|$3|$4|$5|") if ($1 != $2);
                my $tag = new Tag('edittag');
	        $tag->editReplace($5,$3.$4);
                $read->addTag($tag);
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*deleted\s+(\w+)\s+at\s+(\d+)/) {
                $LOGGER->warning("readtag error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
                my $tag = new Tag('edittag');
	        $tag->editDelete($4,$3); # delete signalled by uc ATCG
                $read->addTag($tag);
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*inserted\s+(\w+)\s+at\s+(\d+)/) {
                $LOGGER->warning("readtag error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
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
  	        $LOGGER->info("NOTE detected but not processed ($lineCount): $record");
            }
# finally
            elsif ($record !~ /SCF|Sta|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
                $LOGGER->warning("not recognized ($lineCount): $record");
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
                        unless ($readnameblocker && 
                                $read->getReadName =~ /$readnameblocker/) {
                            $contig->addMapping($mapping);
                            $contig->addRead($read);
                        }
                    }
# test number of alignments: padded allows only one record per read,
#                            unpadded may have multiple records per read
                    if (!$isUnpadded && $entry > 1) {
                        $LOGGER->severe("Multiple assembled_from in padded "
                                       ."assembly ($lineCount) $record");
                        undef $contigs{$objectName};
                        next;
                    }
                }
                else {
                    $LOGGER->severe("Invalid alignment: ($lineCount) $record");
                    $LOGGER->severe("positions: @positions",2);
                }
            }
            elsif ($record =~ /Tag\s+($contigtaglist)\s+(\d+)\s+(\d+)(.*)$/i) {
# detected a contig TAG
                my $type = $1; my $tcps = $2; my $tcpf = $3; 
                my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
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
                $LOGGER->info("CONTIG tag detected: $record\n"
                        . "'$type' '$tcps' '$tcpf' '$info'");
                if ($type eq 'ANNO') {
                    $info =~ s/expresion/expression/;
                    $type = 'COMM';
		}

                my $tag = $ctf->makeTag($type,$tcps,$tcpf);

#                my $tag = new Tag('contigtag');
#                $tag->setType($type);
#                $tag->setPosition($tcps,$tcpf);
#                $tag->setStrand('Unknown');
                $tag->setTagComment($info);
                if ($info =~ /([ACGT]{5,})/) {
                    $tag->setDNA($1);
                }
# pickup repeat name
                if ($type eq 'REPT') {
                    $contig->addTag($tag);
		    if ($info =~ /^\s*(\S+)\s+from/i) {
                        $tag->setTagSequenceName($1);
	            }
                    else {
		        $LOGGER->info("Missing repeat name in contig tag for ".
                             $contig->getContigName().": ($lineCount) $record");
                    }
                }
                elsif ($info) {
                    $contig->addTag($tag);
		    $LOGGER->fine($tag->writeToCaf());
                }
                else {
		    $LOGGER->warning("Empty $type contig tag ignored ($lineCount)");
		}

	    }
            elsif ($record =~ /Tag/) {
                $LOGGER->info("CONTIG tag not recognized: ($lineCount) $record");
            }
            else {
                $LOGGER->info("ignored: ($lineCount) $record");
            }
        }

        elsif ($objectType == -2) {
# processing a contig which has to be ignored: inhibit its reads to save memory
            if ($record =~ /Ass\w+from\s(\S+)\s(.*)$/) {
                $readblockhash->{$1}++; # add read in this contig to the block list
                $LOGGER->finest("read $1 blocked") unless (keys %$readblockhash)%100;
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
        	$LOGGER->info("ignored: ($lineCount) $record (t=$objectType)");
            } 
        }
# go to next record
    }

    $CAF->close();

# here the file is parsed and Contig, Read, Mapping and Tag objects are built
    
    $LOGGER->warning("Scanning of CAF file $caffile was truncated") if $truncated;
    $LOGGER->info("$lineCount lines processed of CAF file $caffile");

    my $nc = scalar (keys %contigs);
    my $nm = scalar (keys %mappings);
    my $nr = scalar (keys %reads);

    $LOGGER->info("$nc Contigs, $nm Mappings, $nr Reads built");

# return array references for contigs and reads 

    my $contigs = [];
    foreach my $key (keys %contigs) {
        push @$contigs, $contigs{$key};
    }

    my $reads = [];
    foreach my $key (keys %reads) {
        push @$reads, $reads{$key};
    }

    return $contigs,$reads;
}

#-----------------------------------------------------------------------------
# methods which take a Contig instance as input and (can) return a new Contig 
#-----------------------------------------------------------------------------

sub reverse {
# inverts all read alignments TO BE TESTED
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'reverse');

    $contig = &copy($contig) unless $options{nonew};

    my $length = $contig->getContigLength();

# the read mappings

    if ($contig->getMappings()) {
        my $mappings = $contig->getMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
# and sort the mappings according to increasing contig position
        @$mappings = sort {$a->getContigStart <=> $b->getContigStart} @$mappings;
    }

# possible parent contig mappings

    if ($contig->getContigToContigMappings()) {
        my $mappings = $contig->getContigToContigMappings();
        foreach my $mapping (@$mappings) {
            $mapping->applyMirrorTransform($length+1);
        }
    }

# tags

    my $tags = $contig->getTags();
    foreach my $tag (@$tags) {
        $tag->mirror($length+1);
    }

# replace the consensus sequence with the inverse complement

    if (my $consensus = $contig->getConsensus()) {
        my $newsensus = inverse($consensus);
        $newsensus =~ tr/ACGTacgt/TGCAtgca/;
	$contig->setConsensus($newsensus);
    }

    if (my $quality = $contig->getBaseQuality()) {
# invert the base quality array
        for (my $i = 0 ; $i < $length ; $i++) {
            my $j = $length - $i - 1;
            last unless ($i < $j);
            my $swap = $quality->[$i];
            $quality->[$i] = $quality->[$j];
            $quality->[$j] = $swap;
        }
    }
}

#-------------------------------------------------------------------------
# remove or replace bases
#-------------------------------------------------------------------------

sub deleteLowQualityBases {
# remove low quality dna from input contig
    my $class = shift;
    my $contig = shift;
    my %options = @_;

$LOGGER->("ENTER deleteLowQualityBases @_") if $LOGGER;

    &verifyParameter($contig,'deleteLowQualityBases');

# step 1: analyse DNA and Quality data to determine the clipping points

    my $pads = &findlowquality($contig->getSequence(),
                               $contig->getBaseQuality(),
                               %options);

# step 2: remove low quality pads from the sequence & quality;

    my ($sequence,$quality,$ori2new) = &removepads($contig->getSequence(),
                                                   $contig->getBaseQuality(),
                                                   $pads);

# out: new sequence, quality array and thye mapping from original to new

$LOGGER->("map $ori2new\n".$ori2new->toString(text=>'ASSEMBLED')) if $LOGGER;

    unless ($sequence && $quality && $ori2new) {
        print STDERR "Failed to determine new DNA or quality data\n";
        return undef;
    }

    my $segments = $ori2new->getSegments();
    if (scalar(@$segments) == 1) {
        my $segment = $segments->[0];
        my $length = $segment->[1] - $segment->[0];
        if ($length == length($contig->getSequence())) {
            return $contig, 0; # no bases clipped
        }
    }

# build the new contig

    my $clippedcontig = new Contig();

# add name and sequence

    my $contigname = $contig->getContigName() || '';
    $contigname .= "-low_quality_removed";
    $clippedcontig->setContigName($contigname);
                
    $clippedcontig->setSequence($sequence);
                
    $clippedcontig->setBaseQuality($quality);

# either treat the new contig as a child of the input contig

    if ($options{exportaschild}) {

$LOGGER->info("exporting as CHILD") if $LOGGER;

        my $mapping = $ori2new->inverse();
        $mapping->setSequenceID($contig->getContigID());
        $clippedcontig->addContigToContigMapping($mapping);
        $clippedcontig->addParentContig($contig);
        $contig->addChildContig($clippedcontig);
    }
# or port the transformed contig components by re-mapping from old to new
    elsif ($options{components}) {
        &remapcontigcomponents($contig,$ori2new,$clippedcontig,%options);
    }
 
    return $clippedcontig, 1;
}

#-----------------------------------------------------------------------------

sub replaceLowQualityBases {
# replace low quality pads by a given symbol
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'replaceLowQualityBases');

# test input contig data

    my $sequence = $contig->getSequence();
    my $quality  = $contig->getBaseQuality();

    my $length = length($sequence);

    return undef unless ($sequence && $quality && @$quality);

    return undef unless ($length && $length == scalar(@$quality));

# create a new Contig instance if so specified

    my $contigname = $contig->getContigName() || '';

    $contig = &copy($contig) if $options{new};

# replace low quality bases by the chosen symbol

    $options{padsymbol} = 'N' unless defined $options{padsymbol};

    my $padsymbol = $options{padsymbol};

# choose mode of replacement

    my $lowercase = 1; 
    if (defined($padsymbol) && length($padsymbol) == 1) {
# use the single symbol as replacement
        $lowercase = 0;
    }
    else {
# use lowercase for low quality stuff; hence switch high quality to UC
        $sequence = uc($sequence);
    }

    my $pads = &findlowquality(0,$quality,%options); # array of pad positions

    if (@$pads) {
# there are low quality bases
        my @dna = split //,$sequence;

        foreach my $pad (@$pads) {
            $dna[$pad] = $padsymbol unless $lowercase;
            $dna[$pad] = lc($dna[$pad]) if $lowercase;
	}
# reconstruct the sequence
        $sequence = join '',@dna;
# amend contigname
        $contigname .= "-low_quality_marked";
        $contigname .= "[$padsymbol]" unless $lowercase;
        $contigname .= "[lc]" if $lowercase;
        $contig->setContigName($contigname);
    }

    $contig->setSequence($sequence);

    return $contig;
}

#-----------------------------------------------------------------------------
# removing reads from contigs
#-----------------------------------------------------------------------------

sub deleteReads {
# remove a list of reads from a contig
    my $class  = shift;
    my $contig = shift;
    my $reads = shift;
    my %options = @_;

    &verifyParameter($contig,'deleteReads');

    $contig = &copy($contig) if $options{new};

    my ($count,$parity,$total) = &removereads($contig,$reads);

    unless ($total) {
        return undef,"No reads to be deleted specified";
    }

# parity and count must be 0 and a multiple of 3 respectively

    my $status = "p:$parity c:$count t:$total";

    if ($parity || $count%3) {
        return undef,"Badly configured input contig or returned contig ($status)";
    }
    
# test actual count against input read specification
    
    unless ($count > 0 && $count == 3*$total || $options{force}) {
        return undef,"No reads deleted from input contig ($status)" unless $count;
        return undef,"Badly configured input contig or returned contig ($status)";
    }

    return $contig,"OK ($status)";
}

#-----------------------------------------------------------------------------
# TO BE DEVELOPED

sub removeLowQualityReads {
# remove low quality bases and the low quality reads that cause them
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

$LOGGER->warning("ENTER removeLowQualityReads @_");

    &verifyParameter($contig,'removeLowQualityBases');

# step 1: analyse DNA and Quality data to determine the clipping points

    my $pads = &findlowquality($contig->getSequence(),
                               $contig->getBaseQuality(),
                               %options);

    return $contig unless ($pads && @$pads); # no low quality stuff found

# step 2: make a copy of the contig 

    $contig = &copy($contig) unless $options{nonew};

# step 3: make an inventory of reads stradling the pad positions

    my $mappings = $contig->getMappings() || return undef; # missing mappings

    @$mappings = sort {$a->getContigStart() <=> $b->getContigStart()} @$mappings; 

    my $padhash = &getCountsAtPadPositions($mappings,$pads,%options);

    my $readnamehash = $padhash->{readname};
    my $padcounthash = $padhash->{padcount};

$LOGGER->warning(scalar(keys %$readnamehash)." bad reads found");

    my $badcounts = {};
    foreach my $read (keys %$readnamehash) {
#        $LOGGER->warning("read $read  count $readnamehash->{$read}") if $LOGGER;
        $badcounts->{$readnamehash->{$read}}++;
    }
foreach my $count (sort {$a <=> $b} keys %$badcounts) {
    $LOGGER->warning("count : $count  frequency $badcounts->{$count}");
}

# 

    my $crosscount = {};
    foreach my $pad (keys %$padcounthash) {
        my $reads = $padcounthash->{$pad};
        next unless (scalar(@$reads) > 1);
        $LOGGER->warning("pad $pad has reads @$reads");
        foreach my $readi (@$reads) {
            foreach my $readj (@$reads) {
                next unless ($readi ne $readj); 
                $crosscount->{$readi} = {} unless $crosscount->{$readi};
                $crosscount->{$readi}->{$readj}++;
	    }
	}
    }

return $contig;

# step 4: delete both the Read and the Mapping for the reads

    &removereads($contig,$readnamehash);

# step 5: remove low quality pads from the sequence & quality

    my ($sequence,$quality,$ori2new) = &removepads($contig->getSequence(),
                                                   $contig->getBaseQuality(),
                                                   $pads);

$LOGGER->warning("map $ori2new\n".$ori2new->toString(text=>'ASSEMBLED')) if $LOGGER;

    unless ($sequence && $quality && $ori2new) {
        print STDERR "Failed to determine new DNA or quality data\n";
        return undef;
    }

# step 6, redo the mappings

    foreach my $mappingset ($mappings, $contig->getContigToContigMappings()) {
        next unless $mappingset;
        foreach my $mapping (@$mappingset) {
            my $newmapping = $mapping->multiply($ori2new);
            unless ($newmapping) {
                $LOGGER->severe("Failed to transform mappings");
                return undef;
	    }
            $mapping = $newmapping;
	}
    }

    return $contig;
}

sub removeShortReads {
# remove reads spanning less than a minimum number of bases
    my $class = shift;
    my $contig = shift;
    my %options = @_;

    &verifyParameter($contig,'removeShortReads');

    $contig->hasMappings(1); # delayed loading

    $contig = &copy($contig,includeIDs=>1) unless $options{nonew}; # new instance

# determine clipping threshold

    $options{threshold} = 1 unless defined($options{threshold});
    my $rejectionlevel = $options{threshold};
    
# process mappings

    my $mappings = $contig->getMappings();

    $LOGGER->info("(new) contig ".$contig->getContigName()
                . " has mappings ". scalar(@$mappings)) if $LOGGER;

    my $i = 0;
    my $readhash = {};
    while ($i < scalar(@$mappings)) {
        my $mapping = $mappings->[$i];
        my @position = $mapping->getContigRange();
        my $size = $position[1] - $position[0] + 1;
        if ($size <= $rejectionlevel) {
            my $mappingname = $mapping->getMappingName();
            $readhash->{$mappingname}++;
            splice @$mappings, $i,1;
            $LOGGER->info("mapping $mappingname removed, left "
                        .  scalar(@$mappings)) if $LOGGER;
        }
        else {
            $i++;
        }
    }

    my $delete = scalar(keys %$readhash);

    $LOGGER->info("Contig has $delete mappings deleted") if $LOGGER;

    return $contig unless $delete; # no short reads founds

    return $contig unless $contig->hasReads();

# now strip out the reads (if any)

    my $reads = $contig->getReads(); # no delayed loading

    $LOGGER->info("(new) contig ".$contig->getContigName()
                . " has reads ". scalar(@$reads) ." ("
                . $contig->getNumberOfReads() . ")") if $LOGGER;

    $i = 0;
    while ($i < scalar(@$reads)) {
        my $readname = $reads->[$i]->getReadName();

        if ($readhash->{$readname}) {
            splice @$reads, $i,1;
            $LOGGER->info("read $readname removed, left ".scalar(@$reads));
            $contig->setNumberOfReads($contig->getNumberOfReads()-1);
            $delete--;
        }
        else {
            $i++;
        }
    }

    return undef if $delete; # the mappings do not match the reads

    $LOGGER->info("Number of deleted reads match removed mapping(s) on contig "
                .  $contig->getContigName()) if $LOGGER;

    return $contig;
}

sub endRegionOnly { # other name required
# cut out the central part of the consensus and replace sequence by X-s in
# order to get a fixed length string which could be used in e.g. crossmatch
# returns a new contig object with only truncated sequence and quality data
    my $class  = shift;
    my $contig = shift;
    my %options = @_; 


print STDOUT "ENTER endRegionOnly\n";
    &verifyParameter($contig,'endRegionOnly');

    my ($sequence,$quality) = &endregiononly($contig->getSequence(),
                                             $contig->getBaseQuality(),@_);

# create a new output contig

    my $newcontig = new Contig();
    my $contigname = $contig->getContigName() . "-endregionmasked";
    $newcontig->setContigName($contigname);
    $newcontig->setSequence($sequence);
    $newcontig->setBaseQuality($quality);

    return $newcontig;
}

sub endregiononly {
# strictly private: generate masked sequence and quality data
    my $sequence = shift;
    my $quality  = shift;
    my %options = @_; 

    &verifyPrivate($sequence,'endregiononly');

# get options

    my $unmask = $options{endregiononly} || 100; # unmasked length at either end
    my $symbol = $options{maskingsymbol} || 'X'; # replacement symbol for remainder
    my $shrink = $options{shrink} || 0; # replace centre with fixed length string
    my $qfill  = $options{qfill}  || 0; # quality value to be used in centre

# apply lower limit, if shrink option active

    $shrink = $unmask if ($shrink < $unmask);

    my $length = length($sequence);

    if ($unmask > 0 && $symbol && $length > 2*$unmask) {

        my $begin  = substr $sequence,0,$unmask;
        my $centre = substr $sequence,$unmask,$length-2*$unmask;
        my $end = substr $sequence,$length-$unmask,$unmask;

# adjust the center, if shrink option

        if ($shrink && $length-2*$unmask >= $shrink) {
            $centre = '';
            while ($shrink--) {
                $centre .= $symbol;
            }
        }
	else {
            $centre =~ s/./$symbol/g;
	}

        $sequence = $begin.$centre.$end;

# assemble new quality array, if an input was defined

        if ($quality) {

            my @newquality = @$quality[0 .. $unmask-1];
            my $length = length($centre);
            while ($length--) {
		push @newquality, $qfill;
	    }
            push @newquality, @$quality[$length-$unmask .. $length-1];

            $quality = \@newquality;
	}
    }

    return $sequence,$quality;
}

#-----------------------------------------------------------------------------

sub endRegionTrim {
# trim low quality data from the end of the contig
    my $class  = shift;
    my $contig = shift;
    my %options = @_;

print STDOUT "ENTER endRegionTrim\n";
    &verifyParameter($contig,'endRegionTrim');

    my ($sequence,$quality,$mapping) = &endregiontrim($contig->getSequence(),
                                                      $contig->getBaseQuality(),
                                                      %options);
    unless ($sequence && $quality && $mapping) {
        return undef,"Can't do trimming: missing quality data in "
                    . $contig->getContigName()."\n";
    }

    if (ref($mapping) ne 'Mapping') {
        return $contig, "No change";
    }

# create a new contig

    my $clippedcontig = new Contig();
    my $contigname = $contig->getContigName() || '';
    $contigname .= "-endregionclipped[$options{cliplevel}]";
    $clippedcontig->setContigName($contigname);

    $clippedcontig->setSequence($sequence);

    $clippedcontig->setBaseQuality($quality);

# and port the components, if any, to the newly created clipped contig

# breaktags,mergetags
    &remapcontigcomponents($contig,$mapping,$clippedcontig,%options); # TO BE TESTED

    my @range = $mapping->getContigRange();

    return $clippedcontig, "clipped range @range";
}

sub endregiontrim {
# strictly private: trim low quality data from the end of the contig
    my $sequence = shift;
    my $quality  = shift;
    my %options = @_; 

    &verifyPrivate($sequence,'endregiontrim');

    return undef unless ($sequence && $quality && @$quality);

    my $cliplevel = $options{cliplevel} || return $sequence, $quality, 1; # no change

# clipping algorithm for the moment taken from Asp

    my ($QL,$QR) = Clipping->phred_clip($cliplevel, $quality);

# adjust the sequence and quality data

    my $newsequence = substr($sequence,$QL-1,$QR-$QL+1);

    my @newquality  = @$quality [$QL-1 .. $QR-1];

    my $mapping = new Mapping();
    $mapping->putSegment($QL, $QR, 1, $QR-$QL+1);

    return $newsequence, \@newquality, $mapping;
}

#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# private methods
#-----------------------------------------------------------------------------

sub copy {
# create a copy of input contig and (some of) its components (as they are)
    my $contig = shift;
    my %options = @_;

    &verifyPrivate($contig,'copy');

# create a new instance

    my $newcontig = new Contig();

# (default do not) add name and sequence ID 

    if ($options{includeIDs}) {
        $newcontig->setContigName($contig->getContigName());
        $newcontig->setContigID($contig->getContigID());
    }

# always add consensus data
                
    $newcontig->setSequence($contig->getSequence);
                
    $newcontig->setBaseQuality($contig->getBaseQuality);

# (optionally) copy the arrays of references to any other components

    my @components  = ('Read','Mapping','Tag','ParentContig',
                       'ChildContig','ContigToContigMapping');

    return $newcontig if $options{nocomponents};

    foreach my $component (@components) {

       eval "\$newcontig->add$component(\$contig->get${component}s())";
       print STDERR "$@\n" if $@; 
    }

    return $newcontig;
}

sub findlowquality {
# scan quality data and/or dna data; return an array of low quality positions
    my $sequence = shift;
    my $quality = shift;
    my %options = @_;

    &verifyPrivate($sequence,'findlowquality');

# check input

    my $length = scalar(@$quality);
$LOGGER->warning("ENTER findlowquality ($length) @_") if $LOGGER;

    if ($sequence) {
        return undef unless ($length == length($sequence));
    }

# get control parameters

    my $symbols   = $options{symbols} || 'ACGT';
    my $threshold = $options{threshold} || 20;
    my $minimum   = $options{minimum}   || 15;
# ensure an odd window length
    my $fwindow   = $options{window}    ||  9;
    my $hwindow = int($fwindow/2);
    $options{window} = 2 * $hwindow + 1;
# require minimum significance for low quality pads already present as e.g. N or X
    my $lowqualitypadminimum = $options{lqpm} || 30; 

# ok, scan the quality array/dna to locate low quality pads

    my $pads = [];

    my $reference = &slidingmeanfilter($quality,$fwindow) || [];

    for (my $i = $hwindow ; $i <= $length - $hwindow ; $i++) {
# test the base
        if ($sequence && substr($sequence, $i, 1) !~ /[$symbols]$/) {
#print STDOUT "alien symbol found: ". substr($sequence, $i, 1) . " $quality->[$i]\n";
            next unless ($quality->[$i] > $lowqualitypadminimum);
            push @$pads, $i; # zeropoint 0
            next;
	}
# if no reference level provided use a default mean filter
        unless ($reference && $reference->[$i]) {
            $reference->[$i] = ($quality->[$i-2] + $quality->[$i+2]) / 2;
	}
# test the quality
        if ($quality->[$i] < $reference->[$i] - $threshold) {
            next if ($quality->[$i] >= $minimum);
            push @$pads, $i; # zeropoint 0
	}
    }

#    @$pads = sort {$a <=> $b} @$pads;

    return $pads;
}

sub slidingmeanfilter {
# sliding mean filtering of (quality) array
    my $qinput = shift;
    my $window = shift;
#$LOGGER->warning("ENTER slidingmeanfilter $window") if $LOGGER;

    &verifyPrivate($qinput,'slidingmeanfilter');

# step 1 : determine filter to be used

    my $nfwhalf = int(($window-1)/2 + 1 +0.5); # half filter width
    my $nfilter = $nfwhalf + $nfwhalf - 1;     # ensure odd length

    my @filter;
    for (my $i = 0 ; $i < $window ; $i++) {
        $filter[$i] = $1.0;
    }

# step 2: apply log transform

    my $qoutput = [];
    my $loghash = {};

    my $logtransform;
    my $offset = 10000.0;
# print STDOUT "begin LOG transform\n";
    foreach my $value (@$qinput) {
        my $logkey = int($value+$offset+0.5);
        unless ($logtransform = $loghash->{$logkey}) {
            $loghash->{$logkey} = log($logkey);
            $logtransform = $loghash->{$logkey};
# print STDOUT "creating log hash element for key $logkey\n"; 
        }
        push @$qoutput,$logtransform;
    }
# print STDOUT "DONE LOG transform\n";

# step 3: apply sliding mean filter

    my $b = []; # scratch buffer

    my $filtersum = 0.0;
    foreach my $element (@filter) {
	$filtersum += $element;
    }
   
    

# step 4: apply inverse log transform

# print STDOUT "begin EXP transform\n";
    foreach my $value (@$qoutput) {
        $value = int(exp($value) - $offset + 0.5);
    } 
# print STDOUT "DONE EXP transform\n";
    return undef;
}

sub removepads {
# remove base and quality data at given pad positions 
    my $sequence = shift; # string
    my $quality = shift; # array ref
    my $pads = shift; # array ref
#print STDOUT "ENTER removepads @_\n";
#print STDOUT "PADS @$pads \n";

    &verifyPrivate($sequence,'removepads');

    my $sorted = [];
    @$sorted = sort {$a <=> $b} @$pads;
# extend the array with an opening and closing pad (pads start counting at 1)
    push @$sorted, length($sequence)+1;
    unshift @$sorted, 0;

    my $newquality = [];
    my $newsequence = '';
    my $mapping = new Mapping();

    for (my $i = 1 ; $i < scalar(@$sorted) ; $i++) {
# get the begin and end of the interval in the original sequence (zeropoint = 1)
        my $final = $sorted->[$i] - 1;
        my $start = $sorted->[$i-1] + 1;
        my $interval = $final - $start + 1;
        next unless ($interval > 0);
# get the begin of the interval from the current size of the ouput array
        my $newstart = scalar(@$newquality);
# assemble the sequence
        $newsequence .= substr($sequence, $start, $interval);        
        push @$newquality, @$quality [$start .. $final];
# assemble the segment for the mapping
        $mapping->putSegment($start+1,$final+1,$newstart+1,$newstart+$interval);
    }
    return $newsequence,$newquality,$mapping;
}

#-----------------------------------------------------------------------------------

sub getCountsAtPadPositions {
# private: build count table at input pad positions
    my $mappings = shift; # array ref
    my $pads = shift; # array ref with pad positions to be tested

    &verifyPrivate($mappings,'testPaPositions');

    my $padhash = {};
    $padhash->{readname} = {};
    $padhash->{padcount} = {};

    my $trialpad = 0;
    foreach my $mapping (@$mappings) {
        next unless $mapping->hasSegments();
        my $segments = $mapping->getSegments();
        my ($cs,$cf) = $mapping->getContigRange();
        while ($pads->[$trialpad] && $pads->[$trialpad] + 1 < $cs) {
            $trialpad++;
	}
        next unless ($pads->[$trialpad] && $pads->[$trialpad] + 1 < $cf);

        my $readname = $mapping->getMappingName();
        foreach my $segment (@$segments) {
# register the mapping name (= read name) if a pad position falls inside a segment
            my $pad = $trialpad;
            while ($pads->[$pad] && $pads->[$pad] + 1 < $cf) {
                if (my $y = $segment->getYforX($pads->[$pad] + 1)) {
                    $padhash->{readname}->{$readname}++;
                    unless ($padhash->{$pad}) {
                        $padhash->{padcount}->{$pad} = [];
                    }
                    push @{$padhash->{padcount}->{$pad}},$readname;
		}
		$pad++;
            }
	}
    }

    return $padhash;
}

#----------------------------------------------------------------------------------
sub remapcontigcomponents {
# take components from oldcontig, remap using ori2new, put into newcontig
    my $oldcontig = shift; # original contig
    my $ori2new   = shift; # mapping original to new
    my $newcontig = shift; 
    my %options = @_;

print STDOUT "ENTER remapcontigcomponents @_\n";
    &verifyPrivate($oldcontig,'remapcontigcomponents');

# add and transform the mappings; keep track of the corresponding reads

    my $readnamehash = {};
    my $mappings = $oldcontig->getMappings();
    foreach my $mapping (@$mappings) {
        my $newmapping = $mapping->multiply($ori2new);
        next unless $newmapping;
        $readnamehash->{$mapping->getMappingName()}++;
        $newcontig->addMapping($newmapping);
    }

# add the reads, if they are present in the input oldcontig

    my $reads = $oldcontig->getReads();
    foreach my $read (@$reads) {
        next unless $readnamehash->{$read->getReadName()};
        $newcontig->addRead($read);
    }

# and remap the tags on the sequence

    if ($oldcontig->hasTags()) {

        my $tagfactory = new ContigTagFactory();

        my $tags = $oldcontig->getTags();

        my $breaktags = $options{breaktags} || 'ANNO';
        $breaktags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $breaktags =~ s/\W+/|/g;

        my @newtags;
        foreach my $tag (@$tags) {
# special treatment for ANNO tags?
            my $tagtype = $tag->getType();
            if ($tagtype =~ /$breaktags/) {
                my $newtags = $tagfactory->remap($tag,$ori2new,break=>1);
                push @newtags, @$newtags if $newtags;
            }
            else {
                my $newtag  = $tagfactory->remap($tag,$ori2new,break=>0);
                push @newtags, $newtag if $newtag;
	    }
	}

# test if some tags can be merged (using the Tag factory)

        my $mergetags = $options{mergetags} || 'ANNO';
        $mergetags =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        $mergetags =~ s/\W+/|/g;

        my @tags = $tagfactory->mergeTags([@newtags],$mergetags);        

# and add to the new contig

        $newcontig->addTag(@tags);
    }

# finally, investigate possible parent links

    if ($oldcontig->hasContigToContigMappings()) {
# get the mapping of newcontig to each parent of oldcontig
        my $new2old = $ori2new->inverse();
        my $parentmappings = $oldcontig->getContigToContigMappings();
        my $parentnamehash = {};
        foreach my $mapping (@$parentmappings) {
            my $newmapping = $new2old->multiply($mapping);
            next unless $newmapping;
            $newcontig->addContigToContigMapping($newmapping);
            $parentnamehash->{$mapping->getMappingName()}++;
	}
# and add the parent(s)
        my $parentcontigs = $oldcontig->getParentContigs();
        foreach my $parent (@$parentcontigs) {
            next unless $parentnamehash->{$parent->getContigName()};
	    $newcontig->addParentContig($parent);
	}
    }
}

sub removereads {
# remove named reads from the Read and Mapping stock
    my $contig = shift;
    my $readrf = shift; # readid, array-ref or hash

    &verifyPrivate($contig,"removeRead");

# get the readname hash

    my $readidhash = {};
    if (ref($readrf) eq 'HASH') {
        $readidhash = $readrf;
    }
    elsif (ref($readrf) eq 'ARRAY') {
        foreach my $identifier (@$readrf) {
            $readidhash->{$identifier}++;
        }
    }
    else {
        $readidhash->{$readrf}++;
    }
    
# run through the reads and mappings and remove the ones that match

    my $parity = 0;
    my $splicecount = 0;
    my $total = scalar(keys %$readidhash);

    my $reads = $contig->getReads(1);
    for (my $i = 0 ; $i < scalar(@$reads) ; $i++) {
        next unless ($readidhash->{$reads->[$i]->getReadName()}
             or      $readidhash->{$reads->[$i]->getReadID()});
        delete $readidhash->{$reads->[$i]->getReadID()}; # remove read ID
        $readidhash->{$reads->[$i]->getSequenceID()}++;  # and replace by sequence ID
        splice @$reads,$i,1;
        $contig->setNumberOfReads(scalar(@$reads));
        $splicecount += 2;
        $parity++;
        next unless $LOGGER;
        $LOGGER->warning("read ".$reads->[$i]->getReadName()." ($i) removed");
    }
            
    my $mapps = $contig->getMappings(1);
    for (my $i = 0 ; $i < scalar(@$mapps) ; $i++) {
        next unless ($readidhash->{$mapps->[$i]->getMappingName()}
             or      $readidhash->{$mapps->[$i]->getSequenceID()});
        splice @$mapps,$i,1;
        $splicecount++;
        $parity--;
        next unless $LOGGER;
        $LOGGER->warning("mapping ".$mapps->[$i]->getMappingName()." ($i) removed");
    }

    return $splicecount,$parity,$total;
}

#-----------------------------------------------------------------------------
# access protocol
#-----------------------------------------------------------------------------

sub verifyParameter {
    my $contig = shift;
    my $origin = shift || 'verifyParameter';

    return if (ref($contig) eq 'Contig');

    die "ContigFactory->$origin expects a Contig instance as parameter";
}

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $origin = shift || 'verifyPrivate';

    return unless (ref($caller) eq 'ContigFactory');
	
    die "Invalid usage of private method '$origin' in package ContigFactory";
}

#-----------------------------------------------------------------------------
# log file
#-----------------------------------------------------------------------------

sub logger {
    my $class = shift;
    $LOGGER = shift;
}

#-----------------------------------------------------------------------------

1;
