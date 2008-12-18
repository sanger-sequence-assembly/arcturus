package ContigFactory;

use strict;

use Contig;

use Mapping;

use Read;

use Tag;

use TagFactory::TagFactory;

use Clipping;

use Logging;

# ----------------------------------------------------------------------------
# constructor (if you need an object; all methods can be called on the class)
# ----------------------------------------------------------------------------

sub new {
# create a ContigFactory object
    my $class = shift;

    my $this = {};

    bless $this,$class;

    return $this;
}

# ----------------------------------------------------------------------------
# building Contig instances from a flat file
# ----------------------------------------------------------------------------

sub getContigs {
# returns array of Contig instances found on input file
    my $class = shift;
    my $filename = shift;
    my %options = @_;

    my $format = $options{format};
    delete $options{format};

    unless ($format) {
        if ($filename =~ /\.(\w+)\s*$/) {
            $format = $1; # take file extension as type indicator
	}
    }

    
    if ($format eq 'fasta' || $format eq 'fas' || $format eq 'fna') {
        return &fastaFileParser($class,$filename,%options);
    }
    elsif ($format eq 'embl') {
        return &emblFileParser($class,$filename,%options);
    }
    elsif ($format eq 'caf') {
        return &cafFileParser($class,$filename,%options);
    }

    my $logger = &verifyLogger('getContigs');

    $logger->error("unknown format for file $filename");

    return undef;
}

# ----------------------------------------------------------------------------
# building Contig instances from a Fasta file
# ----------------------------------------------------------------------------

sub fastaFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $fasfile = shift; # fasta file name
    my %options = @_;

    my $logger = &verifyLogger('fastaFileParser');

# parsing parameters

    my $limit   = $options{limit};   # optional, maximum  number of fasta sequences to process
    my $quality = $options{quality}; # optional, file name with quality data

    my $FASTA = new FileHandle($fasfile,'r'); # open for read

    return undef unless $FASTA;

    my $fastacontigs = [];
    my $fcontignames = {};

    undef my $contig;
    my $sequence = '';

    my $line = 0;
    my $report = $options{report};
    while (defined (my $record = <$FASTA>)) {

        $line++;
        if ($report && ($line%$report == 0)) {
            $logger->error("processing line $line",bs => 1);
	}

        if ($record !~ /\S/) {
            next; # empty
	}
# new contig 
        elsif ($record =~ /\>(\S+)\s(.*)$/) {
            my $contigname = $1;
            my $attributes = $2;
# add existing contig to output stack
            if ($contig && $sequence) {
                $contig->setSequence($sequence);
                push @$fastacontigs, $contig;
                $fcontignames->{$contig->getContigName()} = $contig;
                undef $contig;
                last if ($limit && scalar(@$fastacontigs) >= $limit);
	    }
# open a new contig object
            $contig = new Contig();
# assign name
            $contig->setContigName($contigname);
            $contig->setContigNote($attributes);
# and reset sequence
            $sequence = '';
	}

        elsif ($contig) {
# append DNA string to existing sequence
            $record =~ s/\s+//g; # remove blanks
	    $sequence .= $record;
        }
        else {
            $logger->error("Ignore data: $record");
	}
    }
# add the last one to the stack 
    if ($contig && $sequence) {
        $contig->setSequence($sequence);
        push @$fastacontigs, $contig;
    }

    $FASTA->close();

    return $fastacontigs unless $quality;

    my $QFILE = new FileHandle($quality,'r'); # open for read

    return undef unless $QFILE;

    undef $contig;
    $quality = '';

    $line = 0;
    while (defined (my $record = <$QFILE>)) {

        $line++;
        if ($report && ($line%$report == 0)) {
            $logger->error("processing line $line",bs => 1);
	}

        if ($record !~ /\S/) {
            next; # empty
	}

        elsif ($record =~ /\>(\S+)/) {
# new name encountered; add existing quality to contig
            if ($contig && $quality) {                
                $quality =~ s/^\s+|\s+$//g;
                my @quality = split /\s+/,$quality;              
                $contig->setBaseQuality([@quality]);
            }
            my $contigname = $1;
            $contig = $fcontignames->{$contigname};
            $quality = '';
	}

        elsif ($contig) {
# append DNA string to existing sequence
	    $quality .= $record . " ";
        }

    }
        
    if ($contig && $quality) {                
        $quality = s/^\s+|\s+$//g;
        my @quality = split /\s+/,$quality;              
        $contig->setBaseQuality([@quality]);
    }

    return $fastacontigs;
}

