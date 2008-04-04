package CAFReadFactory;

use strict;

use Read;

use ReadFactory;

use TagFactory::TagFactory;

our (@ISA);

@ISA = qw(ReadFactory);

#------------------------------------------------------------
# constructor takes CAF filename
#------------------------------------------------------------

sub new {

    my $class = shift;

# invoke the constructor of the superclass

    my $this = $class->SUPER::new();

# parse the input parameters

    my ($CAF, $includes, $excludes, $log);

    while (my $nextword = shift) {

        $CAF = shift if ($nextword eq 'caf'); # expects a file handle

        $log = shift if ($nextword eq 'log');

        $includes = shift if ($nextword eq 'readnamelike');

        $excludes = shift if ($nextword eq 'exclude');
    }

# take the filename and process the file completely
     
    die "CAFReadFactory constructor requires a CAF file handle" if !$CAF;

# set up the logging, if any

    $this->setLogging($log) if $log;

# set up buffer for possibly included files

    my $includelist;
    if (ref($includes) eq 'ARRAY') {
        $includelist = join '|',@$includes;
    }
    elsif ($includes) {
        $includelist = $includes;
print STDERR "includelist:$includelist\n";
    }     

# set up buffer for possibly excluded or included files

    my $excludehash = {};
    if (ref($excludes) eq 'HASH') {
        $excludehash = $excludes;
    }
    elsif (ref($excludes) eq 'ARRAY') {
        while (my $readname = shift @$excludes) {
            $excludehash->{$readname} = 1;
        }
    }
    elsif ($excludes) {
        $excludehash->{$excludes} = 1;
    }     

# parse the caf file and populate the buffers of the super class

    $this->CAFFileParser($CAF,$excludehash,$includelist);    

    return $this;
}

#------------------------------------------------------------
# getNextRead returns the Read instance stored in the superclass
#------------------------------------------------------------

sub getNextRead {
# pick up the Read reference from the auxiliary data
    my $this = shift;

    my $Read = $this->getNextReadAuxiliaryData(); # returns Read object

    if (!defined($Read) or ref($Read) ne 'Read') {

        my ($readname, $readdata) = @{$this->{readname}};

        $this->logerror("No or invalid next read data: $readname, $readdata");

        return undef;
    }
    else {
        return $Read;
    }
}

#------------------------------------------------------------
# CAF file parser
#------------------------------------------------------------

