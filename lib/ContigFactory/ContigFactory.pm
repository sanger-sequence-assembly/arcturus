package ContigFactory;

use strict;

use Contig;

use Mapping; # to be removed later

use RegularMapping;
use CanonicalMapping;

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

    unless ($FASTA) {
	$logger->error("Can't open fasta file $fasfile");
	return undef;
    }

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

    my $parsesrc = 0;
    my $srcdescriptors = "source|contig|gap";

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
            $logger->error("processing line $line",bs => 0);
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
# look for 'source' keyword
            elsif ($info =~ /($srcdescriptors)\s+(\d+)[\.\>\<]+(\d+)/) {
                my ($type,$ts,$tf) = ($1,$2,$3);
		$type = $translation{$type} || $type;
                my $contigtag = TagFactory->makeContigTag($type,$ts,$tf);
                $contigtag->setStrand('Forward');
                push @contigtag,$contigtag;
		$parsetag = 0;
                $parsesrc = 1;
	    }
            elsif ($info =~ /($srcdescriptors)\s+complement\(([^\)]+)\)/) {
                my ($type,$joinstring) = ($1,$2);
		$type = $translation{$type} || $type;
                my $contigtag = TagFactory->makeContigTag($type);
                my ($ts,$tf) = split /\.+/,$joinstring;
                $contigtag->setPosition($ts,$tf);
                $contigtag->setStrand('Reverse');
                push @contigtag,$contigtag;
		$parsetag = 0;
                $parsesrc = 1;
	    }
