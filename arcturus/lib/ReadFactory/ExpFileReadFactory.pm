package ExpFileReadFactory;

use strict;

use ReadFactory;

use Read;

use FileHandle;

our (@ISA);

@ISA = qw(ReadFactory);

#------------------------------------------------------------
# constructor takes directory information where to find files
#------------------------------------------------------------

sub new {

    my $class = shift;

# invoke the constructor of the superclass

    my $this = $class->SUPER::new();

# parse the input parameters

    my ($root, $subdir, $includes, $excludes, $limit, $filter);

    while (my $nextword = shift) {

        $root = shift if ($nextword eq 'root');

        $subdir   = shift if ($nextword eq 'subdir');

        $includes = shift if ($nextword eq 'include');

        $excludes = shift if ($nextword eq 'exclude');

        $limit  = shift if ($nextword eq 'limit');

        $filter = shift if ($nextword eq 'readnamelike');

        $this->setLogging(shift) if ($nextword eq 'log');
    }

# set up buffer for possibly included files

    my $includeset;
    if (ref($includes) eq 'ARRAY') {
        $includeset = {};
        while (my $readname = shift @$includes) {
            $includeset->{$readname} = 1;
        }
    }
    elsif ($includes) {
        die "ExpFileReadFactory constructor expects an 'include' array";
    }     

# set up buffer for possibly excluded or included files

    my $excludeset = {};
    if (ref($excludes) eq 'ARRAY') {
        while (my $readname = shift @$excludes) {
            $excludeset->{$readname} = 1;
        }
    }
    elsif ($excludes) {
        die "ExpFileReadFactory constructor expects an 'exclude' array";
    }     

# scan the directories and sub dir and build a list of filenames

    $this->expFileFinder($root,$subdir,$limit,$excludeset,$includeset,$filter);

    return $this;
}
 
#------------------------------------------------------------
# scan directories and build list of exp file names 
#------------------------------------------------------------

sub expFileFinder {

    my $this = shift;
    my $root    = shift;
    my $subdir  = shift; # subdirectory (filter)
    my $limit   = shift || 1000000;
    my $exclude = shift;
    my $include = shift;
    my $filter  = shift; # filename filter

# set up a list of directories to scan for files

    my @dirs;
    $this->loginfo("Scanning root directory $root");
    if (opendir ROOT, $root) {
        $subdir = "0" unless defined($subdir);
        my @files = readdir ROOT;
        foreach my $file (@files) {
            next unless (-d "$root/$file");
            next unless ($file =~ /\w*$subdir\w*/);
            push @dirs, "$root/$file";
        }
        closedir ROOT;
    }
    else {
        $this->logerror("Failed to open directory $root");
    }

    $this->logerror("No (sub)directories matching description") unless @dirs;

# go through each directory in turn to collect files that look like exp files

# print "directories @dirs\n\n"; return;
    my $counted = 0;
    my @rejects;
    foreach my $dir (@dirs) {
	$this->loginfo("Scanning directory $dir");
        if (opendir DIR, $dir) {
            my @files = readdir DIR;
            foreach my $file (@files) {
                last if ($counted >= $limit);
                next if (-d $file);
                next if ($exclude && $exclude->{$file});
                next if ($filter && $file !~ /\w*$filter\w*/);
# accept the file if it is in the include list; else do standard test
                if ($include && defined($include->{$file})) {          
# print "accepted: $file \n";
                   $this->addReadToList($file,"$dir/$file");
                }
                elsif ($include) {
                    next;
                }
                elsif ($file !~ /SCF$/) {
		    my $accept = 1;
		    $accept = 0 unless ($file =~ /[\w\-]+\.[a-z]\d[a-z]\w*/);
                    if ($accept) {
#print "accepted: $file \n";
                        $this->addReadToList($file,"$dir/$file");
                        last if (++$counted >= $limit);
                    }
                    elsif ($file !~ /fn\./) {
                        push @rejects,$file;
                    }
                }
            }
            closedir DIR;
            last unless ($counted < $limit);
        }               
        else {
            $this->logwarning("Failed to open directory $dir");
        }
    }

    $this->{rejects} = [@rejects] if @rejects;
}

