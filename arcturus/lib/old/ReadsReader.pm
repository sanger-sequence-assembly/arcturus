package ReadsReader;

#############################################################################
#
# Read a standard Sanger format READ from a file
#
#############################################################################

use strict;

use LigationReader;
 use Ligationreader;
use Compress;
use OracleReader;
use ReadsRecall;

my $DEBUG = 0;
my %timehash;

#############################################################################

my $BADGERDIR  = '/usr/local/badger/bin'; 
my $SCFREADDIR = '/usr/local/badger/distrib-1999.0/alpha-bin';
my $SCFREADLIB = '/usr/local/badger/distrib-1999.0/lib/alpha-binaries';
my $GELMINDDIR = '/nfs/disk54/badger/src/gelminder';
my $RECOVERDIR = '/nfs/pathsoft/arcturus/dev/cgi-bin';

my $readbackOnServer = 1;

my $USENEWREADLAYOUT = 0;

my $break;

my $pdate;

#############################################################################

# constructor item new

sub new {
    my $prototype = shift;
    my $readtable = shift; # the reference to the READS database table
    my $DNA       = shift;
    my $schema    = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

# allocate hashes

    $self->{readItems} = {};
    $self->{linkItems} = {};
    $self->{linkNames} = '';

    $self->{uploaded} = []; # reads uploaded (reset at polling point)
    $self->{assembly} = 0;  # assembly for which reads are loaded

# error reporting

    $self->{status} = {};
    my $status = $self->{status};
    $status->{errors}    = 0;
    $status->{warnings}  = 0;
    $status->{diagnosis} = '';
    $status->{report}    = '';

# origin of data

    $self->{dataSource} = 0;
    $self->{fileName}  = '';

# transfer Arcturus Table handle to the class variables

    $self->{READS} = $readtable or die "Missing database handle for READS table";

# spawn the required dictionary tables, if not done earlier

    my $database = $self->{READS}->{database}; 
    $self->{READS}->autoVivify($database,2);

    $self->{READS}->spawn('READMODEL','arcturus',0,1);
    $self->{READS}->spawn('DATAMODEL','arcturus',0,1);

# spawn the PENDING and ASSEMBLY tables

    $self->{PENDING}  = $self->{READS}->spawn('PENDING');
    $self->{ASSEMBLY} = $self->{READS}->spawn('ASSEMBLY','<self>',0,1);

# decide what the organism is

    $self->{SCHEMA} = $schema || $database || die 'Unknown Oracle SCHEMA\n';

# create a handle to the data compression module

    $self->{Compress} = new Compress($DNA); # default encoding string for DNA: 'ACGT- '

# create a handle to the ligation reader

    $self->{LigationReader} = Ligationreader->new();

    $self->{fatal} = 1; # default errors treated as fatal 

# environment

    $self->{CGI} = $ENV{PATH_INFO} || 0; # true for CGI mode

    my $library = $ENV{LD_LIBRARY_PATH} || '';
    $ENV{LD_LIBRARY_PATH} = $SCFREADLIB;
    $ENV{LD_LIBRARY_PATH} .= ':'.$library if ($library !~ /$SCFREADLIB/);

    $break = &break;

    bless ($self, $class);
    return $self;
}

#############################################################################

sub setFatal {
    my $self = shift;
    my $fnew = shift;

    $self->{fatal} = $fnew  if (defined($fnew));
}

#############################################################################

sub newRead {
# ingest a new read from a file, return reference to hash table of entries
    my $self = shift;
    my $file = shift;
    my $type = shift;

    &timer('newRead',0) if $DEBUG; 

# type 0 for standard read; else consensus file

    $self->erase(); # reset status and clear data

    if (defined($file)) {
        $self->readReadData($file)     if !$type;
        $self->newConsensusRead($file) if ($type && $type == 1);
        $self->getOracleRead($file)    if ($type && $type == 2);
    }

    &timer('newRead',1) if $DEBUG; 

    if ($self->{status}->{errors}) {
        return 0;
    } 
    else {
        return $self->{readItems};
    }
}

#############################################################################

sub fetchOracleData {
# builds a set of hashes for the input readnames in specified schema and project
    my $self = shift;

    $self->{OracleReader} = new OracleReader (shift, shift) || return 0; # input SCHEME, PROJECT

    return $self->{OracleReader}->getOracleReads(shift); # input array ref of filenames
}

#############################################################################

sub status {
# query the status of the table contents; define list for diagnosis
    my $self = shift; 
    my $list = shift; # = 0 for summary, > 0 for errors, > 1 for warnings as well
    my $html = shift;

    my $status   = $self->{status};

    my $output;

    if (defined($list)) {
        my $n = keys %{$self->{readItems}};
        $output  = "$self->{fileName}: $n items: ";
        $output .= "<FONT COLOR='blue'>$status->{errors} errors</FONT>, ";
        $output =~ s/blue/red/  if ($status->{errors});
        $output .= "<FONT COLOR='WHITE'>$status->{warnings} warnings</FONT><BR>";
        $output =~ s/WHITE/yellow/  if ($status->{warnings});
        $list-- if (!$status->{errors}); # switch off if only listing of errors
        $output .= "$status->{diagnosis}" if ($list && $status->{diagnosis});
# adapt to HTML or line mode
        if ($html) {
            $output =~ s/\n/<br>/g;
#	    $output .= "<br>$comments<br>\n" if ($comments);
            $output =~ s/(\<br\>){2,}/<br>/ig;
        }
        else {
            $output =~ s/\<br\>/\n/ig;
            $output =~ s/\<[^\>]*\>//g; # remove tags
        }
    }

    return $output, $status->{errors};
}

#############################################################################
# private methods for data input
#############################################################################

sub readReadData {
# reads a Read file from disk
    my $self = shift;
    my $file = shift;

    my $readItems = $self->{readItems};

    my $status = $self->{status};

    my $record;
    if (open(READ,"$file")) {
        $self->{fileName} = $file;
        $self->{dataSource} = 1; # source experiment file
# decode data in data file and test
        my $line = 0;
        undef my $sequence;
        undef my $quality;
        while (defined($record = <READ>)) {
        # read the sequence
            chomp $record; $line++;
            if ($record =~ /^SQ\s*$/) {
                $sequence = 1;
            } 
            elsif ($record =~ /^\/\/\s?$/) {
                $sequence = 0;
            }
        # read the sequence data
            elsif ($record =~ /^\s+(\S+.*\S?)\s?$/ && $sequence) {
                $readItems->{SQ} .= $1.' ';
            }
        # read the quality data
            elsif ($record =~ /^AV\s+(\d.*?)\s?$/) {
                $readItems->{AV} .= $1.' ';
            }
        # concatenate comments (including tags)
            elsif ($record =~ /^[CC|TG]\s+(\S.*?)\s?$/) {
                $readItems->{CC} .= "$break" if ($readItems->{CC});
                $readItems->{CC} .= $1;
                $readItems->{CC} =~ s/\s+/ /; # remove redundant blanks
            }
            elsif ($record =~ /^[TG]\s+(\S.*?)\s?$/) {
# tags have to be stored in separate table READTAGS
#                $readItems->{CC} .= "$break" if ($readItems->{CC});
#                $readItems->{CC} .= $1;
#                $readItems->{CC} =~ s/\s+/ /; # remove redundant blanks
            }
        # read the other descriptors                 
            elsif ($record =~ /^(\w+)\s+(\S.*?)\s?$/) {
                my $item = $1; my $value = $2;
                $value = '' if ($value =~ /HASH/);
# print "item $item  value $value <br>" if ($value =~ /^none$/i);
#                $value = '' if ($value =~ /^none$/i);
                $readItems->{$item} = $value if ($value =~ /\S/);
# print "item $item  value $value <br>";
            }
            elsif ($record =~ /\S/) {
                $status->{diagnosis} .= "! unrecognized input in file $file$break" if (!$status->{diagnosis});
                $status->{diagnosis} .= "  l.$line:  \"$record\"$break";
                $status->{warnings}++;
            }
#          &logger($self,"input line $line: $record");
        }
        close READ;
    # test number of fields read
        if (keys(%$readItems) <= 0) {
            $status->{diagnosis} .= "! file $file contains no intelligible data$break$break";
            $status->{errors}++;
        }

    }
    elsif (!$self->{OracleReader}) {
# the file presumably is not present or is corrupted
        $status->{diagnosis} .= "! file $file cannot be opened: $!$break"; 
        $status->{errors}++;
    }
    else {
# try if there is an Oracle Read
        $self->getOracleRead($file);
    }
}

#############################################################################

