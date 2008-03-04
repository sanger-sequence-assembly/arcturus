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
# class variable
# ----------------------------------------------------------------------------

my $TF; # tag factory
my $TAGTEST = 0;
my $TESTMODE = 1;

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
# building Contig instances from a Fasta file
# ----------------------------------------------------------------------------

sub getContigs {
# returns array of Contig instances found on input file
    my $class = shift;
    my $filename = shift;
    my %options = @_;

    my $format = $options{format};

    unless ($format) {
        if ($filename =~ /\.(\w+)\s*$/) {
            $format = $1; # take file extension as type indicator
	}
    }

    
    if ($format eq 'fasta' || $format eq 'fas') {
        return &fastaFileParser($class,$filename,@_);
    }
    elsif ($format eq 'embl') {
        return &emblFileParser($class,$filename,@_);
    }
    elsif ($format eq 'caf') {
        return &cafFileParser($class,$filename,@_);
    }

    my $logger = &verifyLogger('getContigs');

    $logger->error("unknown format for file $filename");

    return undef;
}

sub fastaFileParser {
# build contig objects from a Fasta file 
    my $class = shift;
    my $fasfile = shift; # fasta file name
    my %options = @_;

    my $logger = &verifyLogger('fastaFileParser');

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
            $logger->error("processing line $line",bs => 1);
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
            $logger->error("Ignore data: $record");
	}
    }