sub getRejectedFiles {
    my $this = shift;

    return $this->{rejects};
}
 
#------------------------------------------------------------
# build Read from Exp file stored in the superclass list
#------------------------------------------------------------
 
sub getNextRead {
# pick up the Read reference from the auxiliary data
    my $this = shift;
 
    my $readname = $this->getCurrentReadName(); 

    my $filename = $this->getNextReadAuxiliaryData(); # returns full file name
 
# parse the file and build Read instance
 
    my $read = $this->expFileParser($readname, $filename); # returns Read object
 
    if (!defined($read) or ref($read) ne 'Read') {
                                                                               
        $this->logerror("Cannot build read $readname from $filename");
                                                                               
        return undef;
    }
    else {
        return $read;
    }
}

sub expFileParser {
# private method: parse experiment file
    my $this = shift;
    my $readname = shift;
    my $filename = shift || return undef;

# open the file

    my $READ = new FileHandle($filename,'r') || return undef;

# create a new Read instance

    my $read = new Read($readname);

    my $line = 0;
    undef my $sequence;
    undef my $quality;

# parse the file and store data directly in Read or in a temporary hash

    my $record;
    my %item;
    my $chemistry;
    while (defined($record = <$READ>)) {

# decode data in data file and test

        $line++;
        chomp $record; 
        if ($record =~ /^SQ\s*$/) {
            $sequence = 1;
        } 
        elsif ($record =~ /^\/\/\s?$/) {
            $sequence = 0;
        }
# reading the sequence data
        elsif ($record =~ /^\s+(\S+.*\S?)\s?$/ && $sequence) {
            $item{SQ} .= $1.' ';
        }
# reading the quality data
        elsif ($record =~ /^AV\s+(\d.*?)\s?$/) {
            $item{AV} .= $1.' ';
        }
# readname
        elsif ($record =~ /^ID\s+(\S+)\s?$/) {
	    $read->setReadName($1);
        }
# template
        elsif ($record =~ /^TN\s+(\S+)\s?$/) {
	    $read->setTemplate($1);
        }
# date
        elsif ($record =~ /^DT\s+(\S+)\s?$/) {
            my $asped = $1;
            $asped =~ s/(\b\d\b)/0$1/g;
	    $read->setAspedDate($asped);
	}
# trace file
        elsif ($record =~ /^LN\s+(\S+)\s?$/) {
            my $traceref = $1;
            my @fparts = split '/',$filename;
            pop @fparts; # remove filename
            my $subdir = pop @fparts;
            $read->setTraceArchiveIdentifier("$subdir/$traceref");
        }
# insert size
        elsif ($record =~ /^SI\s+(\d+)\D*(\d+)\s*$/) {
            $read->setInsertSize([$1,$2]);
        }
# ligation
        elsif ($record =~ /^LG\s+(\S+)\s?$/) {
            $read->setLigation($1);
        }
# clone
        elsif ($record =~ /^CN\s+(\S+)\s?$/) {
            $read->setClone($1);
        }
# primertype
        elsif ($record =~ /^PR\s+(\S+)\s?$/) {
            my $primer = 'Unknown_primer';
            $primer = 'Universal_primer' if ($1 == 1 or $1 == 2);
            $primer = 'Custom' if ($1 == 3 or $1 == 4);
            $read->setPrimer($primer);
        }
# chemistry (often not present)
        elsif ($record =~ /^CH\s+(\S+)\s?$/) {
	     $chemistry = "Dye_primer"     if ($1 == 0);
             $chemistry = "Dye_terminator" if ($1 == 1);
       }
# strand (DR, not ST which is the number of strands, single or double)
        elsif ($record =~ /^DR\s+(\S+)\s?$/) {
            my $strand;
            $strand = 'Forward' if ($1 eq '+');
            $strand = 'Reverse' if ($1 eq '-');
            $read->setStrand($strand);
        }
# basecaller
        elsif ($record =~ /^BC\s+(\S+)\s?$/) {
            $read->setBaseCaller($1);
        }
# quality left
        elsif ($record =~ /^QL\s+(\S+)\s?$/) {
            $read->setLowQualityLeft($1);
        }
# quality right
        elsif ($record =~ /^QR\s+(\S+)\s?$/) {
            $read->setLowQualityRight($1);
        }
# process status
        elsif ($record =~ /^PS\s+(\S.*)$/) {
            $read->setProcessStatus($1);
        }
# concatenate comments
        elsif ($record =~ /^CC\s+(\S.*)$/) { 
            $read->addComment($1);
        }
# treat tag info as a comment too
        elsif ($record =~ /^TG\s+(\S.*)$/) {
            $read->addComment($1);
        }

# everything else is put in the temporary items hash; this includes 
# sequencing and cloning vector data which have to be analysed afterwards

        elsif ($record =~ /^(\w+)\s+(\S*?)\s?$/) {
            my $ritem = $1; 
            my $value = $2;
            $value = '' if ($value =~ /^none$/i);
                $item{$ritem} = $value if ($value =~ /\S/);
        }
# anything remaining has not been recognized
        elsif ($record =~ /\S/) {
            my $warning = "! unrecognized input in file $filename, line $line\n";
            $this->logwarning($warning.$record);
       }
    }
# close the file
    $READ->close();

# now process data collected in the temporary hash

    if (defined($item{SQ})) {
# sequence, remove all blanks
        $item{SQ} =~ s/\s+//g;
# replace dashes by N to conform to CAF convention
        $item{SQ}  =~ s/\-/N/g;
        $read->setSequence($item{SQ});
    }

    if (defined($item{AV})) {
# quality data, split into an array and pass its reference
        $item{AV} =~ s/^\s+|\s+$//g; # remove leading/trailing blanks
        my @quality = split /\s+/,$item{AV};
        $read->setQuality([@quality]);
    }

    if (defined($item{SV}) || defined($item{SL}) || defined($item{SR})) {
# sequencing vector
        if (defined($item{SL})) {
            $read->addSequencingVector([$item{SV},1,$item{SL}]);
        }
        if (defined($item{SR})) {
            my $length = $read->getSequenceLength();
            $read->addSequencingVector([$item{SV},$item{SR},$length]);
        }
        if (!defined($item{SL}) && !defined($item{SR})) {
            $read->addComment("Absent sequencing vector $item{SV}");
        }
    }

    if (defined($item{CV}) || defined($item{CL}) || defined($item{CR})) {
# cloning vector
        if (defined($item{CL})) {
            $read->addCloningVector([$item{CV},1,$item{CL}]);
        }
        if (defined($item{CR})) {
            my $length = $read->getSequenceLength();
            $read->addCloningVector([$item{CV},$item{CR},$length]);
        }
        if (!defined($item{CL}) && !defined($item{CR})) {
            $read->addComment("Absent cloning vector $item{CV}");
        }
    }

# finally, compare chemistry info, if any, with file extension code, if any

    if ($readname =~ /\S+\.\w\d(\w)\w*$/) {
# looks like a standard Sanger name
        my $code = $1;
        my $filechtype;
        if ($code =~ /\b(c|d|f|k|n|t)\b/) {
            $filechtype = "Dye_terminator";
        }
        elsif ($code =~ /\b(b|e|m|p)\b/) {
            $filechtype = "Dye_primer";
        }
# test against possible earlier definition
        if (defined($chemistry) && defined($filechtype)) {
            if ($chemistry ne $filechtype) {
                $this->logerror("Incompatible chemistry information in file $filename: $filechtype against $chemistry");
                $chemistry = $filechtype; # adopt extension value
            }            
        }
        elsif (defined($filechtype)) {
            $chemistry = $filechtype;
        }
    }
# here chemistry should be defined
    $read->setChemistry($chemistry);

# test number of fields read

    if (keys (%item) == 0) {
        $this->logerror("! File $filename contains no intelligible data");
        undef $read;
    }

    return $read;
}

#------------------------------------------------------------

1; 