sub emblFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $emblfile = shift; # embl file name
    my %options = @_;

    my $logger = &verifyLogger('emblFileParser');

    my $EMBL = new FileHandle($emblfile,'r'); # open for read

    return undef unless $EMBL;

    my $emblcontigs = [];

    undef my $contig;
    undef my @contigtag;

    my $parsetag = 0;
    my $tagdescriptors = "Tag|CDS|CDS_motif|repeat_region";
    my %translation = (CDS_motif => 'CDSM' , repeat_region => 'REPT' , CDS => 'CDS' , Tag => 'TAG');  

    my $sequence = '';
    my $length = 0;
    my $checksum = 0;

    my $line = 0;
    my $report = $options{report};

    while (defined (my $record = <$EMBL>)) {

        $line++;
        if ($report && ($line%$report == 0)) {
            $logger->error("processing line $line",bs => 1);
	}

        if ($record !~ /\S/) {
            next; # empty
	}

        elsif ($record =~ /^ID\s*(.*)$/) {
# new identifier found; add existing contig to output stack
            my $identifier = $1;
            $logger->fine("contig opened $identifier");
            if ($contig && $sequence) {
                unless ($length == $checksum) {
		    $logger->error("Checksum error ($checksum - $length) on embl file "
                                  .$contig->getContigName());
		}
                $contig->setSequence($sequence);
                foreach my $tag (@contigtag) {
                    $contig->addTag($tag);
		}
                undef @contigtag;
                push @$emblcontigs, $contig;
	    }
# and open a new one
            $contig = new Contig();
# assign name
            my @headeritem = split ';',$identifier;
            my $contigname = $headeritem[0];
            $contigname =~ s/^(\s+|\s+$)//g;
            $contig->setContigName($contigname);
# and reset sequence
            $sequence = '';
            $length = 0;
	}

# parse a feature, e.g. tag

        elsif ($record =~ /^FT\s+(.*)$/) {
            my $info = $1;
            if ($info =~ /($tagdescriptors)\s+(\d+)[\.\>\<]+(\d+)/) {
# new tag with one position started
                my ($type,$ts,$tf) = ($1,$2,$3);
		$type = $translation{$type} || $type;
#                $type = 'FCDS' if ($type eq 'CDS'); # FCDS recognised by Gap4
                my $contigtag = TagFactory->makeContigTag($type,$ts,$tf);
                $contigtag->setStrand('Forward');
                push @contigtag,$contigtag;
                $parsetag = 1;
            }
            elsif ($info =~ /($tagdescriptors)\s+join\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
		$type = $translation{$type} || $type;
                my $contigtag = TagFactory->makeContigTag($type);
                $contigtag->setStrand('Forward');
                my @positions = split ',',$joinstring;
                foreach my $position (@positions) {
                    my ($ts,$tf) = split /\.+/,$position;
                    $contigtag->setPosition($ts,$tf,join=>1);
		}
                push @contigtag,$contigtag;
                $parsetag = 1;
 	    }
            elsif ($info =~ /($tagdescriptors)\s+complement\(join\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
		$type = $translation{$type} || $type;
                my $contigtag = TagFactory->makeContigTag($type);
                $contigtag->setStrand('Reverse');
#                $contigtag->setTagComment('(Reverse Strand)');
                my @positions = split ',',$joinstring;
                foreach my $position (@positions) {
                    my ($ts,$tf) = split /\.+/,$position;
                    $contigtag->setPosition($ts,$tf,join=>1);
		}
                push @contigtag,$contigtag;
                $parsetag = 1;
 	    }
            elsif ($info =~ /($tagdescriptors)\s+complement\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
		$type = $translation{$type} || $type;
                my $contigtag = TagFactory->makeContigTag($type);
                $contigtag->setStrand('Reverse');
#                $contigtag->setTagComment('(Reverse Strand)');
                my @positions = split ',',$joinstring;
                foreach my $position (@positions) {
                    my ($ts,$tf) = split /\.+/,$position;
                    $contigtag->setPosition($ts,$tf,join=>1);
		}
                push @contigtag,$contigtag;
                $parsetag = 1;
 	    }
# if parsetag flag not on, we are outside a tag
            if ($parsetag && @contigtag) {
                my $contigtag = $contigtag[$#contigtag]; # most recent addition
# replace this by a simple adding to an array; only pick up systematic ID
	      if (0) {

                if ($info =~ /\bsystematic_id\b\=\"(.+)\"/) {
                    $contigtag->setSystematicID($1);
		}
		my $tagcomment = $contigtag->getTagComment();
                $tagcomment = [] unless defined $tagcomment;
                if (ref($tagcomment) eq 'ARRAY') {
                    push @$tagcomment,$info; # as is
                    $contigtag->setTagComment($tagcomment);
                } # else ignore                

	      }
	      else {
                my $tagcomment = $contigtag->getTagComment() || '';
                if ($info =~ /(note|ortholog|systematic)/) {
                    my $kind = $1;
                    unless ($tagcomment =~ /$kind/) { 
                        $info =~ s/(^\s*|\s*$|\/)//g;
                        $tagcomment .= '\\n\\' if $tagcomment;
	       	        $tagcomment .= $info;
   		        $contigtag->setTagComment($tagcomment);
                        if ($info =~ /\bsystematic_id\b\=\"(.+)\"/) {
                            $contigtag->setSystematicID($1);
		        }
                        if ($info =~ /\bnote\b\=\"(.+)\"/) {
#                            $contigtag->setComment($1);
		        }
		    }
                }
              }  
            }
# else other info is to be parsed
            else {
# to be developed
		$logger->warning("not parsed: $info");
	    }
        }

# parse the sequence  data

        elsif ($record =~ /^SQ\s*(.*)$/) {
            my $sequencedata = $1;
            my @sequencedata = split ';',$sequencedata;
            $checksum = $sequencedata[0];
            $checksum =~ s/\D+(\d+)\D+/$1/;
	}

        elsif ($record =~ /^([actgn\s]+)(\d+)\s*$/) {
# DNA record
            my $string = $1;
            my $number = $2;
            $string =~ s/\s+//g;
            $sequence .= $string;
            $length += length($string);
	}

        elsif ($record =~ /[actg]/) {
            $logger->severe("Ignore data in DNA block: \n$record") if $length;
            $logger->debug("Ignore data: $record");
	}
	else {
            $logger->debug("Ignore data: $record");
	}
    }

# add the last one to the stack

    if (!$contig && ($sequence || @contigtag)) {
# create a default contig (the ID line was missing, Artemis output!)
        my $contigname = $emblfile;
	$contigname =~ s/\.embl//;
        $contig = new Contig($contigname);      
    }

    if ($contig && ($sequence || @contigtag)) {
        $logger->info("contig & sequence assembled : $length ($checksum)");
        unless ($length == $checksum) {
	    $logger->error("Checksum error ($checksum - $length) on embl file "
                           .$contig->getContigName());
     	}
        $contig->setSequence($sequence);

        $contig->addTag(\@contigtag) if @contigtag;

        push @$emblcontigs, $contig;
    }

    $EMBL->close();

    return $emblcontigs;
}

#-----------------------------------------------------------------------------
# building Contigs from CAF file using an inventory
#-----------------------------------------------------------------------------

my $INVENTORY; # class variable

#------------- building an inventory of contigs and reads --------------------

sub cafFileInventory {
# build an inventory of objects in the CAF file
    my $class = shift;
    my $caffile = shift; # caf file name or 0 
    my %options = @_;

    my $logger = &verifyLogger('cafFileInventory');

# options

    my $progress  = $options{progress};       # report on progress
    my $linelimit = $options{linelimit} || 0; # test option, parse this nr of lines

# register file positions of keywords Sequence, DNA, BaseQuality

    my $CAF = new FileHandle($caffile,"r");

    unless ($CAF) {
	$logger->error("Invalid CAF file specification $caffile");
        return undef;
    }

# report summary

    my $filesize;
    if ($progress) {
# get number of lines in the file
        $logger->warning("Building inventory for CAF file $caffile");
        my $counts = `wc $caffile`;
        $counts =~ s/^\s+|\s+$//g;
        my @counts = split /\s+/,$counts;
        $progress = int ($counts[0]/20);
        $filesize = $counts[0];
        $logger->warning("$caffile is a $counts[2] byte file with $counts[0] lines");
    }

# MAIN

    my $inventory = {};
    $inventory->{caffilename} = $caffile;

    my $datatype;
    my $identifier;
    my $linecount = 0;
    my $location = tell($CAF);

    my $contigcounter = 0;
    while (defined(my $record = <$CAF>)) {
        $linecount++;
        if ($progress && !($linecount%$progress)) {
            my $objectcount = scalar(keys %$inventory);
            my $fraction = sprintf ("%5.2f", $linecount/$filesize);           
            $logger->error("$fraction completed ... $objectcount objects",bs => 1);
	}
        last if ($linelimit && $linecount >= $linelimit);
        chomp $record;
# decode the record info
        if ($record !~ /\S/) {
# blank line indicates end of current object
            undef $identifier;
	}
# the identifier records must contain a ':'
        elsif ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:\s*(\S+)/) {
# check that identifier is undefined
            if ($identifier) {
                $logger->error("l:$linecount Missing blank after previous object");
            }
            $datatype = $1;
            $identifier = $2;
# ok, store the file position keyed on identifier/datatype
            $inventory->{$identifier} = {} unless defined $inventory->{$identifier};
            if ($inventory->{$identifier}->{$datatype}) {
                $logger->error("l:$linecount Multiple $datatype entry for $identifier");
	    }
            my @filelocation = ($location,$linecount);
            $inventory->{$identifier}->{$datatype} = \@filelocation;
        }
        elsif ($record =~ /(Is_(read|contig|assembly))\b/) {
            my $objecttype = $2;
# check if this is inside a valid block on the file
            if ($identifier && $datatype && $datatype eq 'Sequence') {
                $inventory->{$identifier}->{Is} = $objecttype;
                if ($objecttype eq 'contig') {
                    $inventory->{$identifier}->{Rank} = ++$contigcounter;
                }
	    }
	    elsif ($identifier) {
		$logger->error("l:$linecount Unexpected $objecttype specification");
	    }
        }
        elsif ($record =~ /Ass\w+from\s+(\S+)\s/) {
# collect list of readnames, count assembled from segments
#            my $readname = $1;
            my $objecttype = $inventory->{$identifier}->{Is};
            my $errormsg = "Unexpected 'Assembled_from' specification";
            if ($identifier && $datatype && $datatype eq 'Sequence') {
# test for correct object
                if ($objecttype eq "contig") {
                    $inventory->{$identifier}->{segments}++;
                }
                elsif ($objecttype) {
	   	    $logger->error("l:$linecount $errormsg in $objecttype object");
		}
		else {
	   	    $logger->error("l:$linecount $errormsg in undefined object");
		}
	    }
	    elsif ($identifier) {
		$logger->error("l:$linecount $errormsg outside Sequence object");
	    }
        }        
        $location = tell($CAF);
    }

    $CAF->close() if $CAF;

    $class->{inventory} = $inventory if ref($class); # store on instance hash

    $INVENTORY = $inventory unless ref($class);      # store on class variable

    return $inventory;
}