sub CAFFileParser {
# build an array of Read instances for the reads on this CAF file
    my $this    = shift;
    my $CAF     = shift;
    my $excludehash = shift;
    my $includelist = shift;

    print STDERR "Include $includelist \n" if $includelist;

    undef my %reads; # hash for temporary DNA and Quality data storage

    my $line = 0;
    my $type = 0;
    undef my $pdate;

    my $problems = 0;

    $this->loginfo("Begin reading caf file");

    my $object = '';

    my $record;
    while (defined($record = <$CAF>)) {
        $line++; 
        chomp $record;
        $this->loginfo("Processing line $line") if !($line%100000);
        next if ($record !~ /\S/); # skip empty lines 

        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*:\s*(\S+)/) {
# there is a new object name
            $type = 0;
            my $item = $1;
            $object = $2;

# clip out any object named Contig (? redundant because of Is_contig test ?)

            next if ($record =~ /(\s|^)Contig/);

# test against readname exclude and include filters

            if (defined($excludehash) && defined($excludehash->{$object}) ||
		defined($includelist) && $includelist !~ /\b$object\b/ ) {
                $this->loginfo("read $object ignored");
                next;
            }
            elsif (defined($excludehash) || defined($includelist)) {
                $this->logwarning("read $object accepted");
	    }
# assign the new input type
            $type = 1 if ($item eq 'Sequence');
            $type = 2 if ($item eq 'DNA');
            $type = 3 if ($item eq 'BaseQuality');

# construct a new Read if it is a newly encountered readname

            if (!defined($reads{$object})) {
# add next object to hash list
                my $Read = new Read($object);
                $reads{$object} = {};
                $reads{$object}->{Read} = $Read;
            }
            next;
        }

        elsif ($record =~ /Is_contig\b/) {
            $this->logwarning("Contig $object ignored");
            delete $reads{$object};
            $type = 0;
            next;
        }

        elsif ($record =~ /\bpadded\b/i) {
            $type = 0; # ignore padded data
            $this->logwarning("Padded data for read $object ignored");
            delete $reads{$object};
            exit 0;
        }

        elsif ($record =~ /\bunpadded/i) {
            next;
	}

        elsif ($record =~ /align_to_scf\s+(.*)\s*$/i) {
# count align to SCF records: edited reads cannot be loaded from CAF
            next unless ($type == 1); # scanning a read
            my @positions = split /\s+/,$1;
# get the current Read
            my $Read = $reads{$object}->{Read};
            if (scalar @positions == 4) {
                my $entry = $Read->addAlignToTrace([@positions]);
                if ($entry == 2) {
                    $this->logwarning("Edited read $object detected");
# allow acceptance only if objectname explicitly specified
                    unless (defined($object) && defined($includelist) && $includelist =~ /\b$object\b/) {
                        $this->logwarning("Edited read $object cannot be loaded");
                        delete $reads{$object};
                        $type = 0; # ignore edited data
                    }
                }
                elsif (!$entry) {
                    $this->logwarning("Invalid Align_to_SCF record in read $object");
                }
            }
	    else {
                $this->logwarning("Invalid Align_to_SCF record in read $object");
                delete $reads{$object};
                $type = 0;
	    }
            next;
	}

        elsif ($record =~ /Is_read/) {
            next;
        }
          
        elsif ($type == 1) {
# get the current Read
            my $Read = $reads{$object}->{Read};
# decode the read meta data
            $record =~ s/^\s+|\s+$//g;
            my @items = split /\s+/,$record; 
#print "rec:'$record' '@items' \n" if !$items[0];
            if ($items[0] =~ /Temp/i) {
                $Read->setTemplate($items[1]);
            }
            elsif ($items[0] =~ /^Ins/i) {
                $Read->setInsertSize([$items[1],$items[2]]);
            }
            elsif ($items[0] =~ /^Liga/i) {
                $Read->setLigation($items[1]);
            }
            elsif ($items[0] =~ /^Seq_vec/i) {
		#my ($svleft, $svright, $svname) = $record =~ /^Seq_vec\s+\S+\s+(\d+)\s+(\d+)\s+(\"\S+\")?/;
		my ($svleft, $svright, $svname) = @items[2,3,4];
		$svname =~ s/\"//g if defined($svname);
		$Read->addSequencingVector([$svname, $svleft, $svright]);
            }
            elsif ($items[0] =~ /^Pri/i) {
                $Read->setPrimer($items[1]);
            }
            elsif ($items[0] =~ /^Str/i) {
                $Read->setStrand($items[1]);
            }
            elsif ($items[0] =~ /^Dye/i) {
                $Read->setChemistry($items[1]);
            }
            elsif ($items[0] =~ /^Clone_vec/i) {
		my ($cvleft, $cvright, $cvname) = $record =~ /^Clone_vec\s+\S+\s+(\d+)\s+(\d+)\s+(\"\S+\")?/;
		$cvname =~ s/\"//g if defined($cvname);
		$Read->addCloningVector([$cvname, $cvleft, $cvright]);
            }
            elsif ($items[0] =~ /^Clo/i) {
                $Read->setClone($items[1]);
            }
            elsif ($items[0] =~ /^Pro/i) {
                $Read->setProcessStatus($items[1]) if ($record !~ /PASS/);
            }
            elsif ($items[0] =~ /^Asp/i) {
                $Read->setAspedDate($items[1]);
            }
            elsif ($items[0] =~ /^Bas/i) {
                $Read->setBaseCaller($items[1]);
            }
            elsif ($items[0] =~ /^Cli/i) {
                $Read->setLowQualityLeft($items[2]);
                $Read->setLowQualityRight($items[3]);
            }
            elsif ($items[0] =~ /SCF_File/i) {
# add if other than default and not zip files
                if ($items[1] !~ /\.gz|zip|tar/) {
                    $Read->setTraceArchiveIdentifier($items[1]);
                } 
# test if a data is defined, else use date in SCF file specification
                if (!$Read->getAspedDate()) {
                    if ($items[1] =~ /(\d{4})\W(\d{1,2})\W(\d{1,2})\D/) {
                        $pdate = sprintf ("%04d-%02d-%02d",$1,$2,$3);
                        $Read->setAspedDate($pdate);
                    } 
		    elsif ($items[1] =~ /(\d{1,2})\W(\d{1,2})\W(\d{4})\D/) {
                        $pdate = sprintf ("%04d-%02d-%02d",$1,$2,$3);
                        $Read->setAspedDate($pdate);
                    }
                    elsif ($pdate) {
                        $Read->setAspedDate($pdate);
                    }
                    else {
#			print "No date in SCF file $record $break";
                    }
                }
            }
            elsif ($items[0] =~ /^Tag/i) {
# parse a read tag
                my $type = $items[1];
                my $trps = $items[2];
                my $trpf = $items[3];
                my $info = $items[4] || '';
                while (scalar(@items) > 5) {
                    $info .= " ".$items[5];
                    shift @items;
                }
# test numericity of position data (perhaps to TagFactory)
                if (!$trps || !$trpf || $trps =~ /\D/ || $trpf =~ /\D/) {
                     $this->logwarning("$record\n$line  @items");
                     $problems++;
                     next;
                }
# check contents of oligo tags (perhaps to TagFactory)
                if ($type eq 'OLIG' && !$info) {
#                     print STDERR "$line $record   (missing info)\n";
                     $problems++; # missing info
                }
# test for a continuation mark (\n\); if so, read until no continuation mark
                while ($info && $info =~ /\\n\\\s*$/) {
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
  	        my $tag = TagFactory->makeReadTag($type,$trps,$trpf,
                                                  TagComment => $info);
                $Read->addTag($tag) if $tag;
                $problems++ unless $tag;
	    }
            elsif ($items[0] =~ /^Sequencing_vector/) {
# $items[2] is vector name? check?
                next;
            }

            else {
		$this->logwarning("not recognized: $line  $record");
	    }
        }
        elsif ($type == 2) {
# store the DNA in temporary buffer, add current record to existing contents
            $reads{$object}->{SQ} .= $record;
        }
        elsif ($type == 3) {
# store the Quality Data
            $record =~ s/\b0(\d)\b/$1/g; # remove '0' from values such as '01' .. 
	    $reads{$object}->{AV} .= $record.' ';
        }
# register for this object which section has been completed (on key f1, f2, f3)
	if ($type > 0) {
            $reads{$object}->{"f$type"}++;
            $reads{$object}->{last} = $type; # record last flag updated
        }
    }

# okay, here we have a hash of read hashes

    $this->loginfo("CAF file parser finished ($line)");
    my $nr = scalar(keys %reads);
 
    $this->loginfo("$nr reads found (tag problems $problems)"); 

    my $count = 0;
    my $missed = 0;
    foreach my $object (keys %reads) {

        my $progress = $count + $missed + 1;
        $this->logwarning("processing read $progress") unless ($progress%1000);

        my $readhash = $reads{$object};

        if (!$readhash->{f1} || !$readhash->{f2} || !$readhash->{f3}) {
            unless ($readhash->{f1}) {
                $this->logwarning("read $object is not complete : missing meta data");
	    }
            unless ($readhash->{f1}) {
                $this->logwarning("read $object is not complete : missing DNA");
	    }
            unless ($readhash->{f1}) {
                $this->logwarning("read $object is not complete : missing Base Quality");
   	    }
            $missed++;
        }        
        else {
            my $Read = $readhash->{Read};
# transfer the DNA; remove all blanks
            $readhash->{SQ} =~ s/\s+//g;
            $Read->setSequence($readhash->{SQ});
# transfer quality data as an array of integers
            $readhash->{AV} =~ s/^\s+|\s+$//; # remove leading/trailing blanks
            my @quality = split /\s+/, $readhash->{AV};
            $Read->setBaseQuality([@quality]);
# special : check that primer is defined
            $Read->setPrimer("Unknown_primer") unless $Read->getPrimer();
# add the readname and Read object to the buffer of the super class
            if ($this->addReadToList($object,$Read)) {
                $count++;
            }
            else {
                $missed++;
            }
        }
    }

    undef %reads; # release memory

    $this->loginfo("$count reads parsed, $missed reads skipped");

    return $count;
}

# storage and retrieval of reads

sub addReadToList {
    my $this = shift;
    my ($name,$read) = @_; 

    $this->{readlist} = {} unless defined $this->{readlist};

    my $readhash = $this->{readlist};

    $readhash->{$name} = $read;
}

sub getReadNamesToLoad {
# overides superclass method
    my $this = shift;

    $this->{readlist} = {} unless defined $this->{readlist};

    my $readhash = $this->{readlist};

    my @readnames = keys %$readhash;

    return [@readnames];
}

sub getReadByName {
# overides superclass method
    my $this = shift;
    my $name = shift;

    $this->{readlist} = {} unless defined $this->{readlist};

    my $readhash = $this->{readlist};

    return $readhash->{$name};
}

#------------------------------------------------------------------------

1;
