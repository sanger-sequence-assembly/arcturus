package CAFReadFactory;

use strict;

use ReadFactory;

use Read;

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

        $includes = shift if ($nextword eq 'include');

        $excludes = shift if ($nextword eq 'exclude');
    }

# take the filename and process the file completely
     
    die "CAFReadFactory constructor requires a CAF file handle" if !$CAF;

# set up the logging, if any

    $this->setLogging($log) if $log;

# set up buffer for possibly included files

    my $includeset;
    if (ref($includes) eq 'ARRAY') {
        $includeset = {};
        while (my $readname = shift @$includes) {
            $includeset->{$readname} = 1;
        }
    }
    elsif ($includes) {
        die "CAFReadFactory constructor expects an 'include' array";
    }     

# set up buffer for possibly excluded or included files

    my $excludeset = {};
    if (ref($excludes) eq 'ARRAY') {
        while (my $readname = shift @$excludes) {
            $excludeset->{$readname} = 1;
        }
    }
    elsif ($excludes) {
        die "CAFReadFactory constructor expects an 'exclude' array";
    }     

# parse the caf file and populate the buffers of the super class

    $this->CAFFileParser($CAF,$excludeset,$includeset);    

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
    my $exclude = shift;
    my $include = shift;


    undef my %reads; # hash for temporary DNA and Quality data storage

    my $line = 0;
    my $type = 0;
    undef my $pdate;


    my $count = 0;
    my $missed = 0;

    $this->loginfo("Begin reading caf file");

    my $object = '';

    my $record;
    while (defined($record = <$CAF>)) {
        $line++; 
        chomp $record;
        $this->loginfo("Processing line $line") if !($line%100000);
        next if ($record !~ /\S/); # skip empty lines 

        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:?\s*(\S+)/) {
# there is a new object name
            my $item = $1;
#            my $name = $2;
#            if ($object && $object ne $name && $reads{$object} && $dotf) {
#            }             
            $object = $2;
            $type = 0;
# test against readname exclude and include filters
            if (defined($exclude->{$object}) ||
		defined($include) && !defined($include->{$object})) {
                $this->loginfo("read $object ignored");
                next;
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
            $this->loginfo("Contig $object ignored");
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
            elsif ($items[0] =~ /Ins/i) {
                $Read->setInsertSize([$items[1],$items[2]]);
            }
            elsif ($items[0] =~ /Liga/i) {
                $Read->setLigation($items[1]);
            }
            elsif ($items[0] =~ /Seq/i) {
		my ($svleft, $svright, $svname) = $record =~ /^Seq_vec\s+\S+\s+(\d+)\s+(\d+)\s+\"(\S+)\"/;
		$Read->addSequencingVector([$svname, $svleft, $svright]);
            }
            elsif ($items[0] =~ /Pri/i) {
                $Read->setPrimer($items[1]);
            }
            elsif ($items[0] =~ /Str/i) {
                $Read->setStrand($items[1]);
            }
            elsif ($items[0] =~ /Dye/i) {
                $Read->setChemistry($items[1]);
            }
            elsif ($items[0] =~ /Clone_vec/i) {
		my ($cvleft, $cvright, $cvname) = $record =~ /^Clone_vec\s+\S+\s+(\d+)\s+(\d+)\s+\"(\S+)\"/;
		$Read->addCloningVector([$cvname, $cvleft, $cvright]);
            }
            elsif ($items[0] =~ /Clo/i) {
                $Read->setClone($items[1]);
            }
            elsif ($items[0] =~ /Pro/i) {
                $Read->setProcessStatus($items[1]) if ($record !~ /PASS/);
            }
            elsif ($items[0] =~ /Asp/i) {
                $Read->setAspedDate($items[1]);
            }
            elsif ($items[0] =~ /Bas/i) {
                $Read->setBaseCaller($items[1]);
            }
            elsif ($items[0] =~ /Cli/i) {
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

        }
        elsif ($type == 2) {
# store the DNA in temporary buffer, add current record to existing contents
            $reads{$object}->{SQ} .= $record;
        }
        elsif ($type == 3) {
# store the Quality Data
            $record =~ s/\b0(\d)\b/$1/g; # remove '0' from values such as '01' .. 
	    $reads{$object}->{AV} .= $record; 
        }
# register for this object which section has been completed (on key f1, f2, f3)
	if ($type > 0) {
            $reads{$object}->{"f$type"}++;
            $reads{$object}->{last} = $type; # record last flag updated
        }
    }

# okay, here we have a hash of read hashes

    $this->loginfo("CAF file parser finished ($line)");
    my $nr = scalar(keys %reads) + $count + $missed;
 
    $this->loginfo("$nr reads processes ($count, $missed)"); 


    foreach my $object (keys %reads) {

        my $readhash = $reads{$object};

        if (!$readhash->{f1} || !$readhash->{f2} || !$readhash->{f3}) {
            $this->logwarning("read $object is not complete");
            $missed++;
        }        
        else {
            my $Read = $readhash->{Read};
# transfer the DNA
            $Read->setSequence($readhash->{SQ});
# transfer quality data as an array of integers
            $readhash->{AV} =~ s/^\s+|\s+$//; # remove any leading or trailing blanks
            my @quality = split /\s+/, $readhash->{AV};
            $Read->setQuality([@quality]);
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

    $this->loginfo("$count reads loaded, $missed reads skipped");

    return $count;
}