sub getInventory {
    my $class = shift;

    return $class->{inventory} if ref($class); # called on an instance

    return $INVENTORY if (ref($INVENTORY) eq 'HASH');

# there is no valid inventory

    my $logger = verifyLogger('getInventory');
    $logger->error("*** missing inventory ***");
    return undef;
}
    
my %headers = (Sequence=>'SQ',DNA=>'DNA',BaseQuality=>'BQ',segments=>'Segs');

sub listInventoryForObject {
# returns a list of inventory items for the give object name
    my $class = shift;
    my $objectname = shift;

    my $inventory = &getInventory($class);

    my $report = sprintf ("%24s",$objectname);
    my $objectdata = $inventory->{$objectname} || return $report." no data";
    foreach my $type ('Sequence', 'DNA', 'BaseQuality','segments') {
        next unless defined $objectdata->{$type};
        my $data = $objectdata->{$type};
        $data = $data->[0] if (ref($data) eq 'ARRAY');
        $report .= " ".sprintf("%5s",$headers{$type})." ".sprintf("%12d",$data);
    }
    return $report;
}

sub removeObjectFromInventory {
# remove a list of objects from the inventory
    my $class = shift;
    my $objectnames = shift; # array reference

    &verifyParameter($objectnames,'removeObjectFromInventory','ARRAY');

    my $inventory = &getInventory($class) || return;

    foreach my $objectname (@$objectnames) {
        delete $inventory->{$objectname};
    }
}

#------------- building Contig and Read instances from the caf file --------------
    
my %components = (Sequence => 0 , DNA => 1 , BaseQuality => 2); # class constants

 sub assemblyExtractor {
     my $class = shift;
     my $assemblyname = shift;

     my $logger = &verifyLogger('assemblyExtractor');

     my $inventory = &getInventory($class);

# TO BE DEVELOPED
 }


sub contigExtractor {
    my $class = shift;
    my $contignames = shift; # array with contigs to be extracted
    my $readversionhash = shift;
    my %options = @_; 

# options : contignamefilter, usepadded, consensus, contigtaglist, ignoretaglist
#           readtaglist, noreadsequence, noreads

    &verifyParameter($contignames,'contigExtractor','ARRAY');

    my $logger = &verifyLogger('contigExtractor');

    my $inventory = &getInventory($class);

# -------------- options processing (used in this module)

    my $consensus  = $options{consensus};        # include consensus, default not
    my $namefilter = $options{contignamefilter}; # select specific contigs

# default DNA and BaseQuality only added for edited reads

    my $noreads    = $options{noreads} || 0;

# -------------- options processing (passed on to sub-modules)

# tag-related: test options, replace if processed or put default values 

    my $contigtaglist = $options{contigtaglist};
    $contigtaglist =~ s/\W/|/g if ($contigtaglist && $contigtaglist !~ /\\/);
    $contigtaglist = '\w{3,4}' unless $contigtaglist; # default
    $options{contigtaglist} = $contigtaglist;

    my $ignoretaglist = $options{ignoretaglist};
    $ignoretaglist =~ s/\W/|/g if ($ignoretaglist && $ignoretaglist !~ /\\/);
    $options{ignoretaglist} = $ignoretaglist if $ignoretaglist;

    $options{usepadded} = 0 unless defined $options{usepadded};

# --------------- get caf file from inventory hash

    my $CAF = &getFileHandle($inventory);

#    my $caffile = $inventory->{caffilename};
#    my $CAF = new FileHandle($caffile,"r");

#    unless ($CAF) {
#	$logger->error("Invalid CAF file specification $caffile");
#        return undef;
#    }

# --------------- main

# initiate output list; use hash to filter out double entries

    my %contigs;

# build a table, sorted according to file position, of contig data to be collected

    my @contigstack;
    my @contigitems = ('Sequence');
    push @contigitems,'DNA','BaseQuality' if $consensus;

    foreach my $contigname (@$contignames) {
        next if ($namefilter && $contigname !~ /$namefilter/);
        my $cinventory = $inventory->{$contigname};
        unless ($cinventory) {
	    $logger->error("Missing contig $contigname");
	    next;
	}
        next if $contigs{$contigname}; # duplicate entry
        my $contig = new Contig($contigname);
        $contig->setDataSource($class);
        $contigs{$contigname} = $contig; # add to output stack
        foreach my $item (@contigitems) {
            my $itemlocation = $cinventory->{$item};
            next unless $itemlocation;
            push @contigstack,[($contig,$components{$item},@$itemlocation)];
	}
    }

# run through each contig in turn and collect dna & quality data and read names

    my @reads;

    my ($status,$line);
    foreach my $stack (sort {$a->[2] <=> $b->[2]} @contigstack) {
        my ($contig,$type,$fileposition,$line) = @$stack;
        seek $CAF, $fileposition, 00; # position the file 
        if ($type == 0) {
           ($status,$line) = &parseContig      ($CAF,$contig,$line,%options);
        }
        elsif ($type == 1) {
           ($status,$line) = &parseDNA         ($CAF,$contig,$line);
        }
        elsif ($type == 2) {
           ($status,$line) = &parseBaseQuality ($CAF,$contig,$line);
        }

        next if $type;
# and collect the readnames in this contig
        my $reads = $contig->getReads();
        unless ($reads && @$reads) {
	    $logger->error("contig ". $contig->getContigName()
                          ." has no reads specified");
            next;
	}

        next if $noreads;

        push @reads,@$reads;
    }

    my @contigs;
    foreach my $contigname (sort keys %contigs) {
        push @contigs, $contigs{$contigname};
    }

    return \@contigs unless @reads;

# extract the reads

    my %roptions;
    foreach my $key ('readtaglist','ignoretaglist','nosequence') {
        $roptions{$key} = $options{$key} if $options{$key};
    }
    my $result = $class->readExtractor(\@reads,$readversionhash,%roptions);

    return \@contigs;
}