# add the last one to the stack 
    if ($contig && $sequence) {
        $contig->setSequence($sequence);
        push @$fastacontigs, $contig;
    }

    $FASTA->close();

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
            if ($contig && $sequence) {
                unless ($length == $checksum) {
		    $logger->error("Checksum error ($checksum - $length) on embl file "
                                  .$contig->getContigName());
		}
                $contig->setSequence($sequence);
                if (@contigtag) {
                    $contig->addTag(@contigtag);
                    undef @contigtag;
		}
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
            if ($info =~ /(CDS|Tag)\s+(\d+)[\.\>\<]+(\d+)/) {
# new tag with one position started
                my ($type,$ts,$tf) = ($1,$2,$3);
                $type = 'FCDS' if ($type eq 'CDS'); # FCDS recognised by Gap4
                my $contigtag = TagFactory->makeContigTag($type,$ts,$tf);
                push @contigtag,$contigtag;
                $parsetag = 1;
            }
            elsif ($info =~ /(CDS|Tag)\s+join\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
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
            elsif ($info =~ /(CDS|Tag)\s+complement\(join\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
                my $contigtag = TagFactory->makeContigTag($type);
                $contigtag->setStrand('Reverse');
                my @positions = split ',',$joinstring;
                foreach my $position (@positions) {
                    my ($ts,$tf) = split /\.+/,$position;
                    $contigtag->setPosition($ts,$tf,join=>1);
		}
                push @contigtag,$contigtag;
                $parsetag = 1;
 	    }
            elsif ($info =~ /(CDS|Tag)\s+complement\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
                my $contigtag = TagFactory->makeContigTag($type);
                $contigtag->setStrand('Reverse');
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
                my $tagcomment = $contigtag->getTagComment() || '';
                if ($info =~ /note|ortholog|systematic/) {
#  cleanup the current info line
                    $info =~ s/(^\s*|\s*$|\/)//g;
                    $tagcomment .= '\\n\\' if $tagcomment;
	   	    $tagcomment .= $info;
		    $contigtag->setTagComment($tagcomment);
                    if ($info =~ /\bsystematic_id\b\=\"(.+)\"/) {
                        $contigtag->setSystematicID($1);
		    }
                }  
            }
# else other info is to be parsed
            else {
# to be developed                
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

    if ($contig && $sequence) {
        unless ($length == $checksum) {
	    $logger->error("Checksum error ($checksum - $length) on embl file "
                           .$contig->getContigName());
     	}
        $contig->setSequence($sequence);

        if (@contigtag) {
            $contig->addTag(@contigtag);
            undef @contigtag;
     	}
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
        elsif ($record =~ /(Is_[read|contig]+)/) {
            my $objecttype = $1;
# check if this is inside a valid block on the file
            if ($identifier && $datatype && $datatype eq 'Sequence') {
                $inventory->{$identifier}->{Is} = $objecttype;

	    }
	    elsif ($identifier) {
		$logger->error("l:$linecount Unexpected $objecttype specification");
	    }
        }
        elsif ($record =~ /Ass\w+from\s+(\S+)\s/) {
            my $read = $1; # ? not used now
            if ($identifier && $datatype && $datatype eq 'Sequence') {
                $inventory->{$identifier}->{segments}++;
	    }
	    elsif ($identifier) {
		$logger->error("l:$linecount Unexpected 'Assembled_from' specification");
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
print STDERR "removeObjectFromInventory ENTER\n";

    &verifyParameter($objectnames,'removeObjectFromInventory','ARRAY');

    my $inventory = &getInventory($class) || return;

    foreach my $objectname (@$objectnames) {
        delete $inventory->{$objectname};
    }
}

#------------- building Contig and Read instances from the caf file --------------------
    
my %components = (Sequence => 0 , DNA => 1 , BaseQuality => 2); # class constants

sub contigExtractor {
    my $class = shift;
    my $contignames = shift; # array with contigs to be extracted
    my %options = @_; # print STDOUT "contigextractor options @_\n";

    my $logger = &verifyLogger('contigExtractor');

    my $inventory = &getInventory($class);

# -------------- options processing

    my $consensus  = $options{consensus};        # include consensus, default not
    my $namefilter = $options{contignamefilter}; # select specific contigs

# default DNA and BaseQuality only added for edited reads

    my $readselect = $options{readselect}; # 'none', 'full', else default

# tag-related: test options, replace if processed or put default values 

    my $contigtaglist = $options{contigtaglist};
    $contigtaglist =~ s/\W/|/g if ($contigtaglist && $contigtaglist !~ /\\/);
    $contigtaglist = '\w{3,4}' unless $contigtaglist; # default
    $options{contigtaglist} = $contigtaglist;

    my $readtaglist = $options{readtaglist};
    $readtaglist =~ s/\W/|/g if ($readtaglist && $readtaglist !~ /\\/);
    $readtaglist = '\w{3,4}' unless $readtaglist; # default
    $options{readtaglist} = $readtaglist;

    my $ignoretaglist = $options{ignoretaglist};
    $ignoretaglist =~ s/\W/|/g if ($ignoretaglist && $ignoretaglist !~ /\\/);
    $options{ignoretaglist} = $ignoretaglist;

    $options{usepadded} = 0 unless defined $options{usepadded};
    $options{noverify}  = 0 unless defined $options{noverify};

# --------------- get caf file from inventory hash

#    my $CAF = &getFileHandle($inventory);
    my $caffile = $inventory->{caffilename};
    my $CAF = new FileHandle($caffile,"r");

    unless ($CAF) {
	$logger->error("Invalid CAF file specification $caffile");
        return undef;
    }

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

        next if ($readselect && $readselect eq 'none');

        push @reads,@$reads;

#        foreach my $read (@$reads) {
#            my $readname = $read->getReadName();
#            my $rinventory = $inventory->{$readname};
#            unless ($rinventory) {
#	        $logger->error("Missing read $readname in inventory");
#	        next;
#   	    }
#            foreach my $item (@readitems) {
#                my $itemlocation = $rinventory->{$item};
#                next unless $itemlocation;
#                push @readstack,[($read,$components{$item},@$itemlocation)];
#	    }
#	}        
    }

    my @readstack;
# default reads have sequence only and DNA if edited
    my @readitems = ('Sequence');
    if ($readselect && $readselect eq 'full') {
        push @readitems,'DNA','BaseQuality';
    } 

    foreach my $read (@reads) {
        my $readname = $read->getReadName();
        my $rinventory = $inventory->{$readname};
        $read->setDataSource($class);
        unless ($rinventory) {
            $logger->error("Missing read $readname in inventory");
            next;
        }
        foreach my $item (@readitems) {
            my $itemlocation = $rinventory->{$item};
            next unless $itemlocation;
            push @readstack,[($read,$components{$item},@$itemlocation)];
	}
    }        

# use readExtractor here; to be tested

# and collect all the required read items

    foreach my $stack (sort {$a->[2] <=> $b->[2]} @readstack) {
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
# type > 0 implies readoption 'full' with all read data now loaded
        next if ($type || $readselect && $readselect eq 'full');
# default read option
        next unless $read->isEdited();
# add here the DNA and Quality data for this read
#	&getSequenceForObject($read,$inventory); next # alternative (conjunct getFileHandle)

        my $readname = $read->getReadName();
        my $rinventory = $inventory->{$readname};
        foreach my $item ('DNA','BaseQuality') {
            my $positions = $rinventory->{$item};
            unless ($positions) {
		$logger->error("No $item available for edited read $readname");
		next;
	    }
           ($fileposition,$line) = @$positions;
            seek $CAF, $fileposition, 00; # position the file 
            $type = $components{$item};
            if ($type == 1) {
               ($status,$line) = &parseDNA         ($CAF,$read,$line);
	    }
	    elsif ($type == 2) {
               ($status,$line) = &parseBaseQuality ($CAF,$read,$line);
	    }
            next if $status;
	    $logger->error("Failed to extract $item data for read $readname");
        }     
    }

    my @contigs;
    foreach my $contigname (sort keys %contigs) {
        push @contigs, $contigs{$contigname};
    }

    $CAF->close() if $CAF;

    return \@contigs;
}

sub readExtractor {
    my $class = shift;
    my $reads = shift; # array with reads to be extracted
    my %options = @_; 
# print STDOUT "readextractor options @_\n";

    my $logger = &verifyLogger('readExtractor');

    my $inventory = &getInventory($class);

# if input is a list of names, replace by list of Read objects

    my @reads;
    foreach my $read (@$reads) {
        next if (ref($read) eq 'Read');
        push @reads,new Read($read); # read contains readname
    }
# if readnames replaced by read objects: assign new output array
    $reads = \@reads if @reads;

# get caf file from inventory hash

    unless ($inventory) {
# pick up the cached hash, if this method not called on the class itself 
        $inventory = $class->{inventory} if (ref($class) eq 'HASH');
# and check
        unless ($inventory) {
            $logger->error("Missing CAF file inventory");
            return undef;
	}
    }   

    my $CAF = &getFileHandle($inventory);

    unless ($CAF) {
	$logger->error("Invalid CAF file specification $inventory->{caffile}");
        return undef;
    }

# --------------- main

$logger->error("getting reads");

    my @readstack;
# default reads have sequence only and DNA if edited
    my @readitems;
    push @readitems,'Sequence'    unless $options{nosequence};
    push @readitems,'DNA'         unless $options{nodna};
    push @readitems,'BaseQuality' unless $options{noquality};

    foreach my $read (@reads) {
        my $readname = $read->getReadName();
        my $rinventory = $inventory->{$readname};
        unless ($rinventory) {
            $logger->error("Missing read $readname in inventory");
            next;
        }
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
	}
    }

    return $reads;
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

    my $reads = $class->readExtractor([($readname)],@_); # port options

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
print STDOUT "getSequenceForReadn";

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

    my $contigtaglist = $options{contigtaglist};
    $contigtaglist =~ s/\W/|/g if ($contigtaglist && $contigtaglist !~ /\\/);
    $contigtaglist = '\w{3,4}' unless $contigtaglist; # default
    $logger->info("Contig tags to be processed: $contigtaglist");

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

# set up the read tag factory and contig tag factory

    $TF = new TagFactory() unless $TF;

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

	    if ($TESTMODE) {
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

            my $sequencedata = '';
$logger->fine("Building $newObjectType for $newObjectName");
            while (defined(my $nextrecord = <$CAF>)) {
                $lineCount++;
                chomp $nextrecord;
                last unless ($nextrecord =~ /\S/); # blank line
                if ($nextrecord =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:/) {
                    $logger->error("Missing blank after DNA or Quality block ($lineCount)");
		    last;
		}
                $sequencedata .= $nextrecord;
            }
$logger->fine("DONE $newObjectType for $newObjectName");
# store the sequence data in the 
            if ($newObjectType eq 'DNA') {
                $sequencedata =~ s/\s+//g; # remove all blank space
                $objectInstance->setSequence($sequencedata);
	    }
	    elsif ($newObjectType eq 'BaseQuality') {
                $sequencedata =~ s/\s+/ /g; # clear redundent blank space
                $sequencedata =~ s/^\s|\s$//g; # remove leading/trailing
                my @BaseQuality = split /\s/,$sequencedata;
                $objectInstance->setBaseQuality (\@BaseQuality);
	    }
	    else {
		$logger->error("This should not occur ($lineCount)");
	    }
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

# THIS SHOULD GO BELOW
            if ($objectName =~ /contig/i) {
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
            }
	    else {
# the new data relate to a read
                next if $blockobject->{$objectName};
                unless ($read = $reads{$objectName}) {
                    $read = new Read($objectName);
                    $reads{$objectName} = $read;
		}
                $objectType = 1; # activate processing read data
	    }
# TO HERE
	}

# REMOVE from HERE ?
#$logger->warning("TAG detected ($lineCount): $record") if ($record =~ /\bTag/);
    my $IGNORETHIS = 0; unless ($IGNORETHIS) {
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

            if ($TESTMODE) {
                my ($status,$line) = &parseRead($CAF,$read,$lineCount,noverify=>1);
                $lineCount = $line if $status;
		$objectType = 0;
                next;
	    }

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
                        $info .= '"' unless ($info =~ /\"\s*$/); # closing quote
                    }
                }

# build a new read Tag instance

		my $tag = $TF->makeReadTag($type,$trps,$trpf,TagComment => $info);

# the tag now contains the raw data read from the CAF file
# invoke TagFactory to process, cleanup and test the tag info

                $TF->cleanup($tag); # clean-up the tag info
                if ($type eq 'OLIG' || $type eq 'AFOL') {        
# oligo, staden(AFOL) or gap4 (OLIG)
                    my ($warning,$report) = $TF->processOligoTag($tag);
                    $logger->fine($report) if $warning;
                    unless ($tag->getTagSequenceName()) {
		        $logger->info("Missing oligo name in read tag for "
                               . $read->getReadName()." (line $lineCount)");
                        next; # don't load this tag
	            }
	        }
                elsif ($type eq 'REPT') {
# repeat read tags
                    unless ($TF->processRepeatTag($tag)) {
	                $logger->info("Missing repeat name in read tag for "
                                  . $read->getReadName()." (line $lineCount)");
                    }
                }
	        elsif ($type eq 'ADDI') {
# chemistry read tag
                    unless ($TF->processAdditiveTag($tag)) {
                        $logger->info("Invalid ADDI tag ignored for "
                                  . $read->getReadName()." (line $lineCount)");
                        next; # don't accept this tag
                    }
 	        }
# test the comment; ignore tags with empty comment
                unless ($tag->getTagComment() =~ /\S/) {
		    $logger->info("Empty $type read tag ignored for "
                                . $read->getReadName()." (line $lineCount)");
                    $logger->info($tag->writeToCaf(0));
		    next; # don't accept this tag
		}

                $read->addTag($tag);
            }

            elsif ($record =~ /Tag/ && $record =~ /$edittags/) {
                $logger->fine("READ EDIT tag detected but not processed: $record");
            }
            elsif ($record =~ /Tag/) {
                $logger->info("READ tag not recognized: $record");
            }
# EDIT tags TO BE TESTED (NOT OPERATIONAL AT THE MOMENT)
       	    elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*replaced\s+(\w+)\s+by\s+(\w+)\s+at\s+(\d+)/) {
                $logger->warning("readtag error in: $record |$1|$2|$3|$4|$5|") if ($1 != $2);
                my $tag = new Tag('read');
	        $tag->editReplace($5,$3.$4);
                $read->addTag($tag);
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*deleted\s+(\w+)\s+at\s+(\d+)/) {
                $logger->warning("readtag error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
                my $tag = new Tag('read');
	        $tag->editDelete($4,$3); # delete signalled by uc ATCG
                $read->addTag($tag);
            }
            elsif ($record =~ /Tag\s+DONE\s+(\d+)\s+(\d+).*inserted\s+(\w+)\s+at\s+(\d+)/) {
                $logger->warning("readtag error in: $record (|$1|$2|$3|$4|)") if ($1 != $2); 
                my $tag = new Tag('read');
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
  	        $logger->info("NOTE detected but not processed ($lineCount): $record");
            }
# finally
            elsif ($record !~ /SCF|Sta|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
                $logger->info("not recognized ($lineCount): $record");
            }
        }

        elsif ($objectType == 2) {
# parsing a contig, get constituent reads and mapping

            if ($TESTMODE) {
                my $contig = $contigs{$objectName};
                my ($status,$line) = &parseContig($CAF,$contig,$lineCount,noverify=>1);
                $lineCount = $line if $status;
		$objectType = 0;
                next;
	    }

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
                        unless ($readnamefilter && 
                                $read->getReadName =~ /$readnamefilter/) {
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
                        next;
                    }
                }
                else {
                    $logger->severe("Invalid alignment: ($lineCount) $record");
                    $logger->severe("positions: @positions",2);
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
                        $info .= '"' unless ($info =~ /\"\s*$/); # closing quote
                    }
                }
                $logger->info("CONTIG tag detected: $record\n"     # info ?
                                . "'$type' '$tcps' '$tcpf' '$info'");
                if ($type eq 'ANNO') {
                    $info =~ s/expresion/expression/;
                    $type = 'COMM';
		}

                my $tag = $TF->makeContigTag($type,$tcps,$tcpf);
#                $TF->cleanup($tag); # 

# my $tag = new Tag('contigtag');
# $tag->setType($type);
# $tag->setPosition($tcps,$tcpf);
# $tag->setStrand('Unknown');

# preprocess COMM and REPT tags

                if ($type eq 'REPT' || $type eq 'COMM') { # TO TAGFACTORY
# remove possible offset info (lost on inheritance)
                    $info =~ s/\,\s*offset\s+\d+//i if ($info =~ /Repeats\s+with/);
	        }

                $tag->setTagComment($info);   # TO TAGFACTORY
                if ($info =~ /([ACGT]{5,})/) {
                    $tag->setDNA($1);
                }

# special for repeats: pickup repeat name

                if ($type eq 'REPT') {  # TO TAGFACTORY
# try to find the name of the repeat
                    $contig->addTag($tag);
                    $info =~ s/\s*\=\s*/=/g;
		    if ($info =~ /^\s*(\S+)\s+from/i) {
                        my $tagname = $1;
                        $tagname =~ s/r\=/REPT/i;
                        $tag->setTagSequenceName($tagname);
	   	    }
# no name found, try alternative
                    elsif ($info !~ /Repeats\s+with/) {
# try to generate one based on possible read mentioned
                        if ($info =~ /\bcontig\s+(\w+\.\w+)/) {
                            $tag->setTagSequenceName($1);   
	                }
# nothing useful found                
                        else {
		            $logger->info("Missing repeat name in contig tag for ".
                                   $contig->getContigName().": ($lineCount) $record");
		        }
                    }
                }

                elsif ($info) {
                    $contig->addTag($tag);
		    $logger->fine($tag->writeToCaf());
                }
                else {
		    $logger->info("Empty $type contig tag ignored ($lineCount)");
		}

	    }
            elsif ($ignoretaglist 
                && $record =~ /Tag\s+($ignoretaglist)\s+(\d+)\s+(\d+)(.*)$/i) {
                $logger->info("CONTIG tag ignored: ($lineCount) $record");
	    }
            elsif ($record =~ /Tag/) {
#$logger->warning("CONTIG tag not recognized: ($lineCount) $record");
                $logger->info("CONTIG tag not recognized: ($lineCount) $record");
            }
            else {
#$logger->warning("ignored: ($lineCount) $record");
                $logger->info("ignored: ($lineCount) $record");
            }
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

    my $nc = scalar (keys %contigs);
    my $nm = scalar (keys %mappings);
    my $nr = scalar (keys %reads);

    $logger->info("$nc Contigs, $nm Mappings, $nr Reads built");

# return array references for contigs and reads 

    return \%contigs,\%reads,$truncated if $options{oldcontigloader};

# bundle all objects in one array

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
        $qualitydata .= $record;
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
# read Read data block from the file handle; the file must be positioned at the
# correct position before invoking this method: either before the line with Sequence
# keyword or at the start of the actual data block
    my $CAF  = shift;
    my $contig = shift; # Contig instance with contigname defined
    my $line = shift; # starting line in the file (re: error reporting)
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
        $line++;

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

    my $isUnpadded = 1;
    my $readnamehash = {};
    while (defined($record = <$CAF>)) {
        $line++;
        chomp $record;
# add subsequent lines if continuation mark '\n\' present
        while ($record =~ /\\n\\\s*$/) {
            my $extension;
            if (defined($extension = <$CAF>)) {
                chomp $extension;
                $record .= $extension;
#                $record =~ s/\\n\\\s*\"/\"/; # replace continuation & closing quote
                $line++;
            }
            elsif ($record !~ /\"\s*$/) {
# end of file encountered: complete continued record
                $record .= '"' if ($record =~ /\"/); # closing quote
            }
        }
        $record =~ s/\\n\\\s*\"/\"/; # replace continuation & closing quote
# check presence and compatibility of keywords
        last unless ($record =~ /\S/); # blank line
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
        elsif ($record =~ /Is_padded/) {
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
                $readdata->[0] = new Read($readname);
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


if ($TAGTEST) {
            my $tag = TagFactory->makeContigTag($type,$tcps,$tcpf,TagComment=>$info);
$logger->warning("CT verify CONTIG tag");
            my ($status,$msg) = $tag->verify(); # complete the tag using info
            $logger->warning("($line) invalid or empty tag: ".($msg || '')) unless $status;
            $contig->addTag($tag) if $status;
$logger->warning("CT DONE (status $status)");

} else {
# remove 'offset' information (lost on inheritance)

            $info =~ s/\,\s*offset\s+\d+//i if ($info =~ /Repeats\s+with/);

# TO TAGFACTORY from  here
            $logger->info("CONTIG tag detected: $record\n"
                         . "'$type' '$tcps' '$tcpf' '$info'");

# investigate annotation again ....

            if ($type eq 'ANNO') {
                $logger->warning("Contig annotation ANNO tag changed to COMM");
                $type = 'COMM';
	    }

            my $tag = TagFactory->makeContigTag($type,$tcps,$tcpf);

# TO TAGFACTORY preprocess COMM and REPT tags 

            if ($type eq 'REPT' || $type eq 'COMM') {
# remove possible offset info (lost on inheritance)
                $info =~ s/\,\s*offset\s+\d+//i if ($info =~ /Repeats\s+with/);
            }

            $tag->setTagComment($info);
            if ($info =~ /([ACGT]{5,})/) {
                $tag->setDNA($1);
            }

# special for repeats: pickup repeat name

            if ($type eq 'REPT') {
# try to find the name of the repeat
                $contig->addTag($tag);
                $info =~ s/\s*\=\s*/=/g;
        	if ($info =~ /^\s*(\S+)\s+from/i) {
                    my $tagname = $1;
                    $tagname =~ s/r\=/REPT/i;
                    $tag->setTagSequenceName($tagname);
	        }
# no name found, try alternative
                elsif ($info !~ /Repeats\s+with/) {
# try to generate one based on possible read mentioned
                    if ($info =~ /\bcontig\s+(\w+\.\w+)/) {
                        $tag->setTagSequenceName($1);   
                    }
# nothing useful found                
                    else {
		        $logger->info("l:$line Missing repeat name in contig tag "
                                 ."for $contigname: $record");
	            }
                }
            }
            elsif ($info) {
                $contig->addTag($tag);
         	$logger->fine($tag->writeToCaf());
            }
            else {
	        $logger->info("l:$line Empty $type contig tag ignored");
	    }
} # end TEST
# TO TAGFACTORY until here

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

    return 1,$line;
}

sub parseRead {
# read Read data block from the file handle; the file must be positioned at the
# correct position before invoking this method: either before the line with Sequence
# keyword or at the start of the actual data block
    my $CAF  = shift;
    my $read = shift; # Read instance with readname defined
    my $line = shift; # starting line in the file (re: error reporting)
    my %options = @_;

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
        $line++;

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
    while (defined($record = <$CAF>)) {
        $line++;
        chomp $record;
        last unless ($record =~ /\S/); # end of this block
# add subsequent lines if continuation mark '\n\' present
        while ($record =~ /\\n\\\s*$/) {
            my $extension;
            if (defined($extension = <$CAF>)) {
                chomp $extension;
                $record .= $extension;
# $record =~ s/\\n\\\s*\"/\"/; # replace redundant continuation
                $line++;
            }
            elsif ($record !~ /\"\s*$/) {
# end of file encountered: complete continued record
                $record .= '"' if ($record =~ /\"/); # closing quote
            }
        }
        $record =~ s/\\n\\\s*\"/\"/; # remove redundant continuation

# check presence and compatibility of keywords

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
        elsif ($record =~ /Is_padded/) {
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
                   print STDERR "Edited read $readname detected ($line)\n";
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
$logger->fine("Read Tag $type detected");
# test for a continuation mark (\n\); if so, read until no continuation mark
            while ($info =~ /\\n\\\s*$/) {
$logger->error("This block should not be activated");
                if (defined($record = <$CAF>)) {
                    chomp $record;
                    $info .= $record;
                    $line++;
                }
                else {
                    $info .= '"' unless ($info =~ /\"\s*$/); # closing quote
                }
            }

# build a new read Tag instance

	    my $tag = TagFactory->makeReadTag($type,$trps,$trpf,TagComment => $info);
if ($TAGTEST) {
print STDERR "verify READ tag\n";
            my ($status,$msg) = $tag->verify(); # complete the tag using info
$logger->error("output status $status, report: $msg for readtag : ".$tag->getType());
            $logger->info("($line) ignored invalid or empty tag: ".($msg || '')) if $status;
            $read->addTag($tag) if $status;
print STDERR "DONE but not added\n" unless ($status);
print STDERR "DONE\n" if ($status);

} else {
# TO TAGFACTORY from  here
# the tag now contains the raw data read from the CAF file
# invoke TagFactory to process, cleanup and test the tag info
            TagFactory->cleanup($tag); # clean-up the tag info
            if ($type eq 'OLIG' || $type eq 'AFOL') {        
# oligo, staden(AFOL) or gap4 (OLIG)
                my ($warning,$report) = TagFactory->processOligoTag($tag);
#                my ($warning,$report) = $TF->processOligoTag($tag);
                $logger->fine($report) if $warning;
                unless ($tag->getTagSequenceName()) {
		$logger->info("Missing oligo name in read tag for "
                                . $read->getReadName()." (l:$line)");
                        next; # don't load this tag
	        }
	    }
            elsif ($type eq 'REPT') {
# repeat read tags
                unless (TagFactory->processRepeatTag($tag)) {
#                unless ($TF->processRepeatTag($tag)) {
	        $logger->info("Missing repeat name in read tag for "
                             . $read->getReadName()." (l:$line)");
                }
            }
            elsif ($type eq 'ADDI') {
# chemistry read tag
                unless (TagFactory->processAdditiveTag($tag)) {
#                unless ($TF->processAdditiveTag($tag)) {
                    $logger->info("Invalid ADDI tag ignored for "
                                 . $read->getReadName()." (l:$line)");
                    next; # don't accept this tag
                }
 	    }
# test the comment; ignore tags with empty comment
            unless ($tag->getTagComment() =~ /\S/) {
	        $logger->info("Empty $type read tag ignored for "
                               . $read->getReadName()." (l:$line)");
                $logger->info($tag->writeToCaf(0));
	        next; # don't accept this tag
	    }
# tag processing finished
            $read->addTag($tag);
} # end TEST
# TO TAGFACTORY until here

        }

# most of the following is not operational

        elsif ($record =~ /Tag/ && $edittaglist && $record =~ /$edittaglist/) {
            $logger->fine("READ EDIT tag detected but not processed: $record");
        }

        elsif ($record =~ /Tag/) {
            $logger->info("($line) READ tag ignored: $record");
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
# finally
        elsif ($record !~ /SCF|Sta|Temp|Ins|Dye|Pri|Str|Clo|Seq|Lig|Pro|Asp|Bas/) {
            $logger->warning("($line) not recognized : $record");
        }
    }

    return 1,$line;
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