# if parsetag flag not on, we are outside an annotation tag
            elsif ($parsetag && @contigtag) {
                my $contigtag = $contigtag[$#contigtag]; # most recent addition
# replace this by a simple adding to an array
		if ($options{fulltagcomment}) {
# only separate out systematic ID
                    if ($info =~ /\bsystematic_id\b\=\"(.+)\"/) {
                        $contigtag->setSystematicID($1);
			next;
	 	    }
#                   if ($info =~ /\barcturus\_note\b\=\"(.+)\"/) {
#                       $contig->addContigNote($1) if $contig; # ??
#                       next;
#	            }
  		    my $tagcomment = $contigtag->getTagComment();
                    $tagcomment = [] unless defined $tagcomment;
                    if (ref($tagcomment) eq 'ARRAY') {
                        push @$tagcomment,$info; # as is
                        $contigtag->setTagComment($tagcomment);
                    }                
	        }
	        else {
# concatenate selected bits of info
                    my $tagcomment = $contigtag->getTagComment() || '';
                    if ($info =~ /(arcturus\_note|ortholog|systematic_id)/) {
                        my $kind = $1;
                        unless ($tagcomment =~ /\b$kind\b/) { 
                            $info =~ s/(^\s*|\s*$|\/)//g;
                            if ($info =~ /\bsystematic_id\b\=\"(.+)\"/) {
                                $contigtag->setSystematicID($1);
		            }
                            if ($info =~ /\barcturus\_note\b\=\"(.+)\"/) {
                                $contig->addContigNote($1) if $contig;
		            }
			    else {
                                $tagcomment .= '\\n\\' if $tagcomment;
	       	                $tagcomment .= $info;
     		                $contigtag->setTagComment($tagcomment);
			    }
		        }
                    }
		    else {
#print STDOUT "not parsed: $info \n";
		    }
                }
                  
            }
# parse source information
            elsif ($parsesrc && @contigtag) {
                my $contigtag = $contigtag[$#contigtag]; # most recent addition
                my $tagtype = $contigtag->getType();
                $info =~ s/(^\s*|\s*$|\/)//g;
                if ($info =~ /\bnote\b\=\"(.+)\"/) {
                    $contig->addContigNote($1) if ($tagtype eq 'source');
	        }
                elsif ($info =~ /\blabel\b\=(.+)/) {
#print "label $1  tagtype $tagtype\n";
                    my $label = $1;
                    $label =~ s/^[\s|\"|\']+|[\s|\"|\']+$//g;
                    $contigtag->setComment($label) if ($tagtype eq 'contig');
                    $contigtag->setTagSequenceName($label);
                }
		my $tagcomment = $contigtag->getTagComment();
                $tagcomment = [] unless defined $tagcomment;
                if (ref($tagcomment) eq 'ARRAY') {
                    push @$tagcomment,$info; # as is
                    $contigtag->setTagComment($tagcomment);
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

sub getInventory {
# returns reference to inventory hash or undef
    my $class = shift;

    my $inventory_hash;

    $inventory_hash = $class->{inventory} if ref($class); # called on an instance

    $inventory_hash = $INVENTORY if (!$inventory_hash && ref($INVENTORY) eq 'HASH');

    $inventory_hash = &buildCafFileInventory(@_) if @_; # try if input is given

    return $inventory_hash if $inventory_hash; # no storage on inventory handle

# there is no valid inventory

    my $logger = verifyLogger('getInventory');
    $logger->error("*** missing inventory ***");
    return undef;
}

sub cafFileInventory { return &buildInventory(shift,inventory=>1,@_);} # temporary alias

sub buildInventory {
# build an inventory of objects in the CAF file
    my $class = shift;
    my $caffile = shift; # caf file name or 0 
    my %options = @_; # progress=> , linelimit=>

    my $inventory_hash = &buildCafFileInventory($caffile,%options);

    $class->{inventory} = $inventory_hash if ref($class); # store on instance hash

    $INVENTORY = $inventory_hash unless ref($class);      # store on class variable

    return $inventory_hash if $options{inventory};

    return scalar(keys %$inventory_hash) - 1 if $inventory_hash;

    return undef; # build failed
}

sub buildCafFileInventory {
 # build an inventory of objects in the CAF file
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
                    if (my $rank = $inventory->{$identifier}->{Rank}) {
   	                $logger->severe("multiple occurrence of contig $identifier : "
                                       ."previous rank:$rank  new:".$contigcounter+1);
 		    }
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
        elsif ($record =~ /^Tag/) {
            my $objecttype = $inventory->{$identifier}->{Is};
#            next if ($objecttype eq 'contig');    
            $inventory->{$identifier}->{tags}++;
	}
        $location = tell($CAF);
    }

    $CAF->close() if $CAF;

    return $inventory;
}
   
my %headers = (Sequence=>'SQ',DNA=>'DNA',BaseQuality=>'BQ',segments=>'Segs',
               tags=>'Tags',rid=>'read ID', sid=>'sequence ID',V=>'version');

sub listInventoryForObject {
# returns a list of inventory items for the give object name
    my $class = shift;
    my $objectname = shift;

    my $inventory = &getInventory($class);

    my $report = sprintf ("%24s",$objectname);
    my $objectdata = $inventory->{$objectname} || return $report." no data";
    my @types = ('Sequence', 'DNA', 'BaseQuality','rid','sid','VSN','tags');
    foreach my $type (@types) {
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

#------------- return read or contig names --------------

sub getContigNames {
    my $class = shift;
    return &getNames(&getInventory($class),'contig');
}

sub getContigNamesWithTags {
    my $class = shift;
    return &getNames(&getInventory($class),'contig',1);
}

sub getReadNames {
    my $class = shift;
    return &getNames(&getInventory($class),'read');
}

sub getReadNamesWithTags {
    my $class = shift;
    return &getNames(&getInventory($class),'read',1);
}

sub getNames {
# private
    my $inventory = shift;
    my $classtype = shift;
    my $withtag = shift; # optional

    my $namelist;

    foreach my $objectname (keys %$inventory) {
# ignore non-objects
        my $objectdata = $inventory->{$objectname};
# Read and Contig objects have data store as a hash; if no hash, ignore 
        next unless (ref($objectdata) eq 'HASH');

        my $objecttype = $objectdata->{Is};
        next unless ($objecttype =~ /$classtype/);
        next if ($withtag && !$objectdata->{tags});
        push @$namelist,$objectname;
    }

    @$namelist = sort {$inventory->{$a}->{Sequence}->[0] <=> $inventory->{$b}->{Sequence}->[0]} @$namelist;

    return $namelist;
}

#------------- assigning read sequence and version -------------------------------

sub putReadSequenceIDs {
# puts read sequence version info in inventory; returns reads not identified 
    my $class = shift;
    my $readversionhash = shift; # read sequence id and version

    my @readnames = keys %$readversionhash;

    my $reads = $class->readExtractor(\@readnames,$readversionhash) || [];

    my $inventory = &getInventory($class);

# pick up the reads with read_id and sequence_id defined, and split out those not

    my @newversion;
    foreach my $read (@$reads) {
        my $seq_id = $read->getSequenceID();
        unless ($seq_id) {
	    print STDERR "No sequence ID for ".$read->getReadName()."\n";
            push @newversion,$read;
	    next;
	}
        my $rinventory = $inventory->{$read->getReadName()};
        $rinventory->{rid} = $read->getReadID();
        $rinventory->{sid} = $read->getSequenceID();
        $rinventory->{VSN} = $read->getVersion();
    }

    return [@newversion];
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

# options : usepadded, consensus, contigtaglist, ignoretaglist
#           readtaglist, noreadsequence, addreads

    &verifyParameter($contignames,'contigExtractor','ARRAY');

    my $logger = &verifyLogger('contigExtractor');

    my $inventory = &getInventory($class);

# -------------- options processing (used in this module)

    my $consensus = $options{consensus}; # include consensus, default not

    my $addreads  = $options{addreads};

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

# --------------- main

# initiate output list; use hash to filter out double entries

    my %contigs;

# build a table, sorted according to file position, of contig data to be collected

    my @contigstack;
    my @contigitems = ('Sequence');
    push @contigitems,'DNA','BaseQuality' if $consensus;

    foreach my $contigname (@$contignames) {
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
           ($status,$line) = &parseContig      ($CAF,$contig,$line,%options); # pass options
        }
        elsif ($type == 1) {
           ($status,$line) = &parseDNA         ($CAF,$contig,$line);
        }
        elsif ($type == 2) {
           ($status,$line) = &parseBaseQuality ($CAF,$contig,$line);
        }

        next if $type; 

# complete the mappings by adding a (possible) sequence id

        if (my $mapping_arrayref = $contig->getMappings()) {
            foreach my $mapping (@$mapping_arrayref) {
                my $readname = $mapping->getMappingName();
                my $seq_id = $inventory->{$readname}->{sid} || next;
                $mapping->setSequenceID($seq_id);
	    }
	}
        
# and collect the reads in this contig

        my $reads = $contig->getReads();
        unless (!$addreads || $reads && @$reads) {
	    $logger->error("contig ". $contig->getContigName()." has no reads");
            next;
	}

        next unless $addreads;

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
        $read->setDataSource($class);
        push @$extractedreads,$read;
        foreach my $item (@readitems) {
            my $itemlocation = $rinventory->{$item};
            next unless $itemlocation;
            push @readstack,[($read,$components{$item},@$itemlocation)];
	}
# preload read_id,seq_id,version (if they are available)
        $read->setReadID     ($rinventory->{rid});
        $read->setSequenceID ($rinventory->{sid});
        $read->setVersion    ($rinventory->{VSN});
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
                $read->setReadID     ($versionhash->{read_id});
                $read->setSequenceID ($versionhash->{seq_id});
                $read->setVersion    ($version);
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
# parse and extract Sequence, DNA and BaseQuality blocks
#------------------------------------------------------------------------------

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

    my $objectname = $object->getName();

    if ($qualitydata) {
        $qualitydata =~ s/^\s+|\s+$//g; # remove leading/trailing
        my @BaseQuality = split /\s+/,$qualitydata;
# ad hoc change consensus
        if (ref($object) eq 'Read' && $objectname =~ /afake/) {
            foreach my $qlt (@BaseQuality) {
                $qlt = 2;
	    }
        }
        $object->setBaseQuality (\@BaseQuality);
    }
    else {
        $logger->warning("$line: empty Base Quality block detected for $objectname");
    }

    return 1,$line;
}

my $USECANONICAL = 1;
sub useNonCanonical { $USECANONICAL = 0;} # temporary option to use non canonical mappings

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
    my $addreads   = $options{addreads};

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

    my $isUnpadded = 1;
    my $readnamehash = {};
    while (defined($record = <$CAF>)) {
        $fline++;
        chomp $record;
# add subsequent lines if continuation mark '\n\' present (followed by nothing else)
        while ($record =~ /\\n\\\s*$/) {
            my $extension;
            if (defined($extension = <$CAF>)) {
                chomp $extension;
                $record .= $extension;
                $fline++;
            }
            elsif ($record !~ /\"\s*$/) {
# end of file encountered: complete continued record
                $record .= '"' if ($record =~ /\"/); # closing quote
            }
        }
# replace possible continuation mark & closing quote by closing quote
        $record =~ s/(\\n\\)+\s*\"/\"/;
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
	elsif ($record =~ /^Stolen\s*/) {
	    next;
	}

# process 'Assembled_from' specification get constituent reads and mapping

        if ($record =~ /Ass\w+from\s+(\S+)\s+(.*)$/) {
# an Assembled from alignment
            my $readname = $1;
            my $readdata = $readnamehash->{$readname};
            unless (defined($readdata)) {
# on first encounter create the Mapping and Read for this readname
                $readdata = []; # array (length 2)
                $readnamehash->{$readname} = $readdata;
                $readdata->[0] = []; # for alignment records
		$readdata->[1] = new Read($readname) if $addreads;
	    }            
# add the alignment to the Mapping
            my $segment_arrayref = $readdata->[0];
            my @positions = split /\s+/,$2;
            if (scalar @positions == 4) {
# an assembled from record; test alignment data
                my $diagnosis = '';
                foreach my $position (@positions) {
                    next if ($position && $position > 0); # test invalid position
                    $diagnosis = "non-positive position ";
                    next;
                }
                unless (abs($positions[1]-$positions[0]) == abs($positions[3]-$positions[2])) {
                    $diagnosis .= "segment size error";
		}
                if ($diagnosis) {
                    $logger->severe("l:$line Invalid alignment ignored : @positions ($diagnosis)");
                    next;
		}
# add the segment to the cache
                push @$segment_arrayref, [@positions];
                               
                my $entry = scalar(@$segment_arrayref);
# test number of alignments: a padded contig allows only one record per read
                if (!$isUnpadded && $entry > 1) {
                    $logger->severe("l:$line Multiple 'assembled_from' records in "
				    ."padded contig $contigname");
                    next;
                }
            }
	    else {
                $logger->severe("l:$line Invalid alignment ignored @positions");
	    }
        }

# process contig tags
 
        elsif ($contigtags && $record =~ /Tag\s+($contigtags)\s+(\d+)\s+(\d+)(.*)$/i) {
# detected a contig TAG
            my $type = $1; my $tcps = $2; my $tcpf = $3; 
            my $info = $4; $info =~ s/\s+\"([^\"]+)\".*$/$1/ if $info;
# put in a test for unexpected continuation mark at the end of the tag info
            if ($info =~ /\\n\\\s*$/) {
                $logger->special("Unexpected continuation mark in tag removed ($line: $info)");
                $info =~ s/(\\n\\)+\s*$//;
		exit;
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

# now go through the cached read info data and build the mappings

    $logger->info("Building RegularMappings");
    foreach my $readname (keys %$readnamehash) {
        my $readdata = $readnamehash->{$readname};
        delete $readnamehash->{$readname};
 
        my $mapping;
#        my $mapping = new RegularMapping($readdata->[0]); # constructor builds mapping
        $mapping = new RegularMapping($readdata->[0]) if $USECANONICAL; # fail empty mapping
        $mapping = new Mapping() unless $USECANONICAL;

        unless ($mapping) { # build of mapping failed
            $logger->error("FAILED to build read-to-contig mapping $readname");
            next if $options{ignorefailedmapping}; # also do not add read
            $logger->error("skipped mapping $readname");
	}
# complete mapping
        $mapping->setMappingName($readname);
# add read (if any) and mapping to contig
        $contig->addRead($readdata->[1]) if $readdata->[1];
        $contig->addMapping($mapping);

        next if $USECANONICAL;
# add segments (old Mapping class)
        foreach my $segment_arrayref (@{$readdata->[0]}) {
            $mapping->addAssembledFrom(@$segment_arrayref);
        }
    }

    return 0,$fline unless $contig->hasMappings();

    $logger->warning("number of Regular   Mappings: " .$contig->hasMappings());
    $logger->warning("number of Canonical Mappings: " .CanonicalMapping->cache());
#    $logger->info("number of Regular   Mappings: " .$contig->hasMappings());
#    $logger->info("number of Canonical Mappings: " .CanonicalMapping->cache());

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

    my $readlength = 0;
    my $isUnpadded = 1;
    my $sequencingvector;
    my $tagpositiontest;
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
	    last; # (unexpected) end of block (INVESTIGATE if this occurs!)
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
                $readlength = $positions[1] if ($positions[1] > $readlength);
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
	    $readlength = $trpf if ($trpf > $readlength);
        }

# most of the following is not operational

        elsif ($record =~ /Tag/ && $edittaglist && $record =~ /$edittaglist/) {
            $logger->fine("READ EDIT tag detected but not processed: $record");
        }

        elsif ($record =~ /Tag/) {
            $logger->fine("($line) READ tag ignored: $record");
        }
     
        elsif ($record =~ /Note\s(.*)$/i) {
            my $info = $1;
# don't try to get the read length via getSequenceLength, because that may load DNA and
# interfere with the record read order
            $readlength = 1 unless $readlength;
	    my $tag = TagFactory->makeReadTag('NOTE',1,$readlength,TagComment => $info);
            $read->addTag($tag);
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
# special "stolen": format as WARN tag
        elsif ($record =~ /stole[n]?(.*)/i) {
            my $info = $1 || '';
            $info =~ s/([\"\'])([^\"\']+)\1/$2/;
            $info = "Stolen ".$info; 
            my ($rstart,$rfinal) = (1,0);
# do not test here for read length, because that would load sequence by delay
            $rfinal = $read->getSequenceLength() if $read->hasSequence();
# if length not found, try clipping range
            unless ($rfinal) {
                my $lql = $read->getLowQualityLeft();
                my $lqr = $read->getLowQualityRight();
                $rstart = $lql + 1 if defined($lql);
                $rfinal = $lqr - 1 if defined($lqr);
                $rfinal = 1 unless defined $rfinal;
                $tagpositiontest = 1;
            }
            my $tag = TagFactory->makeTag('WARN',$rstart,$rfinal);
            $tag->setTagComment($info) if $info;
            $read->addTag($tag);
        }

	else {
            $logger->warning("($line) not recognized : $record");
        }
    }

    if ($tagpositiontest) {
# adjust tag positions here if special tags were flagged
        my $tags = $read->getTags();
        foreach my $tag (@$tags) {
            next unless ($tag->getType() eq 'WARN');
            my ($ps,$pf) = $tag->getPosition();
            next if ($ps > 0 && $ps <= $pf);
            $pf = $read->getSequenceLength();
            $tag->setPosition(1,$pf);
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