sub readExtractor {
# return a list of Read instances 
    my $class = shift;
    my $reads = shift;  # array with Reads or readnames to be extracted
    my $readversionhash = shift; # may be 0 or undefined
    my %options = @_; # readtaglist, edittaglist, fullreadscan, noreadsequence

# if no readversion hash is provided, the Reads have DNA and BQ data
# if  a readversion hash is specified, those reads that match have DNA and BQ
# removed and have the sequence ID set (unless the nosequence option is used)

    &verifyParameter($reads,'readExtractor','ARRAY');
 
    my $logger = &verifyLogger('readExtractor');

    my $readtaglist = $options{readtaglist};
    $readtaglist =~ s/\W/|/g if ($readtaglist && $readtaglist !~ /\\/);
    $readtaglist = '\w{3,4}' unless $readtaglist; # default
    $options{readtaglist} = $readtaglist;
 
    my $edittaglist = $options{edittaglist};
    $edittaglist =~ s/\W/|/g if ($edittaglist && $edittaglist !~ /\\/);
    $options{edittaglist} = $edittaglist if $edittaglist;

    $options{fullreadscan}   = 0 unless defined $options{fullreadscan};
    $options{noreadsequence} = 0 unless defined $options{noreadsequence};

# --------------------- get caf file from inventory hash --------------------

    my $inventory = &getInventory($class);

    unless ($inventory) {
# pick up the cached hash, if this method not called on the class itself 
        $inventory = $class->{inventory} if (ref($class) eq 'HASH');
# and check
        unless ($inventory) {
            $logger->error("Missing CAF file inventory");
            return undef;
	}
    }   

    my $CAF = &getFileHandle($inventory) || return undef;

#------- if input is a list of names, replace by list of Read objects -------

    my @reads;
    foreach my $read (@$reads) {
        push @reads, $read           if (ref($read) eq 'Read');
        push @reads, new Read($read) if (ref($read) ne 'Read'); # readname
    }
# if readnames replaced by read objects: assign new output array
    $reads = \@reads if @reads;

#--------------------------------- main -------------------------------------

    my @readstack;
    my @readitems =('Sequence');
    push @readitems,'DNA','BaseQuality' unless $options{noreadsequence};

    my $extractedreads = []; # actually extracted 
    foreach my $read (@reads) {
        my $readname = $read->getReadName();
        my $rinventory = $inventory->{$readname};
        unless ($rinventory) {
            $logger->error("Missing read $readname NOT found in inventory");
            next;
        }
        push @$extractedreads,$read;
        foreach my $item (@readitems) {
            my $itemlocation = $rinventory->{$item};
            next unless $itemlocation;
            push @readstack,[($read,$components{$item},@$itemlocation)];
	}
    }        

# and collect all the required read items

    foreach my $stack (sort {$a->[2] <=> $b->[2]} @readstack) {
        my $status = 0;
        my ($read,$type,$fileposition,$line) = @$stack;
        seek $CAF, $fileposition, 00; # position the file 
        if ($type == 0) {
           ($status,$line) = &parseRead        ($CAF,$read,$line,%options);
        }
	elsif ($type == 1) {
           ($status,$line) = &parseDNA         ($CAF,$read,$line);
        }
        elsif ($type == 2) {
	   ($status,$line) = &parseBaseQuality ($CAF,$read,$line);
        }
        unless ($status) {
            my $readname = $read->getReadName();
	    $logger->error("Failed to extract data for read $readname");
	    next;
	}
# test if sequence data have to be removed
        next unless $readversionhash;
        next unless $read->hasSequence();
# get the data from the hash for this read
        my $readname = $read->getReadName();
        if (my $versionhashlist = $readversionhash->{$readname}) {
            my $seq_hash = $read->getSequenceHash();
            my $bql_hash = $read->getBaseQualityHash();
	    my $version = 0;
	    for (my $version=0 ; $version < @$versionhashlist ; $version++) {
                my $versionhash = $versionhashlist->[$version];
                next unless ($seq_hash eq $versionhash->{seq_hash});
                next unless ($bql_hash eq $versionhash->{qual_hash});
# both hashes match: this read version is in the database
                $read->setReadID($versionhash->{read_id});
                $read->setSequenceID($versionhash->{seq_id});
                $read->setVersion($version);
$logger->fine("version $version identified for read $readname");
# remove sequence data
                $read->setSequence(undef);    
                $read->setBaseQuality(undef);
	    }
	}       
    }

    return $extractedreads;
}


sub extractContig {
# public, extract a named contig 
    my $class = shift;
    my $contigname = shift;

    my $contigs = $class->contigExtractor([($contigname)],@_); # port options

    return $contigs->[0] if $contigs->[0];

    return undef;
}

sub extractRead {
# public, extract a named read
    my $class = shift;
    my $readname = shift;
    my %options = @_;

    $options{fullreadscan} = 1 unless defined $options{fullreadscan};

    my $reads = $class->readExtractor([($readname)],%options);

    return $reads->[0] if $reads->[0];

    return undef;
}

# several methods to be developed using delayed loading techniques TO BE TESTED

sub getSequenceAndBaseQualityForContig {
# delayed loading of seuence data for contig
    my $class = shift;
    my $contig = shift;

    &verifyParameter($contig,'getSequenceAndBaseQualityForContig');

    my $inventory = &getInventory($class) || return undef;

    return &getSequenceForObject($contig,$inventory);
}

sub getSequenceForRead {
# to be developed: delayed loading of read sequence
    my $class = shift;
    my $read  = shift;

    &verifyParameter($read,'getSequenceForRead','Read');

    my $inventory = &getInventory($class) || return undef;

    return &getSequenceForObject($read,$inventory);
}

sub getSequenceForObject {
# private
    my $object = shift;
    my $inventory = shift;

    &verifyPrivate($object,"getSequenceForObject");

# return DNA and BQ

    my $CAF = &getFileHandle($inventory);

    my $objectname = $object->getName();
    my $objectinventory = $inventory->{$objectname};

# TO BE DEVELOPED

    foreach my $item ('DNA','BaseQuality') {
        my $positions = $objectinventory->{$item};
        unless ($positions) {
            my $logger = &verifyLogger("getSequenceForObject");
	    $logger->debug("No $item available for object $objectname");
	    next;
	}
        my ($fileposition,$line) = @$positions;
        seek $CAF, $fileposition, 00; # position the file 
        my $status;
	if ($item eq 'DNA') {
           ($status,$line) = &parseDNA         ($CAF,$object,$line);
        }
        else {
           ($status,$line) = &parseBaseQuality ($CAF,$object,$line);
        }
        next if $status;
        my $logger = &verifyLogger("getSequenceForObject");
        $logger->error("Failed to extract $item data for object $objectname");
    }    
}

sub getFileHandle {
# private : auto generate file handle
    my $inventory = shift;

    &verifyPrivate($inventory,"getFileHandle");

    my $filehandle = $inventory->{filehandle};

    unless ($filehandle) {
        my $caffile = $inventory->{caffilename};
        $filehandle = new FileHandle($caffile,"r");
        unless ($filehandle) {
            my $logger = &verifyLogger("getSequenceForObject");
            $logger->error("Invalid CAF file specification $caffile");
            return undef;
        }
        $inventory->{filehandle} = $filehandle;
    } 

    return $filehandle;
}

sub closeFileHandle {
# auto generate file handle
    my $inventory = shift;
   
    my $filehandle = $inventory->{filehandle} || return undef;

    delete $inventory->{filehandle};

    $filehandle->close();
}

#------------------------------------------------------------------------------
# sequencial caf file parser (small files)
#------------------------------------------------------------------------------

sub cafFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $caffile = shift; # caf file name or 0 
    my %options = @_;

# open logfile handle for output

    my $logger = &verifyLogger('cafFileParser');

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
	$logger->severe("Invalid CAF file specification $caffile");
        return undef;
    }

#-----------------------------------------------------------------------------
# collect options   
#-----------------------------------------------------------------------------

    my $lineLimit = $options{linelimit}    || 0; # test purposes
    my $progress  = $options{progress}     || 0; # true or false progress (on STDERR)
    my $usePadded = $options{acceptpadded} || 0; # true or false allow padded contigs
    my $consensus = $options{consensus}    || 0; # true or false build consensus

    my $readlimit = $options{readlimit};

my $lowMemory = $options{lowmemory}    || 0; # true or false minimise memory

# object name filters

    my $contignamefilter = $options{contignamefilter} || ''; 
my $readnamefilter   = $options{readnamefilter}  || ''; # test purposes

    my $blockobject = $options{blockobject};
    $blockobject = {} if (ref($blockobject) ne 'HASH');

# set-up tag selection

    my $readtaglist = $options{readtaglist};
    $readtaglist =~ s/\W/|/g if ($readtaglist && $readtaglist !~ /\\/);
    $readtaglist = '\w{3,4}' unless $readtaglist; # default
    $logger->fine("Read tags to be processed: $readtaglist");
$logger->warning("Read tags to be processed: $readtaglist");

    my $contigtaglist = $options{contigtaglist};
    $contigtaglist =~ s/\W/|/g if ($contigtaglist && $contigtaglist !~ /\\/);
    $contigtaglist = '\w{3,4}' unless $contigtaglist; # default
    $logger->info("Contig tags to be processed: $contigtaglist");
$logger->warning("Contig tags to be processed: $contigtaglist");

    my $ignoretaglist = $options{ingoretaglist};

    my $edittags = $options{edittags} || 'EDIT';

#----------------------------------------------------------------------
# allocate basic objects and object counters
#----------------------------------------------------------------------

    my ($read, $mapping, $contig);

    my (%contigs, %reads, %mappings);