sub getOracleRead {
# get read data from Oracle into $readItem hash
    my $self = shift;
    my $read = shift;

    my $readItems = $self->{readItems};

    my $status = $self->{status};

    if (defined($self->{OracleReader})) {
# try to read the data from a previously built Oracle set (see ADB_get_caf)
        if (my $hash = $self->{OracleReader}->readHash($read)) {
# foreach my $key (keys %$hash) { print "key $key  :  $hash->{$key} <br>";} print "<br>";

            $self->{fileName}  = $read;
            $read =~ s/\S+\///g; # chop of any directory name
            $readItems->{ID} = $read;
            $readItems->{SQ} = $hash->{DNA};
            $readItems->{SQ} =~ s/n/-/ig;
            $readItems->{AV} = $hash->{BaseQuality};
            $readItems->{RPS} = 0; # read-parsing error code
            my @fields = split /\n/,$hash->{Sequence};
            foreach my $field (@fields) {
# print "$field $break";
                my @items = split /\s+/,$field;
                if ($items[0] =~ /Temp/i) {
                    $readItems->{TN} = $items[1];
                }
                elsif ($items[0] =~ /Ins/i) {
                    $readItems->{SI} = "$items[1]..$items[2]";
                }
                elsif ($items[0] =~ /Liga/i) {
                    $readItems->{LG} = $items[1];
                }
                elsif ($items[0] =~ /Seq/i) {
#print "seq: field '$field' @items <br>";
                    $readItems->{SL} = $items[3] if ($items[2] <= 1);
                    $readItems->{SL}++           if ($items[2] == 0);
                    $readItems->{SR} = $items[2] if ($items[2]  > 1);
                    $field =~ s/Seq.*\d+\s+\d+\s+(\S.*)$/$1/;
                    $field =~ s/[\"\']//g;
                    $readItems->{SV} = $field;

                }
                elsif ($items[0] =~ /Pri/i) {
                    $readItems->{PR} = $items[1];
                }
                elsif ($items[0] =~ /Str/i) {
                    $readItems->{ST} = $items[1];
                }
                elsif ($items[0] =~ /Dye/i) {
                    $readItems->{CH} = $items[1];
                }
                elsif ($items[0] =~ /Clone_vec/i) {
                    $readItems->{CV} = $items[1];
                }
                elsif ($items[0] =~ /Clo/i) {
                    $readItems->{CN} = $items[1];
                }
                elsif ($items[0] =~ /Pro/i) {
                    $readItems->{PS} = $items[1];
                }
                elsif ($items[0] =~ /Asp/i) {
                    $readItems->{DT} = $items[1];
                }
                elsif ($items[0] =~ /Bas/i) {
                    $readItems->{BC} = $items[1];
                }
                elsif ($items[0] =~ /Cli/i) {
                    $readItems->{QL} = $items[2];
                    $readItems->{QR} = $items[3];
                }
                elsif ($items[0] =~ /SCF_File/i) {
                    $readItems->{SCF} = $items[1];
                }
            }
            $self->{dataSource} = 2;
        }
        else {
            $status->{diagnosis} .= "! No data found in Oracle hash$break";
            $status->{errors}++;
        }
#	print &list(0,1,1);
    }
}

#############################################################################

sub newConsensusRead {
# reads a consensus file from disk and package it as a "read"
    my $self = shift;
    my $file = shift;

    my $readItems = $self->{readItems};

    my $status = $self->{status};

    my $record;
    if (open(READ,"$file")) {
        $self->{fileName} = $file;
        $self->{fileName} =~ s/\S+\///g;
        $readItems->{ID} = $self->{fileName};
        $readItems->{CC} = 'Consensus Read ';     
    # decode data in data file and test
        my $line = 0;
        undef my $sequence;
        undef my $quality;
        while (defined($record = <READ>)) {
            chomp $record; $line++;
            next if (!($record =~ /\S/));
            if ($record =~ /[^atcgnATCGN-\s]/) {
                $record =~ s/\s+//g;
                $readItems->{CC} .= $record;
                next;
            }
            $record =~ s/\s//g; # no blanks
            $readItems->{SQ} .= $record;
            $readItems->{SQ} =~ tr/A-Z/a-z/; # ensure lower case throughout
        }
        close READ;
    # create a dummy quality sequence of 1 throughout
       ($readItems->{AV} = $readItems->{SQ}) =~ s/(.)/ 1/g;
        $readItems->{AV} =~ s/^\s+//; # remove the leading blank
    # test number of fields read
        if (keys(%$readItems) <= 0) {
            $status->{diagnosis} .= "! file $file contains no intelligible data$break$break";
            $status->{errors}++;
            $status->{diagnosis} .= "! file $file contains no intelligible data$break$break";
            $status->{errors}++;
        }
        else {
    # defined other required read items
            $readItems->{DR}  = ' '; # direction unspecified
            $readItems->{ST}  = 'z';
            my @timer = localtime;
            $timer[4]++; # to get month
            $timer[5] += 1900; # & year
            $readItems->{DT}  = "$timer[5]-$timer[4]-$timer[3]";
            $readItems->{QL}  = 0;
            $readItems->{QR}  = length($readItems->{SQ})+1;
            $readItems->{PR}  = 5;  # undefined
        }
    }
}

#############################################################################

sub erase {
# clear read item hash and error status
    my $self = shift;

    my $readItems = $self->{readItems};
    undef %$readItems;

    $self->{dataSource} = 0; # default unknown
    $self->{fileName}  = '';

    my $status = $self->{status};
    $status->{errors}    = 0;
    $status->{warnings}  = 0;
    $status->{diagnosis} = '';
    $status->{report}    = '';
}

#############################################################################

sub makeLinks {
# store reads keys and corresponding column names
# this method builds the %linkItems hash and the $linkNames string
    my $self = shift;

# get the columns of the READS table (all of them) and find the reads key

    my $linkItems = $self->{linkItems};

    my $status = $self->{status};

    if (!keys %$linkItems) {
        $status->{errors} = 0;
        $status->{diagnosis} = '';
# initialize the correspondence between tags and column names
        my $READMODEL = $self->{READS}->getInstanceOf('arcturus.READMODEL');
        if (!$READMODEL) {
            $status->{diagnosis} = "READMODEL handle NOT found$break";
            $status->{errors}++;
        }
        else {
            my $hashes = $READMODEL->associate('hashrefs','where',1,-1);
# build internal linkItem hash
            if (ref($hashes) eq 'ARRAY') {
                foreach my $hash (@$hashes) {
                    my $column = $hash->{'column_name'};
                    $linkItems->{$column} = $hash->{'item'};
                }
            }
            else {
                $status->{diagnosis} .= "READMODEL cannot be read$break";
                $status->{errors}++;
            }
        }
        return if $status->{errors};
    }

# build the link names string

    $self->{linkNames} = '';
    foreach my $key (keys(%$linkItems)) {
        $self->{linkNames} .= '|' if $self->{linkNames};
        $self->{linkNames} .= $linkItems->{$key};
    }
# add some miscellaneous ones
    $self->{linkNames} .= '|SI|SCF';
}

#############################################################################
# public methods for access and testing
#############################################################################

sub enter {
# enter read item into internal %readItem hash
    my $self  = shift;
    my $entry = shift; # read item key or hash
    my $value = shift; # item value or data source

    my $linkNames = $self->{linkNames};
    $self->makeLinks() if !$linkNames;

    my $readItems = $self->{readItems};

    my $status = $self->{status};

    my $estatus = '';
    if (ref($entry) eq 'HASH') {
        $self->erase; # clear current read data
        foreach my $item (keys %$entry) {
            $status->{diagnosis} .= $self->enter($item,$entry->{$item});
        }
        $self->{dataSource} = $value || 0;
        $status->{errors}++ if $status->{diagnosis};
        $estatus = $status->{diagnosis};
    }
    elsif ($entry =~ /^\b$linkNames\b/ && defined($value)) {
        $readItems->{$entry} = $value;
    }
    elsif ($entry =~ /^\b$linkNames\b/) {
        delete $readItems->{$entry};
    }
    else {
        $estatus = "Attempt to enter invalid read item $entry $break";
    }
# print "enter $entry $value status = $estatus $break" if (ref($entry) ne 'HASH');
    return $estatus;
}

#############################################################################

sub insertRead {
# load a hash with read data, perform tests and insert the data into the database
    my $self = shift;
    my $hash = shift; # the read hash
    my $opts = shift; # the options hash

#    my $READS = $self->{READS};
#print "enter insertRead $break";

    my %options = (sencode => 99, qencode => 99, readback => 1,
                   dataSource => 1, addToPending => 0); # assembly?
    $self->{READS}->importOptions(\%options, $opts);
    my $inserted = 0;

    $self->erase;
    $self->enter($hash, $options{dataSource});

# test the contents

    $self->format;
    $self->ligation;
    $self->strands;
    $self->chemistry;

# check possible error status ...

    my ($summary, $errors) = $self->status(2,0);

#print "summary $summary";

    if ($errors) {
        $errors = "Contents error(s) for putRead: $summary\n";
    }
# encode and dump the data
    elsif ($errors = $self->encode($options{sencode}, $options{qencode})) {
        $errors = "Encode error status in putRead: $errors\n";
    }

    elsif (!($inserted = $self->insert($options{addToPending}))) {
# get error information
       ($summary, $errors) =  $self->status(2,0);
        $errors = "Failed to insert read; $summary, $errors\n";
    }

    elsif ($options{readback} && ($errors = $self->readback)) {
        $errors = "Readback error status in putRead: $errors\n";
    }

# note: rollback in multi mode inserts is not applicable
    $self->rollBack($errors,'SESSIONS'); # undo any changes to dictionary tables if errors
    
#print "$break$break";

    return $inserted; # e.g. number of read items inserted
}

#############################################################################

sub cafFileReader {
# import reads from a caf file, load them one by one and insert into the database
    my $self       = shift;
    my $filename   = shift; # full caf file name
    my $opts       = shift;

$DEBUG=0;

    my $READS = $self->{READS};
    my %options = (nrOfReads => 1000, maxLines => 0  , list => 1000000,
                   ignoreLoaded => 1, ignoreMask => 0, assembly => 1,
                   sencode => 99    , qencode => 99  , readback => 1,
                   addToPending => 0, dataSource => 3, test => 0);
    $READS->importOptions(\%options, $opts);

    undef my %ignore;
    if ($options{ignoreLoaded}) {
        my $where = '1=1';
        $where = "readname like '$options{ignoreMask}'" if $options{ignoreMask};
        my %qoptions = (returnScalar => 0, traceQuery => 0);
        my $loaded = $READS->associate('readname','where',$where,\%qoptions);
        print "query status $READS->{lastQuery} $READS->{qerror} $break" if $options{test};
        my $nr = @$loaded; 
        if ($options{list}) {
            print "$nr previously loaded reads ";
            print "(mask $options{ignoreMask}) " if $options{ignoreMask};
            print "$break";
        }
        foreach my $name (@$loaded) {
            $ignore{$name}++;
        }
        return 0 if ($options{test} > 1);}
    

    my $list = $options{list};
    my $maxLines = $options{maxLines};
    my $plist = $list; $plist = 0 if ($list == 1);
    if ($maxLines) {
        $plist = int(log($maxLines)/log(10));
        $plist = $plist - 1 if ($plist > 1);
        $plist = int(exp($plist*log(10))+0.5);
    }

    undef my %reads; # hash of array index keyed on readname
    print STDOUT "file to be opened: $filename ..." if $list;
    open (CAF,"$filename") || die "cannot open $filename";
    print STDOUT "... DONE $break" if $list;

    my $line = 0;
    my $type = 0;
    undef my $date;

    undef @{$self->{uploaded}};
# if assembly is defined, test if it is a legal (name or number)
    if (!$self->fingerAssembly($options{assembly})) {
	return 0; # or with abort on error flag? 
    }

    print "Reading caf file$break" if $list;

    my $record;
    my $object = '';
    my $truncated = 0;
    while (defined($record = <CAF>)) {
        $line++; 
        chomp $record;
        print STDOUT "Processing line $line$break" if ($plist && ($line == 1 || !($line%$plist)));
        next if ($record !~ /\S/);
# print "$record $break";
        if ($maxLines && $line > $maxLines) {
            print STDOUT "Scanning terminated because of line limit $maxLines$break";
            $truncated = 1;
            $line--;
            last;
        }

        my $nrObjects = 0;
        if ($record =~ /^\s*(Sequence|DNA|BaseQuality)\s*\:?\s*(\S+)/) {
# retrieve the readname
            my $item = $1;
            $object = $2;
            $type = 0;
            print "read $object ignored $break" if ($options{test} && $ignore{$object});
            next if ($ignore{$object});
            $type = 1 if ($item eq 'Sequence');
            $type = 2 if ($item eq 'DNA');
            $type = 3 if ($item eq 'BaseQuality');
# allocate a hash for the read if it is a newly encountered readname

            if (!defined($reads{$object})) {
# add next object to hash list
                my $nreads = scalar(keys %reads);
                if ($nreads < $options{nrOfReads}) {
                    my $hash = {};
                    $hash->{ID} = $object;
                    $reads{$object} = $hash;
                }
                else {
                    $type = 0;
                }
            }
            next;
        }

        if ($record =~ /Is_contig|\bpadded\b/) {
            $type = 0; # ignore contigs and padded data
            delete $reads{$object};
            next;
        }

        if ($record =~ /Is_read/) {
            next;
        }        
          
        if ($type == 1) {
# decode the read data
            $record =~ s/^\s+|\s+$//g;
            my @items = split /\s/,$record;
            if ($items[0] =~ /Temp/i) {
                $reads{$object}->{TN} = $items[1];
            }
            elsif ($items[0] =~ /Ins/i) {
                $reads{$object}->{SI} = "$items[1]..$items[2]";
            }
            elsif ($items[0] =~ /Liga/i) {
                $reads{$object}->{LG} = $items[1];
            }
            elsif ($items[0] =~ /Seq/i) {
#print "seq: field '$field' @items <br>";
                $reads{$object}->{SL} = $items[3] if ($items[2] <= 1);
                $reads{$object}->{SL}++           if ($items[2] == 0);
                $reads{$object}->{SR} = $items[2] if ($items[2]  > 1);
                if ($record =~ s/Seq.*\d+\s+\d+\s+(\S.*)$/$1/) {
                    $record =~ s/[\"\']//g;
                    $reads{$object}->{SV} = $record;
                }
            }
            elsif ($items[0] =~ /Pri/i) {
                $reads{$object}->{PR} = $items[1];
            }
            elsif ($items[0] =~ /Str/i) {
                $reads{$object}->{ST} = $items[1];
            }
            elsif ($items[0] =~ /Dye/i) {
                $reads{$object}->{CH} = $items[1];
            }
            elsif ($items[0] =~ /Clone_vec/i) {
                $reads{$object}->{CV} = $items[1];
            }
            elsif ($items[0] =~ /Clo/i) {
                $reads{$object}->{CN} = $items[1];
            }
            elsif ($items[0] =~ /Pro/i) {
                $reads{$object}->{PS} = $items[1] if ($record !~ /PASS/); 
            }
            elsif ($items[0] =~ /Asp/i) {
                $reads{$object}->{DT} = $items[1];
            }
            elsif ($items[0] =~ /Bas/i) {
                $reads{$object}->{BC} = $items[1];
            }
            elsif ($items[0] =~ /Cli/i) {
                $reads{$object}->{QL} = $items[2];
                $reads{$object}->{QR} = $items[3];
            }
            elsif ($items[0] =~ /SCF_File/i) {
                $reads{$object}->{SCF} = $items[1] if ($items[1] !~ /\.gz|zip|tar/);
                if (!$reads{$object}->{DT}) {
                    if ($items[1] =~ /(\d{4})\W(\d{1,2})\W(\d{1,2})\D/) {
                        $reads{$object}->{DT} = sprintf ("%04d-%02d-%02d",$1,$2,$3);
                        $pdate = $reads{$object}->{DT};
                    } 
		    elsif ($items[1] =~ /(\d{1,2})\W(\d{1,2})\W(\d{4})\D/) {
                        $reads{$object}->{DT} = sprintf ("%04d-%02d-%02d",$1,$2,$3);
                        $pdate = $reads{$object}->{DT};
                    }
                    elsif ($pdate) {
                        $reads{$object}->{DT} = $pdate;
                    }
                    else {
#			print "No date in SCF file $record $break";
                    }
                }
            }

        }
        elsif ($type == 2 && $reads{$object}) {
# store the DNA
	    $reads{$object}->{SQ} .= $record; 
        }
        elsif ($type == 3 && $reads{$object}) {
# store the Quality Data
            $record =~ s/\b0(\d)\b/$1/g; # remove '0' from values such as '01' .. 
	    $reads{$object}->{AV} .= $record; 
        }
    }

# okay, here we have a hash of read hashes

    print "Scanning file $filename finished ($line) $break"    if $list;
    my $nr = keys %reads; print "$nr read hashes build $break" if $list; 


    my $count = 0;
    my $missed = 0;
    foreach my $name (keys %reads) {

	if ($options{test}) {
            print "${break}New read $name "; 
            my @keys = keys %{$reads{$name}}; 
            print "keys: @keys $break";
            print "quality: $reads{$name}->{AV}$break";
        }
        elsif ($self->insertRead($reads{$name},\%options)) {
            push @{$self->{uploaded}}, $name;
            $count++;
        }
        else {
            $missed++;
        }
    }

    undef %reads; # release memory

    print "$count reads loaded, $missed reads skipped $break";

# update ORGANISMS table

    $READS->flush(1); # flush all

    return $count;
}

#############################################################################

sub fingerAssembly {
# identify / test the assembly number / name; store the assembly number
    my $self = shift;
    my $info = shift; # the name or number

    my $ASSEMBLY = $self->{ASSEMBLY};

    my $success = 0;
    if (!$info) {
# default to BLOB (1)
        $self->{assembly} = 1;
    }
# try to identify the assembly; first try assembly name
    elsif (my $anmbr = $ASSEMBLY->associate('assembly',$info,'assemblyname')) {
        $self->{assembly} = $anmbr;
        $success = 1;
    }
# or test a number
    elsif (my $aname = $ASSEMBLY->associate('assemblyname',$info,'assembly')) {
        $self->{assembly} = $info;
        $success = 1;
    }
    else {
# the assembly could not be identified: default to 1, but return 0
        $self->{status}->{diagnosis} .= "Assembly '$info' NOT identified$break";
        $self->{assembly} = 1;
    }

    return $success;
}

#############################################################################

sub housekeeper {
# update counters in ORGANISMS and ASSEMBLY tables after a loading session
    my $self = shift;
    my $user = shift;

print "enter housekeeper $break";

    my $loaded = $self->{uploaded}; # array of readnames in previous loading actions
    return if !@$loaded;

#print "loaded @$loaded $break";

    my $READS = $self->{READS};

    if (my $assembly = $self->{assembly}) {
# if assembly specified (and valid), add assembly info to R2A and ASSEMBLY table
        my $R2A = $READS->spawn('READS2ASSEMBLY');
        $R2A->setMultiLineInsert(500);
# identify the read_ids for the loaded reads
        my %roptions = (traceQuery => 0, returnScalar => 0);
# go through the list in blocks (to accommodate query size buffer of MySQL client)
        my $blocksize = 10000;
        while (@$loaded) {
            undef my @temp;
            $blocksize = @$loaded if ($blocksize > @$loaded);
print "next block $blocksize $break";
            for (my $i = 0 ; $i < $blocksize ; $i++) {
                push @temp, shift(@$loaded);
            }
            my $rids = $READS->associate('read_id',\@temp,'readname',\%roptions);
#print "rids : $rids,  @$rids $break"; 
# add the reads to this assembly
            foreach my $read (@$rids) {
                $R2A->newrow('read_id',$read,'assembly',$assembly);
            }
        }
        $R2A->flush(1);
# count all reads in this assembly
        my $areads = $R2A->count("assembly=$assembly");
print "assembly $assembly reads counted: $areads $break";
        my $ASSEMBLY = $READS->spawn('ASSEMBLY');
        $ASSEMBLY->update('reads',$areads,'assembly',$assembly);
        $ASSEMBLY->update('status','loading','assembly',$assembly);
        $ASSEMBLY->signature($user,'assembly',$assembly);
        if ($ASSEMBLY->associate('progress',$assembly,'assembly') eq 'other') {
            $ASSEMBLY->update('progress','in shotgun','assembly',$assembly);
        }
    }

    my $nreads = $READS->count(0);
    my $npends = $self->{PENDING}->count(0);
    my $database = $READS->{database};
print "updating organisms $break";
    my $organisms = $READS->spawn('ORGANISMS','arcturus');
    $organisms->update('reads_loaded' ,$nreads,'dbasename',$database);
    $organisms->update('reads_pending',$npends,'dbasename',$database);
    $organisms->signature($user,'dbasename',$database);

    $self->{assembly} = 0;
}

#############################################################################

sub list {
# list current data
    my $self = shift;
    my $html = shift;
    my $full = shift; # 0: status only, 1: add contents of read, >1: plus analysis

    undef my $result;

    my $tag = "\n";
    $tag = "<br>" if ($html);

    $result = "${tag}Contents of read $self->{fileName}:$tag$tag";

    my $readItems = $self->{readItems};
    foreach my $key (sort keys (%$readItems)) {
        $result .= "$key: $readItems->{$key}$tag" if ($key ne 'AV' && $key ne 'SQ');
        $result .= "$key: $readItems->{$key}$tag" if ($key eq 'SQ' && !$readItems->{SCM});
        $result .= "$key: $readItems->{$key}$tag" if ($key eq 'AV' && !$readItems->{QCM});
    }

    undef $result if ($full < 1);
    my ($status, $error) = &status($self,2,$html);
    $result .= $status;

    $result .= $self->{status}->{report}.$tag if ($full > 1);

    return $result;
}

#############################################################################
# contents testing
#############################################################################

sub format {
#  Testing for standard Sanger format (error sets bit 1 or 2)
    my $self = shift;

# only test if data originate from a flat file

    my $readItems = $self->{readItems};

    my $status = $self->{status};

    if ($self->{dataSource} == 1 && $self->{fileName}) {

        if ($self->{fileName} !~ /$readItems->{ID}/) {
            $status->{diagnosis} .= "!Mismatch between filename $self->{fileName} and ";
            $status->{diagnosis} .= "read name $readItems->{ID}$break";
# recover if mismatch is a 1 replaced by 'l' in suffix 
            foreach my $key (keys %$readItems) {
                $readItems->{$key} =~ s/(\.\w)l(\w)/${1}1$2/;
  	    }
            $readItems->{RPS} += 2; # error on read ID
            $status->{warnings}++ if (!$self->{fatal});
            $status->{errors}++   if  ($self->{fatal});
        }
        elsif ($readItems->{ID} ne $readItems->{EN}) {
            $status->{diagnosis} .= "! ID and EN mismatch in $readItems->{ID}$break";
            $readItems->{RPS} += 1; # flag mismatch            
            $status->{warnings}++; # what about outside data ?
        }
        elsif ($readItems->{ID} !~ /$readItems->{TN}/) {
            $status->{diagnosis} .= "! ID and TN mismatch in $readItems->{ID}$break";
            $readItems->{RPS} += 1; # flag mismatch
            $status->{warnings}++;
        }
    }
# for other input, define a readFileName
    elsif ($readItems->{ID}) {
        $self->{fileName} = $readItems->{ID};
    }
# missing read ID
    else {
        $status->{diagnosis} .= "! Missing Read Name$break";
        $status->{errors}++; 
    }

# test presence of sequence and quality data

    if (!$readItems->{SQ}) {
        $status->{diagnosis} .= "! Missing Sequence data in $self->{fileName}$break";
        $status->{errors}++;
    }    
    if (!$readItems->{AV}) {
        $status->{diagnosis} .= "! Missing Quality data in $self->{fileName}$break";
        $status->{errors}++;
    }    

# process comment info

    return if !$USENEWREADLAYOUT;

    if ($readItems->{CC} && $readItems->{CC} =~ /\S/) {
        my $COMMENTS = $self->{READS}->getInstanceOf('<self>','COMMENTS');
        if (!$COMMENTS->counter('comment',$readItems->{CC},0)) {
            $status->{diagnosis} .= "! Error in update of COMMENTS (read: $readItems->{CC})$break";
            $status->{errors}++;  
        }
    }
}
# error reporting coded as:

# bit 1  : mismatch between EN or TN and ID
# bit 2  : error in read ID (mismatch with fileneme; possibly recoverde)

#############################################################################

sub ligation {
# get ligation data and test against database tables VECTORS and LIGATIONS
    my $self = shift;

    &timer('ligation',0) if $DEBUG; 

# get the database handle to the LIGATIONS and SEQUENCEVECTOR tables

    my $READS = $self->{READS};
    my $LIGATIONS = $READS->getInstanceOf('<self>.LIGATIONS')       or die "undefined LIGATIONS";
    my $SQVECTORS = $READS->getInstanceOf('<self>.SEQUENCEVECTORS') or die "undefined SEQUENCEVECTORS";
    my $CLVECTORS = $READS->getInstanceOf('<self>.CLONINGVECTORS')  or die "undefined CLONINGVECTORS";
    my $CLONES    = $READS->getInstanceOf('<self>.CLONES')          or die "undefined CLONES";

    $self->logger("** Test or find Ligation Data $break"); 

    my $readItems = $self->{readItems};

    my $status = $self->{status};

    if (my $rdsi = $readItems->{SI}) {
        my ($vl, $vu) = split /\s+|\.+/, $rdsi;
        if ($vl && $vu) {
            $vl *= 1000; $vl /= 1000 if ($vl >= 1.0E4);
            $vu *= 1000; $vu /= 1000 if ($vu >= 1.0E4);
            $readItems->{SIL} = $vl;
            $readItems->{SIH} = $vu;   
        } else {
            $status->{diagnosis} .= "! Invalid Sequence Vector insertion length (SI = $rdsi)$break";
            $readItems->{RPS} += 4; # bit 3
            $status->{warnings}++ if (!$self->{fatal});
            $status->{errors}++   if  ($self->{fatal});
        }
    } else {
        $status->{diagnosis} .= "! No Sequencing Vector insertion length (SI) specified$break";
        $readItems->{RPS} += 8; # bit 4
        $status->{warnings}++;
    }

# test and possibly update (sequence) vector table (tblv)

    undef my $svector;
    if ($readItems->{SV} && $readItems->{SV} !~ /\bnone\b/i) {
        if (!$SQVECTORS->counter('name',$readItems->{SV},0)) {
            $status->{diagnosis} .= "! Error in update of SEQUENCEVECTORS.name (read: $readItems->{SV})$break";
            $status->{errors}++;
        }
        $svector = $SQVECTORS->associate('svector',$readItems->{SV},'name'); # get id number           
    }
    else {
#        $readItems->{SV} = 0; # just to have it defined (re: ligation check)
        $readItems->{SV} = ''; # just to have it defined (re: ligation check)
        $status->{diagnosis} .= "! No Sequencing Vector (SV) specified$break";
        $readItems->{RPS} += 32; # bit 6
        $status->{warnings}++;
    }

# check cloning vector presence and cover

    if ($readItems->{CV} && $readItems->{CV} !~ /none/i) {
        if (!$CLVECTORS->counter('name',$readItems->{CV},0)) {
            $status->{diagnosis} .= "! Error in update of CLONINGVECTORS.name (read: $readItems->{CV})$break";
            $status->{errors}++;
        }
    }
    else {
        delete $readItems->{CV} if ($readItems->{CV}); # delete 'none'
        $status->{diagnosis} .= "! No Cloning Vector (CV) specified$break";
        $readItems->{RPS} += 128; # bit 8
        $status->{warnings}++;
    }

    if (my $cvsi = $readItems->{CS}) {
        my ($cl, $cu) = split /\s+|\.+/, $cvsi;
        if ($cl && $cu) {
            $readItems->{CL} = $cl;
            $readItems->{CR} = $cu;
        } elsif (!$cl && $cu) {
            $cl = 1;
            $cu++;
        } else {
            $status->{diagnosis} .= "! Failed to decode Cloning Vector cover $cvsi$break";
            $readItems->{RPS} += 64; # bit 7
            $status->{warnings}++ if (!$self->{fatal});
            $status->{errors}++   if  ($self->{fatal});
        }
    }

# if ligation not specified or equals '99999', try recovery via clone

    if (!$readItems->{LG} && $readItems->{CN}) {
print "Try to recover undefined ligation data for clone $readItems->{CN}<br>$break";
#        if ($self->{LigationReader}->newClone($readItems->{CN},1)) {
#            my $list = $self->{LigationReader}->list(1);
#            print "output Ligationreader: $list";
#        }
    }

# test if ligation is indicated in the read; if so, find it in the ligation table

    if ($readItems->{LG}) {
        my @items = ('CN','SIL','SIH','SV');
        my ($hash, $column) = $LIGATIONS->locate($readItems->{LG}); # exact match
        if ($column eq 'clone') {
# instead of the ligation name or number, the clone name is used
            $hash = $LIGATIONS->associate('hashref',$readItems->{LG},'identifier');
            $column = 'identifier' if $hash;
  print "recovery hashref $hash column $column <br>";
        }
print "Ligation hash $hash \n" if $DEBUG;

        if (!$hash) {
# the ligation does not yet exist; find it in the Oracle database and add to LIGATIONS
            $self->logger("Ligation $readItems->{LG} not in LIGATIONS: search in Oracle database");
            my $origin;
            my $ligation = LigationReader->new($readItems->{LG});
print "Ligation hash $ligation \n" if $DEBUG;
            if ($ligation->build() > 0) {
                foreach my $item (@items) {
                    my $litem = $ligation->get($item);

#           if ($self->{LigationReader}->newLigation($readItems->{LG})) { # get a new ligation
#               foreach my $item (@items) {
#                   my $litem = $self->{LigationReader}->get($item);

                    $self->logger("ligation: $item $litem");
                    if ($item eq 'SV' && !$readItems->{SV} && $litem) {
# pick the Sequence Vector information from the Ligation
                        $readItems->{SV} = $litem;
                        if (!$SQVECTORS->counter('name',$readItems->{SV},0)) {
                            $status->{diagnosis} .= "! Error in update of SEQUENCEVECTORS.name ";
                            $status->{diagnosis} .= "(ligation: $readItems->{SV})$break";
                            $status->{errors}++;
                        }
                        $svector = $SQVECTORS->associate('svector',$readItems->{SV},'name'); # get id            
                    }
                    if (!$readItems->{$item} || $litem ne $readItems->{$item}) {
                        $status->{diagnosis} .= "! Inconsistent data for ligation $readItems->{LG} : $item ";
                        $status->{diagnosis} .= ": Oracle says \"$litem\", READ says:\"$readItems->{$item}\"$break";
                        $readItems->{RPS} += 256; # bit 9
                    # try to see if the indication matches the plate names
                        if ($item eq 'CN' && $ligation->get('cn') =~ /$readItems->{CN}/) {
                            $status->{diagnosis} .= " ($readItems->{CN} corresponds to $litem)$break";
                            $readItems->{CN} = $litem; # replace by Oracle value
                            $status->{warnings}++;
                        }
                        elsif ($item =~ /SIH|SIL/ && ($litem>30000 || $readItems->{$item}>30000)) {
                            $readItems->{RPS} += 16; # bit 5
                            $status->{diagnosis} .= " (Overblown insert value(s) ignored)$break";
                            $status->{warnings}++; # flag, but ignore the range data
                        }
                        elsif ($litem && $litem =~ /$readItems->{$item}/i) {
                            $status->{diagnosis} .= "Ligation accepted$break";
                            $status->{warnings}++;
	 	        }
                        else {
                            $status->{warnings}++ if (!$self->{fatal});
                            $status->{errors}++   if  ($self->{fatal});
                        }
                    }
                }
                $origin = 'O'; # Oracle data base
            } 
            elsif ($self->{dataSource} <= 2) {
# load with non-oracle id; possibly Oracle database inaccessible
                $origin = 'R'; # Defined in the Read itself
                $status->{diagnosis} .= "! Warning" if (!$self->{fatal});
                $status->{diagnosis} .= "! CGI access Error" if ($self->{fatal});
                $status->{diagnosis} .= ": ligation $readItems->{LG} not found in Oracle database$break";
                $readItems->{RPS} += 512; # bit 10
                $status->{warnings}++ if (!$self->{fatal});
                $status->{errors}++   if  ($self->{fatal});
                $self->logger(" ... NOT found!");
            }
            else {
		$self->logger("NOT FOUND .. ligation $readItems->{LG} adopted as foreign");
                $origin = 'F'; # foreign
            }

# update CLONES database table

            if (!$status->{errors} && $readItems->{CN} && !$CLONES->counter('clonename',$readItems->{CN},0)) {
                $status->{diagnosis} .= "!Error in update of CLONES.clonename '$readItems->{CN}'$break";
                $status->{errors}++;
            }

# if no errors detected, add to LIGATIONS table

            if (!$status->{errors}) {
                $LIGATIONS->newrow('identifier' , $readItems->{LG});
print "LIGATIONS error status: $LIGATIONS->{qerror} <br>\n" if $LIGATIONS->{qerror};
                $LIGATIONS->update('clone'      , $readItems->{CN}) if $readItems->{CN};
# new  use ref    my $clone = $CLONES->associate('clone',$readItems->{CN},'clonename' 0, 0, 1);
# new             $LIGATIONS->update('clone'      , $clone);
                $LIGATIONS->update('origin'     , $origin);
                $LIGATIONS->update('silow'      , $readItems->{SIL});
                $LIGATIONS->update('sihigh'     , $readItems->{SIH});
                $LIGATIONS->update('svector'    , $svector) if $svector;
                $self->logger(" .. stored in LIGATIONS!$break");
            }
            else {
                $status->{diagnosis} .= "! No new ligation added because of $status->{errors} error(s)$break";
            }
            $LIGATIONS->build(1,'ligation'); # rebuild the table
        } 
        elsif ($column ne 'identifier') {
# the ligation string is identified in table LIGATION but in the wrong column
            $status->{diagnosis} .= "! Invalid column name for ligation '$readItems->{LG}': $column$break";
            $status->{errors}++;

        }
        else {
# the ligation is identified in the table; check matchings of other reads data
            $self->logger("Ligation $readItems->{LG} found in LIGATIONS: test this against old data $break");
            undef my %itest;
            $itest{CN}  = $hash->{clone};
# new        $itest{CN}  = $CLONES->associate('clonename',$hash->{clone},'clone', 0, 0, 1);
            $itest{SIL} = $hash->{silow};
            $itest{SIH} = $hash->{sihigh};
            $svector    = $hash->{svector};
            $itest{SV}  = $SQVECTORS->associate('name',$svector,'svector') if $svector;
            my $oldwarnings = $status->{warnings};
            foreach my $item (keys %itest) {
                $readItems->{$item} = 0 if ($item ne 'CN' && !$readItems->{$item});
                if (defined($itest{$item}) && $itest{$item} ne $readItems->{$item}) {
                    $status->{diagnosis} .= "! Inconsistent data for ligation $readItems->{LG} : $item ";
                    $status->{diagnosis} .= "LIGATIONS table:'$itest{$item}' Read:'$readItems->{$item}'$break";
                    if ($itest{$item} =~ /$readItems->{$item}/i) {
             #   $status->{diagnosis} .= " ($readItems->{$item} replaced by $itest{$item}$break";
             #   $readItems->{$item} = $itest{$item};
                        $status->{warnings}++; # matching, but incomplete
                    }
                    elsif ($readItems->{$item} =~ /$itest{$item}/i) {
                        $status->{warnings}++; # matching, but overcomplete
                    }
                    elsif ($item eq 'SV' && $itest{$item} =~ /none/i && !$readItems->{$item}) {
                        $readItems->{$item} = 'NONE'; # alternatively: allow NONE on input (=> readReadData)
                        $status->{warnings}++;
                    }
                    elsif ($item eq 'SIH' && ($itest{$item}>30000 || $readItems->{$item}>30000)) {
                        $readItems->{RPS} += 16; # bit 5
                        $status->{diagnosis} .= " (Overblown insert value(s) ignored)$break";
                        $status->{warnings}++; # flag, but ignore the range data
                    }
                    elsif ($item eq 'CN' && $readItems->{ID} =~ /$readItems->{CN}/) {
                        $status->{diagnosis} .= " ($readItems->{CN} corresponds to file name:";
                        $status->{diagnosis} .= " $itest{$item} replaces $readItems->{CN})$break";
                        $readItems->{CN} = $itest{$item};
                        $status->{warnings}++;
                    }
                    else {                    
             # total mismatch
                        $status->{warnings}++ if (!$self->{fatal});
                        $status->{errors}++   if  ($self->{fatal});
                    }
                }
                elsif (!defined($itest{$item})) {
                # the ligation table item is undefined
                    $status->{diagnosis} .= "! Ligation item $item undefined;";
                    $status->{diagnosis} .= "  value $readItems->{$item} used$break";
                    $status->{warnings}++; 
                }
            }
            $readItems->{RPS} += 1024 if ($status->{warnings} != $oldwarnings); # bit 11
        }
    } 
    elsif ($readItems->{CN}) {
# NO ligation number is defined in the read; test read for other ligation data
        $self->logger("No ligation number defined; searching ARCTURUS table for matching data");
        $status->{diagnosis} .= "! Undefined ligation number$break";
# default test for data to recover, but signal as error if not in forced loading mode   
        $status->{warnings}++ if (!$self->{fatal});
        $status->{errors}++   if  ($self->{fatal});
# check if clone present in / or update CLONES database table
        $readItems->{RPS} += 2048; # bit 12
        if (!$CLONES->counter('clonename',$readItems->{CN},0)) {
            $status->{diagnosis} .= "!Error in update of CLONES.clonename ($readItems->{CN})$break";
            $status->{errors}++;
        }
        my $clone = $CLONES->associate('clone',$readItems->{CN},'clonename', 0, 0, 1); # exact match
        my $lastligation = 0;
        my $hash =  $LIGATIONS->nextrow(-1); # initialise counter
        while (1 && $clone) {
            $hash = $LIGATIONS->nextrow();
            last if (!defined($hash));
            $lastligation = $hash->{ligation};
            next if ($hash->{origin}  ne 'U'); # only consider previously unidentified 
            next if ($hash->{clone}   ne $readItems->{CN});
# new        next if ($hash->{clone}   ne $clone);
            next if ($hash->{silow}   ne $readItems->{SIL});
            next if ($hash->{sihigh}  ne $readItems->{SIH});
            next if ($hash->{svector} != $svector);
# here a match is found with a previously "unidentified" ligation; adopt this one
            $readItems->{LG} = $hash->{identifier};
            $self->logger("Match found with previous ligation $hash->{identifier}");
            last; # exit while loop
        }

        # if still not found, makeup a new number (Uxxxxx) and add to database
            
        if (!$readItems->{LG} && $clone) {
        # add a new ligation number to the table
            $readItems->{LG} = sprintf ("U%05d",++$lastligation);
            print STDOUT "Add new ligation $readItems->{LG} to ligation table$break";
            $LIGATIONS->newrow('identifier' , $readItems->{LG});
# new           $LIGATIONS->update('clone'      , $clone);
            $LIGATIONS->update('clone'      , $readItems->{CN});
            $LIGATIONS->update('origin'     , 'U');
            $LIGATIONS->update('silow'      , $readItems->{SIL});
            $LIGATIONS->update('sihigh'     , $readItems->{SIH});
            $LIGATIONS->update('svector'    , $svector);
            $LIGATIONS->build(1,'ligation'); # rebuild the table
        }
    }    
    else {
# NO ligation number is defined in the read; test read for other ligation data
        $self->logger("No ligation number or clone defined");
        $status->{diagnosis} .= "! Undefined ligation number$break";
        $status->{warnings}++ if (!$self->{fatal});
        $status->{errors}++   if  ($self->{fatal});
    }    
    &timer('ligation',1) if $DEBUG;

# process template

    return if !$USENEWREADLAYOUT;

    my $TEMPLATES = $READS->getInstanceOf('<self>.TEMPLATES') or die "undefined TEMPLATES";

    if (!$TEMPLATES->counter('template',$readItems->{TN},0)) {
        $status->{diagnosis} .= "! Error in update of TEMPLATES (read: $readItems->{TN})$break";
        $status->{errors}++;
    }
}
# error reporting coded as:

# bit 3    : Invalid SV insertion length
# bit 4    : Missing SV insertion length
# bit 5    : Sequence Vector insert length out of range (e.g. very large)
# bit 6    : Missing Sequence Vector
# bit 7    : Error in cloning vector cover
# bit 8    : Missing Cloning Vector
# bit 9    : Inconsistent Ligation data (i.p. between file and Oracle data)
# bit 10   : Unidentified Ligation
# bit 11   : Ligation warnings (unspecified)
# bit 12   : Missing Ligation

#############################################################################

sub strands {
# test Strands information implicit in file name against data table "STRANDS"
    my $self = shift;

    &timer('strands',0) if $DEBUG; 

# get the database handle to the STRANDS table

    my $READS   = $self->{READS};
    my $STRANDS = $READS->getInstanceOf('<self>.STRANDS') or die "undefined STRANDS";

    my $readItems = $self->{readItems};

    my $status = $self->{status};

# analyse the filename suffix

    my @fnparts = split /\./,$readItems->{ID};
    my $suffix = '   '; # blank triple to ensure definition
# find the first part of the filename which conforms to the standard form
    for (my $i=1; $i < @fnparts ; $i++) {
        if ($fnparts[$i] =~ /([a-z]\d[a-z])\w*/) {
            $suffix = $1;
            last;
        }
    }

# if no matching name part found, accept first

    $suffix = $fnparts[1] if (!($suffix =~ /\S/) && defined($fnparts[1]));
    my @suffixes = split //,$suffix;

# test strand identifier (=suffix[0]) against number of strands

#    my $oldwarnings = $status->{warnings};

    if ($self->{dataSource} == 1) {
# experiment file (like): the ST value is the number of strands
        $self->logger("Find Strands: suffix = $suffix $break");
        my $strands = $STRANDS->associate('strands',$suffixes[0],'strand');
        if (defined($strands) && $readItems->{ST} == $strands) {
            $readItems->{ST} = $suffixes[0]; # replace original by identifier 
        }
        else {
            $status->{diagnosis} .= "! Mismatch of strands identifier: \"$suffixes[0]\"";
            $status->{diagnosis} .= " and number of strands $readItems->{ST} given in read$break";
        # prepare for possible strand redefinition
            my $newstrand = 'z'; # completely unknown
            $newstrand = 'x' if ($readItems->{ST} == 1);
            $newstrand = 'y' if ($readItems->{ST} == 2);
      
            if ($suffixes[0] =~ /[a-z]/) {
            # test strand  description against sequence vector
                 my $string = $STRANDS->associate('description',$suffixes[0],'strand');
                $self->logger("test string:  $string");
                 my @fields = split /\s/,$string;
                 my $accept = 0;
                 foreach my $field (@fields) {
                     $accept = 1 if ($readItems->{SV} =~ /$field/i);
                 }
                 if ($accept) {
                 # the file suffix seems to be correct
                     $status->{diagnosis} .= " ($readItems->{SV} matches description";
                     $status->{diagnosis} .= " \"$string\": suffix $suffixes[0] accepted)$break";
                     $readItems->{ST} = $suffixes[0];
                 }
                 else {
                 # the file suffix appears to be incorrect
                     $status->{diagnosis} .= " ($readItems->{SV} conficts with description";
                     $status->{diagnosis} .= " \"$string\")$break";
                     $status->{diagnosis} .= "  suspect suffix $suffixes[0]: experiment file";
                     $status->{diagnosis} .= " value $readItems->{ST} encoded as $newstrand$break";
                     $readItems->{ST} = $newstrand;
                     $readItems->{RPS} += 4096; # bit 13
                 }
            }
            elsif ($suffixes[0] =~ /\d/) { # no valid code available in suffix
                $status->{diagnosis} .= " (Invalid code in experiment file suffix)$break";
                $readItems->{ST} = $newstrand;           
                $readItems->{RPS} += 4096; # bit 13
            }
            else {
                $readItems->{RPS} += 8192; # bit 14
                $status->{diagnosis} .= "! Invalid file extension \"$suffix\"$break";
                $status->{errors}++; # considered fatal
            }
        # the suffix is a number
            $status->{warnings}++;
        }
    }
    elsif ($self->{dataSource} == 2) {
# from Oracle: either "forward or "reverse"
        my $strands = $STRANDS->associate('description',$suffixes[0],'strand');
        if (defined($strands) && $strands =~ /$readItems->{ST}/i) {
            $readItems->{ST} = $suffixes[0]; # replace original by identifier 
        } 
        else {
            $status->{diagnosis} .= "! Mismatch of strands direction: \"$readItems->{ST}\"";
            $status->{diagnosis} .= " for suffix type \"$suffixes[0]\"$break";
            if ($suffixes[0] =~ /[a-z]/) {
                $readItems->{ST} = $suffixes[0]; # accept file extention code
                $readItems->{RPS} += 4096; # bit 13
                $status->{warnings}++;
            }
            else {
                $readItems->{RPS} += 8192; # bit 14
                $status->{diagnosis} .= "! Invalid file extension \"$suffix\"$break";
                $status->{errors}++; # considered fatal
            }
        }
    }
    elsif ($self->{dataSource} == 3) {
# foreign data, e.g. from TIGR: either "forward or "reverse", assumed double
        $readItems->{ST} = 'a' if ($readItems->{ST} =~ /forward/i);
        $readItems->{ST} = 'b' if ($readItems->{ST} =~ /reverse/i);
        $self->logger("Strand for foreign read: '$readItems->{ST}'$break"); 
    }

# test primer type

    $suffixes[1] = ' ' if (!defined($suffixes[1])); # ensure it's definition

    my $primertype = 5; # default unknown
    $primertype  = 1 if ($suffixes[0] =~ /[pstfw]/i); # forward
    $primertype  = 2 if ($suffixes[0] =~ /[qru]/i);   # reverse
    $primertype += 2 if ($primertype <= 2 && $suffixes[1] > 1); # custom primers

    if ($self->{dataSource} == 1) {
# PR value should match extension information
        if (defined($readItems->{PR}) && $readItems->{PR} != $primertype) {
            $status->{diagnosis} .= "! Mismatch of Primer type: \"$readItems->{PR}\" (read)";
            $status->{diagnosis} .= " vs. \"$suffixes[0]$suffixes[1]\" (suffix)$break";
            if ($readItems->{PR} == 3) {
                $status->{diagnosis} .= " (Probable XGap value replaced by Gap4 value $primertype)$break";
                $readItems->{PR} = $primertype;
            } 
            else {
                $status->{diagnosis} .= " (Experiment file value $readItems->{PR} accepted)$break";
	    }
            $status->{warnings}++;
            $readItems->{RPS} += 16384; # bit 15
        } 
    }
    if ($self->{dataSource} == 3) {
# foreign reads e.g. TIGR: primer type depends on strand and  
        if ($readItems->{PR} =~ /universal/i) {
            $primertype = 1 if ($readItems->{ST} eq 'a');
            $primertype = 2 if ($readItems->{ST} eq 'b');
        }
        elsif ($readItems->{PR} =~ /custom/i) {
            $primertype = 3 if ($readItems->{ST} eq 'a');
            $primertype = 4 if ($readItems->{ST} eq 'b');
        }
    }
    if ($self->{dataSource} == 2 || $self->{dataSource} == 3) {
# for Oracle data: accept the suffix value-based value
        if ($primertype < 5) {
            $readItems->{PR} = $primertype;
        }
        else {
            $readItems->{RPS} += 32768; # bit 16
            $status->{diagnosis} .= "! Missing Primer Type for \"$readItems->{PR}\"";
            $status->{warnings}++ if (!$self->{fatal});
            $status->{errors}++   if  ($self->{fatal});
        }
    }

# determine the default chemistry type (default to undefined)

    $suffixes[2] = 'u' if (!defined($suffixes[2])); # ensure it's definition
    $readItems->{CHT} = $suffixes[2];

    &timer('strands',1) if $DEBUG; 
}
# error reporting coded as:

# bit 13  : Mismatch between Strand description and file suffix
# bit 14  : Invalid file extension
# bit 15  : Mismatch bewteen Primer description and file suffix
# bit 16  : Missing Primer type

#############################################################################

sub chemistry {
# determine chemistry and test against database tables (CHEMISTRY & CHEMTYPES)
    my $self = shift;

    &timer('chemistry',0) if $DEBUG; 

# get the database handle to the CHEMISTRY and CHEMTYPES tables

    my $READS     = $self->{READS};
    my $CHEMISTRY = $READS->getInstanceOf('<self>.CHEMISTRY')   or die "undefined CHEMISTRY";
    my $CHEMTYPES = $READS->getInstanceOf('arcturus.CHEMTYPES') or die "undefined CHEMTYPES";

    my $readItems = $self->{readItems};

    my $status = $self->{status};

# before trying to get the chemistry from the SCF file, test if it is already specified

    my $chemistry = $readItems->{CH};
    if ($chemistry && $chemistry =~ /[a-zA-Z]/) {
# it's a name, now try to match it with a chemistry type
        $chemistry =~ s/[\s]/_/g; # replace blanks by '_' wildcard
        $chemistry = "%$chemistry%"; # add wildcards at beginning and end
        if (my $chemtype = $CHEMTYPES->associate('chemtype',$chemistry,'description',{limit=>1})) {
            $status->{diagnosis} .= "chemistry $readItems->{CH} found in ARCTURUS database ";
            $status->{diagnosis} .= "($chemtype) $break";
            $readItems->{CHT} = $chemtype;
            $CHEMISTRY->counter('identifier', $readItems->{CH}, 0); # the row could exist
            $CHEMISTRY->update('chemtype', $readItems->{CHT}, 'identifier', $readItems->{CH});
            $CHEMISTRY->build(1); # rebuild internal table
            return;
        }
        $status->{diagnosis} .= "chemistry $readItems->{CHT} NOT matched with a chemtype $break";
    }

# get description from SCF file

$self->logger("Default Chemistry Type: '$readItems->{CHT}' .. $break");
$self->logger("Test chemistry in file $self->{fileName}SCF$break");

    my $scffile = $readItems->{SCF} || "$self->{fileName}SCF";
    if ($scffile !~ /\//) { 
# no directory indicated: try to find directory using SCHEMA (temp fix for ORACLE data)
        if (!$self->{READATADIR}) {
# print "Chemistry test schema $self->{SCHEMA} $break";
            my $dirdata = `$BADGERDIR/pfind $self->{SCHEMA}`;
            my @dirdata = split /\s+/,$dirdata;
            $self->{READATADIR} = $dirdata[4];
        }
        $scffile = "$self->{READATADIR}/*/$scffile";
    }
$self->logger("SCF file full name: $scffile$break");

    my $test = 0;
    my $command = "$SCFREADDIR/get_scf_field $scffile";
    if (!$self->{CGI}) {
        $chemistry = `$command`;
$self->logger("non-CGI SCF: $command => chemistry: '$chemistry'$break");
        if ($chemistry =~ /.*\sDYEP\s*\=\s*(\S+)\s/) {
            $chemistry = $1;
            if ($chemistry =~ /Tag/) {
                undef $chemistry; # Tag not present
            }
        }
        else {
            undef $chemistry;
	}
$self->logger("chemistry='$chemistry' .. ");
    }
    elsif (!$test) {
#print "test recover $RECOVERDIR <br>";
        $chemistry = `$RECOVERDIR/recover.sh $command`;
$self->logger("test recover chemistry: '$chemistry' .. ");
        if ($chemistry =~ /.*\sDYEP\s*\=\s*(\S+)\s/) {
            $chemistry = $1;
            if ($chemistry =~ /Tag/) {
                undef $chemistry; # Tag not present
            }
        }
        else {
            undef $chemistry;
	}
$self->logger("chemistry='$chemistry' .. ");
    }
    else {
        $chemistry = `$RECOVERDIR/orecover.sh $command`;
        chomp $chemistry;
        undef $chemistry if ($chemistry =~ /load.+disabled/i);
        $chemistry =~ s/dye.*\=\s*//ig; # remove clutter from SCF data
$self->logger("SCF chemistry: '$chemistry'$break");
    }

# test against entries in the CHEMISTRY table (exact matches because $chemistry may contain wildcard symbols)

    my %choptions = (traceQuery => 0, compareExact => 1, useCache => 1);
    if ($chemistry && $CHEMISTRY->associate('chemistry',$chemistry,'identifier',\%choptions)) {
$self->logger("chemistry $chemistry found in ARCTURUS database table$break");
        $status->{diagnosis} .= "chemistry $chemistry found in ARCTURUS database table$break";
# the chemistry is already in the table; check CHT
        my $chtype = $CHEMISTRY->associate('chemtype',$chemistry,'identifier',\%choptions); # exact match
#        my $chtype = $CHEMISTRY->associate('chemtype',$chemistry,'identifier',-1,0,1); # exact match
        if (ref($chtype) eq 'ARRAY') {
            $status->{diagnosis} .= "! Multiple hits on chemistry identifier $chemistry: @$chtype$break";
# print "REPORT $self->{status}->{report}<br>";
            $status->{errors}++;
        }
        elsif ($readItems->{CHT} eq 'u' && $chtype ne 'u') {
            $status->{diagnosis} .= "! Undefined chemistry type for $chemistry replaced by \"$chtype\"$break";
            $readItems->{CHT} = $chtype;
            $readItems->{RPS} += 32768*2 ; # bit 17 
            $status->{warnings}++;
        }
        elsif ($chtype ne $readItems->{CHT}) {
            $status->{diagnosis} .= "! Warning: inconsistent chemistry identifier for $chemistry ";
            $status->{diagnosis} .= ": \"$readItems->{CHT}\" (file) vs. \"$chtype\" (database table)$break";
            $readItems->{CHT} = $chtype unless ($chtype eq 'u' || !$chtype); # use table value
            $status->{diagnosis} .= "  ARCTURUS data base table value $chtype adopted$break" if ($readItems->{CHT} eq $chtype);
            $readItems->{RPS} += 32768*4 ; # bit 18 
            $status->{warnings}++;
# if chemtype is not defined in the table, here is an opportunity to update
            if (!$chtype) {
                $CHEMISTRY->update('chemtype',$readItems->{CHT},'identifier',$chemistry, 0, 1);
                $status->{diagnosis} .= "CHEMISTRY.chemtype is inserted for chemistry $chemistry$break";
            }
        } 
        $readItems->{CH} = $chemistry;

    }
    elsif ($chemistry) {
        $status->{diagnosis} .= "chemistry \"$chemistry\" NOT found in ARCTURUS database$break";
# the chemistry is not yet in the CHEMISTRY table; before adding, test against CHT
        my $field = `grep '\"$chemistry\"' $GELMINDDIR/phred/phredpar.dat`; # identify in phred file
        $field    = `grep '\"$chemistry\"' $GELMINDDIR/*/phredpar.dat` if (!$field); # try other places
        chomp $field;
$self->logger("Gelminder chemistry data fields: \"$field\"$break");
        $field =~ s/[\'\"]?\s*$chemistry\s*[[\'\"]?/x /g; # remove chemistry and any quotations
        $field =~ s/\-/./; # replace hyphens by any symbol match
        my @fields = split /\s+/,$field;
        if ($readItems->{CHT} ne 'u') {
# get description from chemistry type
            my $description = $CHEMTYPES->associate('description',$readItems->{CHT},'chemtype');
$self->logger("test Gelminder description against type $readItems->{CHT}$break");
            if (@fields) {
$self->logger("@{fields}$break$fields[1]$break$fields[2]$break");
        # require both to match
                if (!($description =~ /$fields[1]/i) || !($description =~ /$fields[2]/i)) {
                    $status->{diagnosis} .= "! Mismatch between Gelminder: '$field' and description: ";
                    $status->{diagnosis} .= "'$description' for chemtype $readItems->{CHT}$break";
        # try to recover by re-assembling and testing the description field
                    $field = $fields[1].' '.$fields[2];
                    $field =~ s/^\s*(primer|terminator)\s*(\S*.)$/$2 $1/;
                    $status->{diagnosis} .= "test field: $field<br>";
                    $field =~ s/Rhoda/%hoda/i; # to avoid case sensitivities 
                    $field =~ s/\s+|\./%/g;
                    my $chtype = $CHEMTYPES->associate('chemtype',$field,'description');
                    if ($chtype && ref($chtype) ne 'ARRAY') {
                        $status->{diagnosis} .= "Chemistry type recovered as: $chtype$break";
                        $readItems->{CHT} = $chtype;
                        $status->{warnings}++;
                    }
                    else {
                        $status->{errors}++   if  ($self->{fatal} && $readItems->{CHT} ne 'l');
                        $status->{warnings}++ if (!$self->{fatal} || $readItems->{CHT} eq 'l' && $description =~ /Licor/i);
                    } 
                    $readItems->{RPS} += 32768*4 ; # bit 18
#$self->{status}->{report} =~ s/$break/<br>/g; print STDOUT "report: $self->{status}->{report}";
                }
            }
            else {
        # assume CHT is correct
                $status->{diagnosis} .= "! Warning: incomplete Chemistry data in phredpar.dat$break";
                $readItems->{RPS} += 32768*2 ; # bit 17 
                $status->{warnings}++;
            }
        }
        else {
    # CHT not defined; find matching description for fields 1 and 2
$self->logger(" CHT not defined: test Gelminder description against ARTURUS chemistry data$break");
            if (@fields) {
                for (my $n=1 ; $n<=10 ; $n++) {
                    my $description = $CHEMTYPES->associate('description',$n,'number');
$self->logger("description = $description$break");
                    if ($description =~ /$fields[1]/i && $description =~ /$fields[2]/i) {
                        $readItems->{CHT} = $CHEMTYPES->associate('chemtype',$n,'number');
$self->logger(" ... identified (type = $readItems->{CHT})$break");
                    }
                }
            }
            if ($readItems->{CHT} eq 'u') {
                $status->{diagnosis} .= "Unrecognized Gelminder chemistry type$break";
                $readItems->{RPS} += 32768*8 ; # bit 19 
                $status->{warnings}++; 
            }
        }
        $readItems->{CH} = $chemistry;

        if (!$status->{errors}) {
            $status->{diagnosis} .= "New chemistry $chemistry added to Arcturus database$break";
            $CHEMISTRY->newrow('identifier', $chemistry);
            $CHEMISTRY->update('chemtype'  , $readItems->{CHT});
            $CHEMISTRY->build(1); # rebuild internal table
        }
        else {
            $status->{diagnosis} .= "! Chemistry $chemistry NOT added because of $status->{errors} error(s)$break";
        }
    }
    else {
# undefined chemistry
        $status->{warnings}++ if (!$self->{fatal});
        $status->{errors}++   if  ($self->{fatal});
        if ($readItems->{CHT} eq 'u') {
            $status->{diagnosis} .= "! Undefined (CH=$readItems->{CH}) ";
        }
        elsif ($readItems->{CHT}) {
            $status->{diagnosis} .= "! Unverified ($readItems->{CHT}) ";
        }
        else { 
            $status->{diagnosis} .= "! Unspecified (CH=$readItems->{CH}) ";
        }
        $status->{diagnosis} .= "chemistry: no SCF info available ";
        $status->{diagnosis} .= "($SCFREADDIR/get_scf_field $self->{fileName}SCF)$break";
        $readItems->{RPS} += 32768*16 ; # bit 20 
# try to recover using Chemtype description
        if ($chemistry = $CHEMTYPES->associate('description',$readItems->{CHT},'chemtype')) {
            $readItems->{CH} = $chemistry;
            $CHEMISTRY->counter('identifier',$chemistry,0); # the row could exist
$self->logger(".. recovered: = $readItems->{CH})$break");
            $CHEMISTRY->update('chemtype', $readItems->{CHT},'identifier', $chemistry);
            $CHEMISTRY->build(1); # rebuild internal table
        }
        else {
$self->logger("... NOT recovered: = $readItems->{CH})$break");
            delete $readItems->{CH}; # remove meaningless info
        }
print "REPORT $self->{status}->{report}<br>";
    }
    &timer('chemistry',1) if $DEBUG; 
}
# error reporting coded as:

# bit 17  : Incomplete Chemistry data (recovered)
# bit 18  : Inconsistent Chemistry description
# bit 19  : Unrecognised Gelminder chemistry type
# bit 20  : Missing chemistry

#############################################################################

sub encode {
    my $self = shift;
    my $scm  = shift; # sequence compression method
    my $qcm  = shift; # quality  compression method

    $scm = 99 unless defined($scm);
    $qcm = 99 unless defined($qcm);

    &timer('encode',0) if $DEBUG; 

    my $Compress  = $self->{Compress};
 
    my $readItems = $self->{readItems};

    undef my $error;
    undef my $scount;
    if ($scm && ($scm == 1 || $scm == 2 || $scm == 99)) {
        $readItems->{sequence} = $readItems->{SQ};
       ($scount,$readItems->{SQ}) = $Compress->sequenceEncoder($readItems->{SQ},$scm);
        $error .= $self->enter('SCM',$scm);
    }
    elsif ($scm) {
        $error .= "Invalid Sequence Encoding option=$scm$break";
    }
    my $sqcstatus = $Compress->status;

    undef my $qcount;
    if ($qcm && ($qcm >= 1 && $qcm <= 3) || $qcm == 99) {
        $readItems->{quality} = $readItems->{AV};
       ($qcount,$readItems->{AV}) = $Compress->qualityEncoder($readItems->{AV},$qcm);
        $error .= $self->enter('QCM',$qcm);
    }
    elsif ($qcm) {
        $error .= "Invalid Quality Encoding option=$qcm$break";
    }
    my $qdcstatus = $Compress->status;

# further status checking

    if (!$qcount || !$scount || $qcount != $scount) {
        $error .= "Mismatch of sequence ($scount) and quality data ($qcount)$break";
    }
    else {
        $error .= $self->enter('SLN',$scount);
    }

    $error .= "Sequence encoding error $sqcstatus$break" if $sqcstatus;
    $error .= "Quality  encoding error $qdcstatus$break" if $qdcstatus;

    if ($error) {
        $self->{status}->{errors}++;
        $self->{status}->{diagnosis} .= $error;
    }

    &timer('encode',1) if $DEBUG; 

    return $error;
}

sub newencode {
# encoding DNA and Quality data using z-compression
    my $self = shift;

    my $Compress  = $self->{Compress};
 
    my $readItems = $self->{readItems};

    undef my $scount;

    $readItems->{sequence} = $readItems->{SQ};
   ($scount,$readItems->{SQ}) = $Compress->sequenceEncoder($readItems->{SQ},99);
    my $sqcstatus = $Compress->status;

    undef my $qcount;

    $readItems->{quality} = $readItems->{AV};
   ($qcount,$readItems->{AV}) = $Compress->qualityEncoder($readItems->{AV},99);
    my $qdcstatus = $Compress->status;

# further status checking

    undef my $error;
    if (!$qcount || !$scount || $qcount != $scount) {
        $error .= "Mismatch of sequence ($scount) and quality data ($qcount)$break";
    }
    else {
        $error .= $self->enter('SLN',$scount); # sequence length
    }

    $error .= "Sequence encoding error $sqcstatus$break" if $sqcstatus;
    $error .= "Quality  encoding error $qdcstatus$break" if $qdcstatus;

    if ($error) {
        $self->{status}->{errors}++;
        $self->{status}->{diagnosis} .= $error;
    }

    return $error;
}

#############################################################################

sub insert {
# insert a new record into the READS database table
    my $self = shift;
    my $atop = shift; # add to pending on failure

    &timer('insert',0) if $DEBUG; 

    my $READS = $self->{READS};

    my $status = $self->{status};

# get the columns of the READS table (all of them) and find the reads key

    my $readItems = $self->{readItems};
    my $linkItems = $self->{linkItems};
    my $linkNames = $self->{linkNames};

# get the links to the dictionary tables

    $self->makeLinks() if !keys(%$linkItems);
    return 0 if $status->{errors};
    my $linkhash = $READS->traceTable();

    undef my %columntags;
    foreach my $key (keys %$linkhash) {
# get the experiment file item corresponding to the column name in $1
        if ($key =~ /\.READS\.(\S+)$/) {
            $columntags{$key} = $linkItems->{$1};
        }
    }

# now go through all columns and update the dictionary tables

    foreach my $key (sort keys %columntags) {
        my $tag = $columntags{$key}; my $tagHasValue = 0;
        $tagHasValue = 1 if (defined($readItems->{$tag}) && $readItems->{$tag} =~ /\w/);
        my $link = $linkhash->{$key};
        if ($link && $tagHasValue) {
# it's a linked column; find the link table, column and table handle
            my ($database,$linktable,$linkcolumn) = split /\./,$link;
            $linktable = $database.'.'.$linktable;
            my $linkhandle = $READS->getInstanceOf($linktable);
# find the proper column name in the dictionary table
            undef my @columns;
            my $pattern = "name|identifier|text";
            foreach my $column (@{$linkhandle->{columns}}) {
                if ($column ne $linkcolumn && $column =~ /\b(\S*$pattern)\b/i) {
                    push @columns, $1;
                }
            }
# replace the read entry by the reference
            if (@columns == 1) {
                $linkhandle->counter($columns[0],$readItems->{$tag});
                my %lkoptions = (compareExact => 1, useLocate => 1); # ?? changed
                my $reference = $linkhandle->associate($linkcolumn,$readItems->{$tag},$columns[0],\%lkoptions);
		$status->{diagnosis} .= "insert: $linkcolumn $readItems->{$tag},$reference$break";
                $readItems->{$tag} = $reference;
            }
            elsif (!@columns) {
                my $level = $linkhandle->counter($linkcolumn,$readItems->{$tag});
                $status->{diagnosis} .= "$linkhandle->{errors}<br>" if !$level;
            }
            else {
                $status->{diagnosis} .= "No unambiguous name/identifier column found ";
                $status->{diagnosis} .= "(@columns) in linked table $linktable$break";
                $status->{warnings}++;
            }
        }
    }

# finally, enter the defined read items in a new record of the READS table 

    my $counted = 0;
    if (!defined($readItems->{ID}) || $readItems->{ID} !~ /\w/) {
        $status->{diagnosis} .= "! Undefined or Invalid Read Name$break";
        $status->{errors}++;
    } 
    else {
        $counted = 1;
        undef my @columns;
        undef my @cvalues;
	foreach my $column (keys %$linkItems) {
            my $tag = $linkItems->{$column};
            if ($tag ne 'ID' && $tag ne 'RN' && $column ne 'readname') {
                my $entry = $readItems->{$tag};
                if (defined($entry) && $entry =~ /\S/) {
                    push @columns,$column;
                    push @cvalues,$entry;
                    $counted++;
                }
            }
        }

#----------------------
# what about $USENEWREADSLAYOUT?
#----------------------

# how to insert into READS and DNA? What about the template?
        if (!$READS->newrow('readname',$readItems->{ID},\@columns,\@cvalues)) {
# add the DNA, Quality data to the other table
# insert into DNA (read_id=last_insert_id() etc)
#        } 
#        else {
# entry failed
            $status->{diagnosis}  = "Failed to create new entry for read $readItems->{ID}";
            $status->{diagnosis} .= ": $READS->{qerror}" if $READS->{qerror};
            $status->{diagnosis} .= "$break";
            $status->{errors}++;
            $counted = 0;
# add the readname to the pending list
            if ($atop) {
                my $PENDING  = $self->{PENDING};
                my $assembly = $self->{assembly} || 1;
                if (!$PENDING->associate('record',$readItems->{ID},'readname',-1)) {
                    if (!$PENDING->newrow('readname',$readItems->{ID},'assembly',$assembly)) {
                        $status->{diagnosis}  = "Failed to add $readItems->{ID} to PENDING";
                        $status->{diagnosis} .= ": $READS->{qerror}" if $PENDING->{qerror};
                        $status->{diagnosis} .= "$break";
		    }
		}
            }
        }
    }

    &timer('insert',1) if $DEBUG; 

    return $counted;
}

#############################################################################

sub readback {
# read last inserted record back and test against readItem
    my $self = shift;

    &timer('readback',0) if $DEBUG; 

    undef my $error;

    my $Compress  = $self->{Compress};
    my $readItems = $self->{readItems};

    my $hash;
    if ($readbackOnServer) {
# full readback with reading data from database
        my $READS     = $self->{READS};
        my %options = (traceQuery => 0);
        $hash = $READS->associate('hashref','where','read_id=LAST_INSERT_ID()',\%options);
#        print "(readback on server) .. ";   
        if ($hash->{readname} && $hash->{readname} ne $readItems->{ID}) {
            print "LAST INSERT select failed ..";
            $hash = $READS->associate('hashref',$readItems->{ID},'readname',\%options);
            $error = "Cannot test against server: LAST INSERT select failed$break";
        }
    }
    else {
# only do a backtransform on the compressed data
        $hash->{scompress} = $readItems->{SCM};
        $hash->{sequence}  = $readItems->{SQ};
        $hash->{qcompress} = $readItems->{QCM};
        $hash->{quality}   = $readItems->{AV};
        print "(internal readback test) .. ";
    }

    my ($count, $string);

    my $scm = $hash->{scompress};
    my $sequence = $hash->{sequence};
    if ($scm && ($scm == 1 || $scm == 2 || $scm == 99)) {
       ($count, $string) = $Compress->sequenceDecoder($sequence,$scm,1);
    }
    elsif (!defined($scm) || $scm) {
        $scm = 0 if !$scm; $count = 0; # just to have them defined
        $error .= "Invalid sequence encoding method readback: $scm$break";
    }
    $readItems->{sequence} =~ s/\s+//g if ($scm == 99);
    if ($string !~ /\S/ || $string !~ /^$readItems->{sequence}\s*$/) {
        my $slength = length($sequence); # encoded sequence
        $error .= "Error in readback of DNA sequence (length = $count / $slength):$break";
        $error .= "Original : $readItems->{sequence}${break}Retrieved: $string$break$break"; 
    } 

    my $qcm = $hash->{qcompress};
    my $quality = $hash->{quality};
    if ($qcm && ($qcm >= 1 && $qcm <= 3 || $qcm == 99)) {
       ($count, $string) = $Compress->qualityDecoder($quality,$qcm);
        $string =~ s/^\s*(.*?)\s*$/$1/; # remove leading and trailing blanks
    }
    elsif (!defined($qcm) || $qcm) {
        $qcm = 0 if !$qcm; $count = 0; # just to have them defined
        $error .= "Invalid quality encoding method readback: $qcm$break";
    }
#    if ($string !~ /\S/ || ($string !~ /^\s*$readItems->{quality}\s*$/ && $readItems->{quality} !~ /^\s*$string\s*$/)) {
    if ($string !~ /\S/ || $readItems->{quality} !~ /^\s*$string\s*$/) {
        my $slength = length($string);
        my $rlength = length($readItems->{quality});
        my $qlength = length($quality); # encode quality data
	$readItems->{quality} =~ s/ /-/g; $string =~ s/ /-/g;
        $error .= "Error in readback of quality data (lengthes = $count/$qlength/$rlength/$slength):$break";
        $error .= "Original : '$readItems->{quality}'${break}Retrieved: '$string'$break$break"; 
    }

    if ($error) {
        $self->{status}->{diagnosis} .= $error;
        $self->{status}->{errors}++;
    }

    &timer('readback',1) if $DEBUG; 

    return $error; # undefined if none
}

#############################################################################
# ad hoc repair procedure for consensus reads with spurious leading zero

sub repairReads {

    my $self   = shift;
    my $commit = shift;
    my $start  = shift;
    my $final  = shift;

    my $READS = $self->{READS};

    my $ReadsRecall = ReadsRecall->init($READS,'ACGTN ');

    $start = 1 unless defined($start);
    $final = $READS->count unless defined($final);

    my $count = 0;
    my $missed = 0;

    my $block = 10000;
    print "\n";

    while ($start <= $final) {

        my $limit = $start + $block - 1;
        $limit = $final if ($limit > $final);

        print "Processing read $start - $limit \n";

        my $where = "read_id >= $start && read_id <= $limit";
        my $hashes = $READS->associate('hashrefs','where',$where,{returnScalar=>0});

        my $qcount;
        my $quality;
        foreach my $hash (@$hashes) {
# load the read hash into the ReadsRecall buffer
            if (my $status = $ReadsRecall->newReadHash($hash)) {
                print "missed on loading error: $hash->{readname}\n";
                $self->status(1);
                $missed++;
            }
            elsif ($ReadsRecall->{status}->{report} =~ /spurious/) {
                print "Repairable read $hash->{readname} located\n";
                my $qstring = $ReadsRecall->{qstring}; # the new quality string
#                print "New quality data:\n$qstring\n";
                next if ($qstring !~ /\S/);

                if (defined($hash->{qcompress}) && $self->{Compress}) {

                    my $dq = $hash->{qcompress};
                   ($qcount, $quality) = $self->{Compress}->qualityEncoder($qstring,$dq);
                    if (!$quality || $quality !~ /\S/) {
                        $status->{report} .= "! Missing or empty quality data ($dq)\n";
                        $status->{errors}++;
                    }
                    else {
                        my $length = length($quality);
                        my $oldlgt = length($hash->{quality});
                        print "New compressed quality data for $hash->{readname}: ";
                        print "length=$length ($oldlgt) method=$dq\n\n";
#                        $READS->update('quality',$quality,'readname',$hash->{readname}) if $commit;
#                        $DNA->update('quality',$quality,'read_id',$hash->{read_id}) if $commit;
                    }
                }
            }
            $count++;
        }
        $start = $limit + 1;
    }

#my $missed=@missed; print "$count reads written to output device; missed $missed \n" if $DEBUG;

    return $count; # 0 to signal NO reads found, OR query failed
}


#############################################################################

sub rollBack {
# reset if level == 0, else undo updates of last changes to tables 
    my $self    = shift;
    my $level   = shift;
    my $exclude = shift || ''; # optional array of tables to ignore

    my $instances = $self->{READS}->getInstanceOf(0);

    $exclude = join '|',@$exclude if (ref($exclude) eq 'ARRAY');

    foreach my $key (keys %$instances) {
        $instances->{$key}->rollback($level) if (!$exclude || $key !~ /$exclude/i);
    }
}

#############################################################################

sub logger {
    my $self = shift;
    my $line = shift;

    if (defined($line)) {
        $self->{status}->{report} .= $line;
    }
    else {
        $self->{status}->{report} = '';
    }
}

#############################################################################

sub break {

# return the line break appropriate for the environment (cosmetics)

    my $break = "\n";

    $break = "<br>" if $ENV{REQUEST_METHOD};

    return $break;
}

#############################################################################

sub timer {
# ad hoc timing routine
    my $marker = shift;
    my $access = shift; # 0 for start, 1 for end

    my $cptime = (times)[0]; # time spent in user code
    my $iotime = (times)[1]; # system cpu (not elapsed time, unfortunately)
    $timehash{$marker}->[$access]->[0] += $cptime;
    $timehash{$marker}->[$access]->[1] += $iotime;
}

#----------------------------------------------------------------------------

sub DESTROY {

    if ($DEBUG) {
        my $list = "$break$break${break}breakdown of time usage:$break";
        foreach my $key (keys %timehash) {
	    my $cptime = $timehash{$key}->[1]->[0] - $timehash{$key}->[0]->[0];
	    my $iotime = $timehash{$key}->[1]->[1] - $timehash{$key}->[0]->[1];
            $list .= sprintf ("%16s  CPU:%8.2f  IO:%8.2f$break",$key,$cptime,$iotime);
        } 
        $list =~ s/\n/<br>/ if ($ENV{REQUEST_METHOD});
        print STDOUT $list;
    }

}

#############################################################################
#############################################################################

sub colophon {

    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>              81 ,
        version =>             1.1 ,
        updated =>    "03 Feb 2003",
        date    =>    "15 Aug 2001",
    };
}

1;