# control switches

    my $lineCount = 0;
    my $listCount = 0;
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

    $logger->info("Parsing CAF file $caffile");

    $logger->info("Read a maximum of $lineLimit lines") if $lineLimit;

    $logger->info("Contig (or alias) name filter $contignamefilter") if $contignamefilter;

    while (defined(my $record = <$CAF>)) {

#-------------------------------------------------------------------------
# line count processing: report progress and/or test line limit
#-------------------------------------------------------------------------

        $lineCount++;
#        if ($progress && !($lineCount%$progress)) {
        if ($progress && ($lineCount >= $listCount)) {
            my $fraction = sprintf ("%5.2f", $lineCount/$fileSize);         
            $logger->error("$fraction completed .....",bs=>1);
            $listCount += $progress;
	}

# deal with (possible) line limit

        if ($lineLimit && ($lineCount > $lineLimit)) {
            $logger->warning("Scanning terminated because of line limit $lineLimit");
            $truncated = 1;
            $lineCount--;
            last;
        }

# skip empty records

        chomp $record;
        next if ($record !~ /\S/);

# extend the record if it ends in a continuation mark

        my $extend;
        while ($record =~ /\\n\\\s*$/) {
            if (defined($extend = <$CAF>)) {
                chomp $extend;
                $record .= $extend;
                $lineCount++;
            }
            else {
                $record .= '"' if ($record =~ /\"/); # closing quote
            }
        }

#--------------------------------------------------------------------------
# checking padded/unpadded status and its consistence
#--------------------------------------------------------------------------

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

        if ($record =~ /^\s*(DNA|BaseQuality)\s*\:?\s*(\S+)/) {
# a new data block is detected
            my $newObjectType = $1;
            my $newObjectName = $2;
# close the previous object, if there is one
            if ($objectType == 2) {
                $logger->fine("END scanning Contig $objectName");
                if ($readlimit && scalar(keys %reads) >= $readlimit) {
                    $truncated = 1;
                    last;
                }
            }
            $objectType = 0; # preset
            my $objectInstance;
            if ($newObjectName =~ /(\s|^)Contig/) {
# it's a contig; decide if the new object has to be built
                next unless $consensus;
                next if $blockobject->{$newObjectName};
                unless ($objectInstance = $contigs{$newObjectName}) {
                    $objectInstance = new Contig($newObjectName);
                    $contigs{$newObjectName} = $objectInstance;
		}
            }
	    else {
# the new data relate to a read
                next if $blockobject->{$newObjectName};
                unless ($objectInstance = $reads{$newObjectName}) {
                    $objectInstance = new Read($newObjectName);
                    $reads{$newObjectName} = $objectInstance;
		}
	    }
# now read the file to the next blank line and accumulate the sequence or quality 

            my ($status,$line);
            if ($newObjectType eq 'DNA') {
  	       ($status,$line) = &parseDNA($CAF,$objectInstance,$lineCount,noverify=>1);
	    }
            elsif ($newObjectType eq 'BaseQuality') {
  	       ($status,$line) = &parseBaseQuality($CAF,$objectInstance,$lineCount,noverify=>1);
	    }
            $lineCount = $line if $status;
            $objectType = 0;
            next;
	}

        if ($record =~ /^\s*Sequence\s*\:?\s*(\S+)/) {
# a new object is detected
            my $objectName = $1;
# close the previous object, if there is one
#          closeContig($objectName);
            if ($objectType == 2) {
                $logger->fine("END scanning Contig $objectName");
            }
            $objectType = 0; # preset

            if ($objectName =~ /Contig/) {
# it's a contig; decide if the new object has to be built
                if ($blockobject->{$objectName}) {
                    $objectType = -2; # forced discarding read objects
                    if ($readlimit && scalar(keys %reads) >= $readlimit) {
                        $truncated = 1;
                        last;
                    }
                    next;
                }
                unless ($contig = $contigs{$objectName}) {
                    $contig = new Contig($objectName);
                    $contigs{$objectName} = $contig;
		}
                $objectType = 2; # activate processing contig data 

		my $readhashref = \%reads;
                my $contig = $contigs{$objectName};
                my ($status,$line) = &parseContig($CAF,$contig,$lineCount,
                                                  readhashref=>$readhashref,
                                                  noverify=>1);
                $lineCount = $line if $status;
		$objectType = 0;
                next;
            }
	    else {
# the new data relate to a read
                next if $blockobject->{$objectName};
                unless ($read = $reads{$objectName}) {
                    $read = new Read($objectName);
                    $reads{$objectName} = $read;
		}
                $objectType = 1; # activate processing read data

                my ($status,$line) = &parseRead($CAF,$read,$lineCount,noverify=>1);
                $lineCount = $line if $status;
		$objectType = 0;
                next;
	    }
	}

# REMOVE from HERE ?
    my $IGNORETHIS = 0; unless ($IGNORETHIS) {
        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:?\s*(\S+)/) {
#print STDERR "IGNORETHIS block used  ... \n";
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
#                    $objectType = 0 if $cnBlocker->{$objectName};
                }
# for read we reject if it is already known that there are no edits
                elsif ($read = $reads{$objectName}) {
# we consider an existing read only if the number of SCF-alignments is NOT 1
	            my $align = $read->getAlignToTrace();
                    if ($isUnpadded && $align && scalar(@$align) == 1) {
#                        $objectType = 0;
		    }
#	         my $aligntotracemapping = $read->getAlignToTraceMapping();
#                $objectType = 0 if ($isUnpadded && $aligntotracemapping
#                                && ($aligntotracemapping->hasSegments() == 1));
                }
# for DNA and Quality 
                elsif ($blockobject->{$objectName}) {
                    $objectType = 0;
	        }
            }
            next;
        }
    } # end IGNORETHIS
#remove up to HERE

       
# the next block handles a special case where 'Is_contig' is defined after 'assembled'

        if ($objectName =~ /contig/i && $record =~ /assemble/i 
                                     && abs($objectType) != 2) {
# decide if this contig is to be included
            my $include = 1;
            $include = 0 if ($contignamefilter && $objectName =~ /$contignamefilter/);
            $include = 0 if ($blockobject && $blockobject->{$objectName});
            if ($include) {
#        if ($contignamefilter !~ /\S/ || $objectName =~ /$contignamefilter/) {
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
            if ($contignamefilter !~ /\S/ || $objectName =~ /$contignamefilter/) {
                $logger->fine("NEW contig $objectName: ($lineCount)");
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
        }

# standard read initiation

        elsif ($record =~ /Is_read/) {
# decide if this read is to be included
            if ($blockobject->{$objectName}) {
# no, don't want it; does the read already exist?
                $read = $reads{$objectName};
                if ($read && $lowMemory) {
                    delete $reads{$objectName};
                } 
                $objectType = 0;
            }
            else {
                $logger->finest("NEW Read $objectName: ($lineCount) $record");
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
            $logger->error("scan $objectName ($objectType) SHOULD NOT occur $lineCount");
# TO BE DEPRECATED
            my ($status,$line) = &parseRead($CAF,$read,$lineCount,noverify=>1);
            $lineCount = $line if $status;
            $objectType = 0;
            next;
	 
# UNTIL HERE
        }

        elsif ($objectType == 2) {
# parsing a contig, get constituent reads and mapping
            $logger->error("scan $objectName ($objectType) SHOULD NOT occur $lineCount");
# TO BE DEPRECATED
            my $contig = $contigs{$objectName};
            my ($status,$line) = &parseContig($CAF,$contig,$lineCount,noverify=>1);
            $lineCount = $line if $status;
	    $objectType = 0;
            next;
# UNTIL HERE
        }

        elsif ($objectType == -2) {
# processing a contig which has to be ignored: inhibit its reads to save memory
            if ($record =~ /Ass\w+from\s(\S+)\s(.*)$/) {
                $blockobject->{$1}++; # add read in this contig to the block list
                $logger->finest("read $1 blocked") unless (keys %$blockobject)%100;
# remove existing Read instance
                $read = $reads{$1};
                if ($read && $lowMemory) {
                    delete $reads{$1};
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
$logger->warning("$lineCount lines processed of CAF file $caffile");

    my $nc = scalar (keys %contigs);
    my $nm = scalar (keys %mappings);
    my $nr = scalar (keys %reads);

    $logger->info("$nc Contigs, $nm Mappings, $nr Reads built");

# return array references for contigs and reads 

    return \%contigs,\%reads,$truncated if $options{oldcontigloader};

# bundle all objects in one array
$logger->warning("bundling ....");

    my $er = 0;
    my $objects = [];
    foreach my $key (keys %contigs) {
        my $contig = $contigs{$key};
        push @$objects, $contig;
        my $creads = $contig->getReads();
# remove the reads in this contig from the overall read list
        foreach my $read (@$creads) {
            delete $reads{$read->getReadName()};
            $er++ if $read->isEdited();
        }
    }

    $logger->info("$er Edited Reads found");

#add any remaining reads, if any, to output object list

    my $reads = [];
    foreach my $key (keys %reads) {
        push @$objects, $reads{$key};
    }

    $nr = scalar @$reads;

    my $no = scalar @$objects;

    $logger->info("$no Objects; $nr Reads (unassembled)");
$logger->warning("$no Objects; $nr Reads (unassembled)");

    return $objects,$truncated;
}

sub parseDNA {
# read DNA block from the file handle; the file must be positioned at the right
# position before invoking this method: either before the line with DNA keyword
# or at the start of the actual data block
    my $CAF  = shift;
    my $object = shift; # Read or Contig
    my $line = shift; # starting line in the file (re: error reporting)
    my %options = @_; # noverify=> ,

    &verifyPrivate($CAF,'parseDNA');

    my $logger = &verifyLogger('parseDNA');

# test if it is indeed the start of a DNA block

    my $record;

    unless ($options{noverify}) {

# test for the line with DNA keyword; cross check the object name

        $record = <$CAF>;
        chomp $record;

        if ($record =~ /^\s*DNA\s*\:?\s*(\S+)/) {
            my $objectname = $1;
            my $name = $object->getName();
            if ($name && $objectname ne $name) {
                $logger->severe("Incompatible object names ($line: $name $objectname)");
                return 0;
            }
            elsif (!$name) {
                $object->setName($objectname);
            }
	}
        else {
            $logger->severe("Position error on CAF file ($line: $record)");
            return 0;
        }
    }

    $logger->fine("Building DNA for ".$object->getName());

# read the data block
    
    my $sequencedata = '';
    while (defined($record = <$CAF>)) {
        $line++;
        chomp $record;
        last unless ($record =~ /\S/); # blank line
        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:/) {
            $logger->error("Missing blank after DNA block ($line)");
	    last;
	}
        $sequencedata .= $record;
    }

# add the DNA to the object provided

    if ($sequencedata) {
        $sequencedata =~ s/\s+//g; # remove all blank space
        $object->setSequence($sequencedata);
    }
    else {
        $logger->warning("$line: empty DNA block detected for ".$object->getName());
    }

    return 1,$line;
}

sub parseBaseQuality {
# read BaseQuality block from the file handle; the file must be positioned at the
# correct position before invoking this method: either before the line with BaseQuality
# keyword or at the start of the actual data block
    my $CAF  = shift;
    my $object = shift; # Read or Contig
    my $line = shift; # starting line in the file (re: error reporting)
    my %options = @_; # noverify=> ,

    &verifyPrivate($CAF,'parseBaseQuality');

    my $logger = &verifyLogger('parseBaseQuality');

# test if it is indeed the start of a base quality block

    my $record;

    unless ($options{noverify}) {

# test for the line with DNA keyword; cross check the object name

        $record = <$CAF>;
        chomp $record;
        $line++;

        if ($record =~ /^\s*BaseQuality\s*\:?\s*(\S+)/) {
            my $objectname = $1;
            my $name = $object->getName();
            if ($name && $objectname ne $name) {
                $logger->severe("Incompatible object names ($line: $name $objectname)");
                return 0,$line;
            }
            elsif (!$name) {
                $object->setName($objectname);
            }
	}
        else {
            $logger->severe("Position error on CAF file ($line: $record)");
            return 0,$line;
        }
    }

    $logger->fine("Building Base Quality for ".$object->getName());

# read the data block
    
    my $qualitydata = '';
    while (defined($record = <$CAF>)) {
        $line++;
        chomp $record;
        last unless ($record =~ /\S/); # blank line
        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:/) {
            $logger->error("Missing blank after DNA block ($line)");
	    last;
	}
        $qualitydata .= $record.' '; # just in case
    }

# add the BaseQuality to the object provided

    if ($qualitydata) {
        $qualitydata =~ s/^\s+|\s+$//g; # remove leading/trailing
        my @BaseQuality = split /\s+/,$qualitydata;
        $object->setBaseQuality (\@BaseQuality);
   }
    else {
        $logger->warning("$line: empty Base Quality block detected for ".$object->getName());
    }

    return 1,$line;
}

sub parseContig {
# read Read data block from the file handle; the file must be positioned at 
# the correct position before invoking this method: either before the line
# with Sequence keyword or at the start of the actual data block
    my $CAF  = shift;
    my $contig = shift; # Contig instance with contigname defined
    my $fline = shift; # starting line in the file (re: error reporting)
    my %options = @_;

    &verifyPrivate($CAF,'parseContig');

    my $logger = &verifyLogger('parseContig');

# options: if taglist specified only those tags will be picked up, with info on other
#          tags skipped; if no readtaglist specified all tags will be processed


    my $contigtags = $options{contigtaglist} || '\w{3,4}'; # default any tag
    my $ignoretags = $options{ignoretaglist} || '';

    my $usepadded = $options{usepadded} || 0;

# test if it is indeed the start of a sequence block

    my $record;
    my $contigname;

    unless ($options{noverify}) {

# test for the line with DNA keyword; cross check the object name

        $record = <$CAF>;
        chomp $record;
	my $line = $fline;
        $fline++;

        if ($record =~ /^\s*Sequence\s*\:?\s*(\S+)/) {
            $contigname = $1;
            my $name = $contig->getContigName();
            if ($name && $contigname ne $name) {
                $logger->severe("l:$line Incompatible object names ($name $contigname)");
                return 0,$line;
            }
            elsif (!$name) {
                $contig->setContigName($contigname);
            }
            $logger->fine("l:$line Opening record verified: $record");
	}
        else {
            $logger->severe("Position error on CAF file ($line: $record)");
            return 0,$line;
        }
    }

    $contigname = $contig->getContigName() unless $contigname;

# parse the file until the next blank record

    my $readobjecthash = $options{readhashref};

    my $isUnpadded = 1;
    my $readnamehash = {};
    while (defined($record = <$CAF>)) {
        $fline++;
        chomp $record;
# add subsequent lines if continuation mark '\n\' present
        while ($record =~ /\\n\\\s*$/) {
            my $extension;
            if (defined($extension = <$CAF>)) {
                chomp $extension;
                $record .= $extension;
#                $record =~ s/\\n\\\s*\"/\"/; # replace continuation & closing quote
                $fline++;
            }
            elsif ($record !~ /\"\s*$/) {
# end of file encountered: complete continued record
                $record .= '"' if ($record =~ /\"/); # closing quote
            }
        }
        $record =~ s/\\n\\\s*\"/\"/; # replace continuation & closing quote
# check presence and compatibility of keywords
        last unless ($record =~ /\S/); # blank line

        my $line = $fline - 1; # for messages
        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:/) {
            $logger->error("l:$line Missing blank line after Contig block");
	    last;
	}
    
        elsif ($record =~ /Is_read/) {
            $logger->error("l:$line \"Is_read\" keyword incompatible with Contig block");
            return 0,$line;
        }
        elsif ($record =~ /Is_contig/) {
            $logger->finest("l:$line NEW Contig $contigname: $record");
            next;

	}
        elsif ($record =~ /Unpadded/) {
	    next;
	}
        elsif ($record =~ /Padded/) {
            unless ($usepadded) {
                $logger->severe("l:$line padded data not allowed");
                return 0,$line;
	    }
            $isUnpadded = 0;
        }

# process 'Assembled_from' specification get constituent reads and mapping

        if ($record =~ /Ass\w+from\s+(\S+)\s+(.*)$/) {
# an Assembled from alignment
            my $readname = $1;
            my $readdata = $readnamehash->{$readname};
            unless (defined($readdata)) {
# on first encounter create the Mapping and Read for this readname
                $readdata = []; # array (length 2)
# if an external Read object list is provided, look there first
                $readdata->[0] = $readobjecthash->{$readname} if $readobjecthash;
                unless ($readdata->[0]) {
                    $readdata->[0] = new Read($readname);
                    $readobjecthash->{$readname} = $readdata->[0] if $readobjecthash;
		}
                $readdata->[1] = new Mapping($readname);
                $readnamehash->{$readname} = $readdata;
                $contig->addMapping($readdata->[1]);
                $contig->addRead($readdata->[0]);
	    }            
# add the alignment to the Mapping
            my $mapping = $readdata->[1];
            my @positions = split /\s+/,$2;
            if (scalar @positions == 4) {
# an asssembled from record; $entry returns number of alignments
                my $entry = $mapping->addAssembledFrom(@positions); 
# test number of alignments: a padded contig allows only one record per read
                if (!$isUnpadded && $entry > 1) {
                    $logger->severe("l:$line Multiple 'assembled_from' records in "
				    ."padded contig $contigname");
                    next;
                }
            }
        }

# process contig tags
 
        elsif ($contigtags && $record =~ /Tag\s+($contigtags)\s+(\d+)\s+(\d+)(.*)$/i) {
# detected a contig TAG
            my $type = $1; my $tcps = $2; my $tcpf = $3; 
            my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;

# test for a continuation mark (\n\); if so, read until no continuation mark
            while ($info =~ /\\n\\\s*$/) {
$logger->error("Extending Tag record ($line)  .. SHOULD NOT OCCUR!!");
                if (defined($record = <$CAF>)) {
                    chomp $record;
                    $info .= $record;
                    $line++;
                }
                else {
                    $info .= '"' unless ($info =~ /\"\s*$/); # closing quote
                }
            }

# ignore autogenerated tags

            next if ($info =~ /imported|split|shift|truncated/);

            my $tag = TagFactory->makeContigTag($type,$tcps,$tcpf,TagComment=>$info);
            my ($status,$msg) = $tag->verify(); # complete the tag using info
            if ($status) {
                $contig->addTag($tag);
	    }
	    else {
                $logger->warning("($line) invalid or empty (contig) tag: ".($msg || ''));
	    }
        }
        elsif ($ignoretags && $record =~ /Tag\s+($ignoretags)\s+(\d+)\s+(\d+)(.*)$/i) {
            $logger->info("($line) CONTIG tag ignored: $record");
        }
        elsif ($record =~ /Tag/) {
            $logger->info("($line) CONTIG tag not recognized: $record");
        }
        else {
            $logger->info("($line) Ignored: $record");
        }
    }

    return 1,$fline;
}

sub parseRead {
# read Read data block from the file handle; the file must be positioned at the
# correct position before invoking this method: either before the line with Sequence
# keyword or at the start of the actual data block
    my $CAF  = shift;
    my $read = shift; # Read instance with readname defined
    my $fline = shift; # starting line in the file (re: error reporting)
    my %options = @_; # readtaglist, edittaglist, fullreadscan, noverify

    &verifyPrivate($CAF,'parseRead');

    my $logger = &verifyLogger('parseRead');

# options: if taglist specified only those tags will be picked up, with info on other
#          tags skipped; if no readtaglist specified all tags will be processed

    my $readtaglist = $options{readtaglist} || '\w{3,4}'; # default any tag (always)
    my $edittaglist = $options{edittaglist} || '';

    my $usepadded = $options{usepadded} || 0;

# test if it is indeed the start of a sequence block

    my $record;
    my $readname;

    unless ($options{noverify}) {

# test for the line with DNA keyword; cross check the object name

        $record = <$CAF>;
        chomp $record;
        my $line = $fline;
        $fline++;

        if ($record =~ /^\s*Sequence\s*\:?\s*(\S+)/) {
            $readname = $1;
            my $name = $read->getReadName();
            if ($name && $readname ne $name) {
                $logger->severe("l:$line Incompatible object names ($name $readname)");
                return 0,$line;
            }
            elsif (!$name) {
                $read->setReadName($readname);
            }
	}
        else {
            $logger->severe("Position error on CAF file ($line: $record)");
            return 0,$line;
        }
    }

    $readname = $read->getReadName() unless $readname;

# parse the file until the next blank record

    my $isUnpadded = 1;
    my $sequencingvector;
    while (defined($record = <$CAF>)) {
        $fline++;
        chomp $record;
        last unless ($record =~ /\S/); # end of this block
# add subsequent lines if continuation mark '\n\' present
        while ($record =~ /\\n\\\s*$/) {
            my $extension;
            if (defined($extension = <$CAF>)) {
                chomp $extension;
                $record .= $extension;
# $record =~ s/\\n\\\s*\"/\"/; # replace redundant continuation
                $fline++;
            }
            elsif ($record !~ /\"\s*$/) {
# end of file encountered: complete continued record
                $record .= '"' if ($record =~ /\"/); # closing quote
            }
        }
        $record =~ s/[\\n\\]+\s*\"/\"/; # remove redundant continuation

# check presence and compatibility of keywords

        my $line = $fline - 1;
        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:/) {
            $logger->error("Missing blank line after Read block ($line)");
            $logger->error("$record");
	    last; # (unexpected) end of block
	}
    
        elsif ($record =~ /Is_contig/) {
            $logger->error("\"Is_contig\" keyword incompatible with Read block");
            return 0,$line;
        }
        elsif ($record =~ /Is_read/) {
            $logger->finest("NEW Read $readname: ($line) $record");
            next;

	}
        elsif ($record =~ /Unpadded/) {
	    next;
	}
        elsif ($record =~ /Padded/) {
            unless ($usepadded) {
                $logger->severe("l:$line padded data not allowed");
                return 0,$line;
	    }
            $isUnpadded = 0;
        }

# processing a read, test for Alignments and Quality specification

        if ($record =~ /Align\w+\s+((\d+)\s+(\d+)\s+(\d+)\s+(\d+))\s*$/) {
# AlignToSCF for both padded and unpadded files
            my @positions = split /\s+/,$1;
            if (scalar @positions == 4) {
                my $entry = $read->addAlignToTrace([@positions]);
                if ($isUnpadded && $entry == 2) {
                    $logger->info("Edited read $readname detected ($line)");
                }
            }
            else {
                $logger->severe("Invalid alignment: ($line) $record",2);
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
            my $sv = $4; # test against sequencing vector if defined before
            if ($sequencingvector && $sequencingvector ne $sv) {
		$logger->warning("sequencing vector inconsistency corrected ($sv,$sequencingvector)");
                $sv = $sequencingvector;
	    }
            $read->addSequencingVector([$4, $2, $3]);
        }
        elsif ($record =~ /Clone_vec\s+(\w+)\s(\d+)\s+(\d+)\s+\"([\w\.]+)\"/i) {
            $read->addCloningVector([$4, $2, $3]);
        }

# further processing a read Read TAGS and EDITs

        elsif ($readtaglist && $record =~ /Tag\s+($readtaglist)\s+(\d+)\s+(\d+)(.*)$/i) {
# elsif ($readtaglist && $record =~ /Tag\s+($readtaglist)\s+(\d+)\s+(\d+)(.*)$/i) {
            my $type = $1; my $trps = $2; my $trpf = $3;
            my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
# test for a continuation mark (\n\); if so, read until no continuation mark
            while ($info =~ /\\n\\\s*$/) {
$logger->error("This line extention block should NOT be activated : $fline $record");
                if (defined($record = <$CAF>)) {
                    chomp $record;
                    $info .= $record;
                    $fline++;
                }
                else {
                    $info .= '"' unless ($info =~ /\"\s*$/); # closing quote
                }
            }

# build a new read Tag instance

	    my $tag = TagFactory->makeReadTag($type,$trps,$trpf,TagComment => $info);

            my ($status,$msg) = $tag->verify(); # complete the tag using info

            if ($status) {
                $read->addTag($tag);
	    }
            else {
                $logger->info("($line) ignored invalid or empty "
                              . $tag->getType() . " tag for read "
                              . $read->getReadName() . " : ".($msg || ''));
                $logger->info($tag->writeToCaf(0));
            }
        }

# most of the following is not operational

        elsif ($record =~ /Tag/ && $edittaglist && $record =~ /$edittaglist/) {
            $logger->fine("READ EDIT tag detected but not processed: $record");
        }

        elsif ($record =~ /Tag/) {
            $logger->fine("($line) READ tag ignored: $record");
        }
     
        elsif ($record =~ /Note\sINFO\s(.*)$/) {
# TO BE COMPLETED
	    my $trpf = $read->getSequenceLength();
#            my $tag = new Tag('readtag');
#            $tag->setType($type);
#            $tag->setPosition($trps,$trpf);
#            $tag->setStrand('Forward');
#            $tag->setTagComment($info);
  	    $logger->info("NOTE detected but not processed ($line): $record");
        }

        elsif ($record =~ /SCF|Pro|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
# this block is taken from CAFfileloader
            next unless $options{fullreadscan};
# decode the read meta data
            $record =~ s/^\s+|\s+$//g;
            my @items = split /\s+/,$record; 
#print "rec:'$record' '@items' \n" if !$items[0];
            if ($items[0] =~ /Temp/i) {
                $read->setTemplate($items[1]);
            }
            elsif ($items[0] =~ /^Ins/i) {
                $read->setInsertSize([$items[1],$items[2]]);
            }
            elsif ($items[0] =~ /^Liga/i) {
                $read->setLigation($items[1]);
            }
#            elsif ($items[0] =~ /^Seq_vec/i) {
#		my ($svleft, $svright, $svname) = @items[2,3,4];
#		$svname =~ s/\"//g if defined($svname);
#		$read->addSequencingVector([$svname, $svleft, $svright]);
#            }
#            elsif ($items[0] =~ /^Sequencing_vector/i) {
#		my $svname = $items[1];
#		$svname =~ s/\"//g if defined($svname);
#            }
            elsif ($items[0] =~ /^Pri/i) {
                $read->setPrimer($items[1]);
            }
            elsif ($items[0] =~ /^Str/i) {
                $read->setStrand($items[1]);
            }
            elsif ($items[0] =~ /^Dye/i) {
                $read->setChemistry($items[1]);
            }
#            elsif ($items[0] =~ /^Clone_vec/i) {
#		my ($cvleft, $cvright, $cvname) = $record =~ /^Clone_vec\s+\S+\s+(\d+)\s+(\d+)\s+(\"\S+\")?/;
#		$cvname =~ s/\"//g if defined($cvname);
#		$read->addCloningVector([$cvname, $cvleft, $cvright]);
#            }
            elsif ($items[0] =~ /^Clo/i) {
                $read->setClone($items[1]);
            }
            elsif ($items[0] =~ /^Pro/i) {
                $read->setProcessStatus($items[1]) if ($record !~ /PASS/);
            }
            elsif ($items[0] =~ /^Asp/i) {
                $read->setAspedDate($items[1]);
            }
            elsif ($items[0] =~ /^Bas/i) {
                $read->setBaseCaller($items[1]);
            }
#            elsif ($items[0] =~ /^Cli/i) {
#                $read->setLowQualityLeft($items[2]);
#                $read->setLowQualityRight($items[3]);
#            }
            elsif ($items[0] =~ /SCF_File/i) {
# add if other than default and not zip files
                if ($items[1] !~ /\.gz|zip|tar/) {
                    $read->setTraceArchiveIdentifier($items[1]);
                } 
            }

	}

	else {
            $logger->warning("($line) not recognized : $record");
        }
    }

    return 1,$fline;
}

#-----------------------------------------------------------------------------
# scaffold
#-----------------------------------------------------------------------------

sub parseScaffold {
    my $this = shift;
    my $file = shift;
    my %options = @_; # full =>

    my $logger = &verifyLogger('parseScaffold');

    unless ($file =~ /\.agp/) {
        $logger->error("Invalid file name : $file");
        return undef;
    }

    my $APG = new FileHandle($file,'r'); # open for read

    my $apg = []; # for array of arrays

    while (my $record = <$APG>) {
# contig information
        $record =~ s/^\s*|\s*$//g;
        next unless $record;
        if ($record =~ /[\-\+]/) {
            my @data = split /\s+/,$record;
            unshift @data, 'c';
            push @$apg,[@data];           
	}
# gap information
	else {
            my @data = split /\s+/,$record;
            unshift @data, 'g';
            push @$apg,[@data];           
	}
    }

    close $APG;

    return &scaffoldList($apg) unless $options{full}; # return list of contigs

    return $apg; # returns an array of arrays with scaffold member data
}

sub scaffoldList {
# convert array of arrays into list of signed contig IDs
    my $apg = shift; # array of arrays

    return undef unless ($apg && @$apg);

    my @scaffold;
    foreach my $component (@$apg) {
        my $type = shift @$component;
        next unless ($type eq 'c'); # ignore gaps
        my $sign = pop @$component;
        my $identifier = shift @$component;
        push @scaffold,"$sign$identifier";
    }
    return \@scaffold;
}

#-----------------------------------------------------------------------------
# access protocol
#-----------------------------------------------------------------------------

sub verifyParameter {
    my $object = shift;
    my $method = shift || 'UNDEFINED';
    my $class  = shift || 'Contig';

    return if ($object && ref($object) eq $class);
    print STDOUT "ContigFactory->$method expects a $class instance as parameter\n";
    exit 1;
}

sub verifyPrivate {
# test if reference of parameter is NOT this package name
    my $caller = shift;
    my $method = shift || 'verifyPrivate';

    return unless ($caller && ($caller  eq 'ContigFactory' ||
                           ref($caller) eq 'ContigFactory'));
    print STDERR "Invalid use of private method '$method' in package ContigFactory\n";
    exit 1;
}

#-----------------------------------------------------------------------------
# log file
#-----------------------------------------------------------------------------

my $LOGGER;

sub verifyLogger {
# private, test the logging unit; if not found, build a default logging module
    my $prefix = shift;

    &verifyPrivate($prefix,'verifyLogger');

    if ($LOGGER && ref($LOGGER) eq 'Logging') {

        $LOGGER->setPrefix($prefix) if defined($prefix);

        return $LOGGER;
    }

# no (valid) logging unit is defined, create a default unit

    $LOGGER = new Logging();

    $prefix = 'ContigFactory' unless defined($prefix);

    $LOGGER->setPrefix($prefix);
    
    return $LOGGER;
}

sub setLogger {
# assign a Logging object 
    my $this = shift;
    my $logger = shift;

    return if ($logger && ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

    &verifyLogger(); # creates a default if $LOGGER undefined
}

#-----------------------------------------------------------------------------

1;
