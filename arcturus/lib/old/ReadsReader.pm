package ReadsReader;

#############################################################################
#
# Read a standard Sanger format READ from a file
#
#############################################################################

use strict;
# use vars qw($VERSION);

use LigationReader;
 use Ligationreader;
use Compress;
use ADB_get_caf;

#############################################################################

my $LigationReader;
my $Compress;

my $readFileName;
my %readItem;
my %linkItem;
my $linkItems;
my $OracleData;
my $isExperimentFile;

my $errors;    # counter
my $warnings;  # counter
my $diagnosis; # text

my $report;

my $BADGERDIR  = '/usr/local/badger/bin'; 
my $SCFREADDIR = '/usr/local/badger/distrib-1999.0/alpha-bin';
my $GELMINDDIR = '/nfs/disk54/badger/src/gelminder';
my $RECOVERDIR = '/nfs/pathsoft/arcturus/dev/cgi-bin';
my $READATADIR;

my $READS; # the database handle for the READS table
my $fatal; # flag to switch some warnings to errors

#############################################################################

# constructor item new

sub new {
   my $prototype = shift;
   my $readtable = shift; # the reference to the READS database table
   my $DNA       = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

# transfer Arcturus Table handle to the class variables

   $READS = $readtable or die "Missing database handle for READS table";

# create a handle to the data compression module

   $Compress = new Compress($DNA); # default encoding string for DNA: 'ACGT- '

# create a handle to the ligation reader

   $LigationReader = Ligationreader->new();

   $fatal = 1; # default errors treated as fatal 

   bless ($self, $class);
   return $self;
}

#############################################################################

sub setFatal {
    my $self = shift;
    my $fnew = shift;

    $fatal = $fnew  if (defined($fnew));
}

#############################################################################

sub newRead {
# ingest a new read, return reference to hash table of entries
    my $self = shift;
    my $file = shift;
    my $type = shift;

# type 0 for standard read; else consensus file

    $isExperimentFile = 0;

    &erase; # clear any existing read items

    &logger(); # clear report

    if (defined($file)) {
        &readReadData($file)     if !$type;
        &newConsensusRead($file) if ($type && $type == 1);
        &getOracleRead($file)    if ($type && $type == 2);
    }

    if ($errors) {
        return 0;
    } 
    else {
        return \%readItem;
    }
}

#############################################################################

sub fetchOracleData {
# builds a set of hashes for the input readnames in specified schema and project
    my $self = shift;

    $OracleData = new ADB_get_caf(shift, shift) || return 0; # input SCHEME, PROJECT

    return $OracleData->getOracleReads(shift); # input array ref of filenames
}

#############################################################################

sub status {
# query the status of the table contents; define list for diagnosis
    my $self = shift; 
    my $list = shift; # = 0 for summary, > 0 for errors, > 1 for warnings as well
    my $html = shift;

    my $output;

    if (defined($list)) {
        my $n = keys %readItem;
        $output  = "$readFileName: $n items: ";
        $output .= "<FONT COLOR='blue'>$errors errors</FONT>, ";
        $output =~ s/blue/red/  if ($errors);
        $output .= "<FONT COLOR='WHITE'>$warnings warnings</FONT><BR>";
        $output =~ s/WHITE/yellow/  if ($warnings);
        $list-- if (!$errors); # switch off if only listing of errors
        $output .= "$diagnosis" if ($list && defined($diagnosis));
# adapt to HTML or line mode
        if ($html) {
            $output =~ s/\n/<br>/g;
#	    $output .= "<br>$comments<br>\n" if ($comments);
            $output =~ s/(\<br\>){2,}/<br>/ig;
        }
        else {
            $output =~ s/<br>/\n/ig;
            $output =~ s/\<[^\>]*\>//g; # remove tags
        }
    }

    $output, $errors;
#    return $errors, $output;
}

#############################################################################
# private methods for data input
#############################################################################

sub readReadData {
# reads a Read file from disk
    my $file = shift;

    my $record;
    if (open(READ,"$file")) {
        $readFileName = $file;
        $isExperimentFile = 1;
# decode data in data file and test
        my $line = 0;
        undef my $sequence;
        undef my $quality;
        while (defined($record = <READ>)) {
        # read the sequence
            chomp $record; $line++;
            if ($record =~ /^SQ\s?$/) {
                $sequence = 1;
            } 
            elsif ($record =~ /^\/\/\s?$/) {
                $sequence = 0;
            }
        # read the sequence data
            elsif ($record =~ /^\s+(\S+.*\S?)\s?$/ && $sequence) {
                $readItem{SQ} .= $1.' ';
            }
        # read the quality data
            elsif ($record =~ /^AV\s+(\d.*?)\s?$/) {
                $readItem{AV} .= $1.' ';
            }
        # concatenate comments (including tags)
            elsif ($record =~ /^[CC|TG]\s+(\S.*?)\s?$/) {
                $readItem{CC} .= "\n" if ($readItem{CC});
                $readItem{CC} .= $1;
                $readItem{CC} =~ s/\s+/ /; # remove redundant blanks
            }
        # read the other descriptors                 
            elsif ($record =~ /^(\w+)\s+(\S.*?)\s?$/) {
                my $item = $1; my $value = $2;
                $value = '' if ($value =~ /HASH/);
                $value = '' if ($value =~ /^none$/i);
                $readItem{$item} = $value if ($value =~ /\S/);
# print "item $item  value $value <br>";
            }
            elsif ($record =~ /\S/) {
                $diagnosis .= "! unrecognized input in file $file\n" if (!$diagnosis);
                $diagnosis .= "  l.$line:  \"$record\"\n";
                $warnings++;
            }
#          &logger("input line $line: $record");
        }
        close READ;
    # test number of fields read
        if (keys(%readItem) <= 0) {
            $diagnosis .= "! file $file contains no intelligible data\n\n";
            $errors++;
        }

    }
    elsif (!$OracleData) {
# the file presumably is not present or is corrupted
        $diagnosis .= "! file $file cannot be opened: $!\n"; 
        $errors++;
    }
    else {
# try if there is an Oracle Read
        &getOracleRead($file);
    }
}

#############################################################################

sub getOracleRead {
# get read data from Oracle into $readItem hash
    my $read = shift;

    if (defined($OracleData)) {
# try to read the data from a previously built Oracle set (see ADB_get_caf)
        if (my $hash = $OracleData->readHash($read)) {
# foreach my $key (keys %$hash) { print "key $key  :  $hash->{$key} <br>";} print "<br>";

            $readFileName  = $read;
            $read =~ s/\S+\///g; # chop of any directory name
            $readItem{ID} = $read;
            $readItem{SQ} = $hash->{DNA};
            $readItem{SQ} =~ s/n/-/ig;
            $readItem{AV} = $hash->{BaseQuality};
            $readItem{RPS} = 0; # read-parsing error code
            my @fields = split /\n/,$hash->{Sequence};
            foreach my $field (@fields) {
# print "$field  <br>\n";
                my @items = split /\s/,$field;
                if ($items[0] =~ /Temp/i) {
                    $readItem{TN} = $items[1];
                }
                elsif ($items[0] =~ /Ins/i) {
                    $readItem{SI} = "$items[1]..$items[2]";
                }
                elsif ($items[0] =~ /Liga/i) {
                    $readItem{LG} = $items[1];
                }
                elsif ($items[0] =~ /Seq/i) {
                    $readItem{SL} = $items[3] if ($items[2] <= 1);
                    $readItem{SL}++           if ($items[2] == 0);
                    $readItem{SR} = $items[4] if ($items[2]  > 1);
                    $field =~ s/Seq.*\d\s+\d+\s+(\S.*)$/$1/;
                    $field =~ s/[\"\']//g;
                    $readItem{SV} = $field;

                }
                elsif ($items[0] =~ /Pri/i) {
                    $readItem{PR} = $items[1];
                }
                elsif ($items[0] =~ /Str/i) {
                    $readItem{ST} = $items[1];
                }
                elsif ($items[0] =~ /Dye/i) {
                    $readItem{CH} = $items[1];

                }
                elsif ($items[0] =~ /Clo/i) {
                    $readItem{CN} = $items[1];
                }
                elsif ($items[0] =~ /Pro/i) {
                    $readItem{PS} = $items[1];
                }
                elsif ($items[0] =~ /Asp/i) {
                    $readItem{DT} = $items[1];
                }
                elsif ($items[0] =~ /Bas/i) {
                    $readItem{BC} = $items[1];
                }
                elsif ($items[0] =~ /Cli/i) {
                    $readItem{QL} = $items[2];
                    $readItem{QR} = $items[3];
                }
                elsif ($items[0] =~ /SCF_File/i) {
                    $readItem{SCF} = $items[1];
                }
            }
        }
        else {
            $diagnosis .= "! No data found in Oracle hash\n";
            $errors++;
        }
#	print &list(0,1,1);
    }
}

#############################################################################

sub newConsensusRead {
# reads a consensus file from disk and package it as a "read"
    my $file = shift;

    my $record;
    if (open(READ,"$file")) {
        $readFileName = $file;
        $readFileName =~ s/\S+\///g;
        $readItem{ID} = $readFileName;
        $readItem{CC} = 'Consensus Read ';     
    # decode data in data file and test
        my $line = 0;
        undef my $sequence;
        undef my $quality;
        while (defined($record = <READ>)) {
            chomp $record; $line++;
            next if (!($record =~ /\S/));
            if ($record =~ /[^atcgnATCGN-\s]/) {
                $record =~ s/\s+//g;
                $readItem{CC} .= $record;
                next;
            }
            $record =~ s/\s//g; # no blanks
            $readItem{SQ} .= $record;
            $readItem{SQ} =~ tr/A-Z/a-z/; # ensure lower case throughout
        }
        close READ;
    # create a dummy quality sequence of 1 throughout
       ($readItem{AV} = $readItem{SQ}) =~ s/(.)/ 1/g;
    # test number of fields read
        if (keys(%readItem) <= 0) {
            $diagnosis .= "! file $file contains no intelligible data\n\n";
            $errors++;
        }
        else {
    # defined other required read items
            $readItem{DR}  = ' '; # direction unspecified
            $readItem{ST}  = 'z';
            my @timer = localtime;
            $timer[4]++; # to get month
            $timer[5] += 1900; # & year
            $readItem{DT}  = "$timer[5]-$timer[4]-$timer[3]";
            $readItem{QL}  = 0;
            $readItem{QR}  = length($readItem{SQ})+1;
            $readItem{PR}  = 5;  # undefined
        }
    }
}

#############################################################################

sub erase {
# clear read item hash and error status
    undef %readItem;

    $diagnosis = '';
    $warnings = 0;
    $errors = 0;
}

#############################################################################

sub makeLinks {
# store reads keys and corresponding column names
# this method builds the %linkItem hash and the $linkItems string
#    my $self = shift;
# print "makeLinks: build link entry<br>";

# get the columns of the READS table (all of them) and find the reads key

    if (!keys %linkItem) {
        $errors = 0;
        $diagnosis = '';
# initialize the correspondence between tags and column names
        my $READMODEL = $READS->findInstanceOf('arcturus.READMODEL');
        if (!$READMODEL) {
            $diagnosis = "READMODEL handle NOT found\n";
            $errors++;
        }
        else {
            my $hashes = $READMODEL->associate('hashrefs','where',1,-1);
# build internal linkItem hash
            if (ref($hashes) eq 'ARRAY') {
                foreach my $hash (@$hashes) {
                    my $column = $hash->{'column_name'};
                    $linkItem{$column} = $hash->{'item'};
                }
            }
            else {
                $diagnosis .= "READMODEL cannot be read\n";
                $errors++;
            }
        }
        return if $errors;
    }

    undef $linkItems;
    foreach my $key (keys(%linkItem)) {
        $linkItems .= '|' if $linkItems;
        $linkItems .= $linkItem{$key};
    }
}

#############################################################################
# public methods for access and testing
#############################################################################

sub enter {
# enter read item into internal %readItem hash
    my $self  = shift;
    my $entry = shift; # read item key or hash
    my $value = shift;

    $self->makeLinks if !$linkItems;

    my $status = '';
    if (ref($entry) eq 'HASH') {
        $self->erase; # clear current read data
        foreach my $item (keys %$entry) {
            $diagnosis .= $self->enter($item,$entry->{$item});
        }
        $errors++ if $diagnosis;
        $status = $diagnosis;
    }
    elsif ($entry =~ /^($linkItems)$/ && defined($value)) {
        $readItem{$entry} = $value;
    }
    elsif ($entry =~ /^($linkItems)$/) {
        delete $readItem{$entry};
    }
    else {
        $status = "Attempt to enter invalid read item $entry \n";
    }
    return $status;
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

    $result = "${tag}Contents of read $readFileName:$tag$tag";
    foreach my $key (sort keys (%readItem)) {
        $result .= "$key: $readItem{$key}$tag" if ($key ne 'AV' && $key ne 'SQ');
        $result .= "$key: $readItem{$key}$tag" if ($key eq 'SQ' && !$readItem{SCM});
        $result .= "$key: $readItem{$key}$tag" if ($key eq 'AV' && !$readItem{QCM});
    }

    undef $result if ($full < 1);
    my ($status, $error) = &status($self,2,$html);
    $result .= $status;

    $result .= $report.$tag if ($full > 1);

    return $result;
}

#############################################################################
# contents testing
#############################################################################

sub format {
#  Testing for standard Sanger format (error sets bit 1 or 2)

# only test if data originate from a flat file

    if ($isExperimentFile) {
        if ($readFileName !~ /$readItem{ID}/) {
            $diagnosis .= "!Mismatch between filename $readFileName and ";
            $diagnosis .= "read name $readItem{ID}\n";
# recover if mismatch is a 1 replaced by 'l' in suffix 
            foreach my $key (keys %readItem) {
                $readItem{$key} =~ s/(\.\w)l(\w)/${1}1$2/;
  	    }
            $readItem{RPS} += 2; # error on read ID
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
        elsif ($readItem{ID} ne $readItem{EN}) {
            $diagnosis .= "! ID and EN mismatch in $readItem{ID}\n";
            $readItem{RPS} += 1; # flag mismatch            
            $warnings++; # what about outside data ?
        }
        elsif (!($readItem{ID} =~ /$readItem{TN}/)) {
            $diagnosis .= "! ID and TN mismatch in $readItem{ID}\n";
            $readItem{RPS} += 1; # flag mismatch
            $warnings++;
        }
    }

# test presence of sequence and quality data

    if (!$readItem{SQ}) {
        $diagnosis .= "! Missing Sequence data in $readFileName\n";
        $errors++;
    }    
    if (!$readItem{AV}) {
        $diagnosis .= "! Missing Quality data in $readFileName\n";
        $errors++;
    }    
}
# error reporting coded as:

# bit 1  : mismatch between EN or TN and ID
# bit 2  : error in read ID (mismatch with fileneme; possibly recoverde)

#############################################################################

sub ligation {
# get ligation data and test against database tables VECTORS and LIGATIONS
    my $self = shift;

# get the database handle to the LIGATIONS and SEQUENCEVECTOR tables

    my $LIGATIONS = $READS->findInstanceOf('<self>.LIGATIONS')       or die "undefined LIGATIONS";
    my $SQVECTORS = $READS->findInstanceOf('<self>.SEQUENCEVECTORS') or die "undefined SEQUENCEVECTORS";
    my $CLVECTORS = $READS->findInstanceOf('<self>.CLONINGVECTORS')  or die "undefined CLONINGVECTORS";
    my $CLONES    = $READS->findInstanceOf('<self>.CLONES')          or die "undefined CLONES";

   &logger ("** Test or find Ligation Data"); 

    if (my $rdsi = $readItem{SI}) {
        my ($vl, $vu) = split /\s+|\.+/, $rdsi;
        if ($vl && $vu) {
            $vl *= 1000; $vl /= 1000 if ($vl >= 1.0E4);
            $vu *= 1000; $vu /= 1000 if ($vu >= 1.0E4);
            $readItem{SIL} = $vl;
            $readItem{SIH} = $vu;   
        } else {
            $diagnosis .= "! Invalid Sequence Vector insertion length (SI = $rdsi)\n";
            $readItem{RPS} += 4; # bit 3
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
    } else {
        $diagnosis .= "! No Sequencing Vector insertion length (SI) specified\n";
        $readItem{RPS} += 8; # bit 4
        $warnings++;
    }

# test and possibly update (sequence) vector table (tblv)

    undef my $svector;
    if ($readItem{SV} && $readItem{SV} !~ /none/i) {
        if (!$SQVECTORS->counter('name',$readItem{SV},0)) {
            $diagnosis .= "! Error in update of SEQUENCEVECTORS.name (read: $readItem{SV})\n";
            $errors++;
        }
        $svector = $SQVECTORS->associate('svector',$readItem{SV},'name'); # get id number           
    }
    else {
        $diagnosis .= "! No Sequencing Vector (SV) specified\n";
        $readItem{RPS} += 32; # bit 6
        $warnings++;
    }

# check cloning vector presence and cover

    if ($readItem{CV} && $readItem{CV} !~ /none/i) {
        if (!$CLVECTORS->counter('name',$readItem{CV},0)) {
            $diagnosis .= "! Error in update of CLONINGVECTORS.name (read: $readItem{CV})\n";
            $errors++;
        }
    }
    else {
        delete $readItem{CV} if ($readItem{CV}); # delete 'none'
        $diagnosis .= "! No Cloning Vector (CV) specified\n";
        $readItem{RPS} += 128; # bit 8
        $warnings++;
    }

    if (my $cvsi = $readItem{CS}) {
        my ($cl, $cu) = split /\s+|\.+/, $cvsi;
        if ($cl && $cu) {
            $readItem{CL} = $cl;
            $readItem{CR} = $cu;
        } elsif (!$cl && $cu) {
            $cl = 1;
            $cu++;
        } else {
            $diagnosis .= "! Failed to decode Cloning Vector cover $cvsi\n";
            $readItem{RPS} += 64; # bit 7
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
    }

# if ligation not specified or equals '99999', try recovery via clone

    if (!$readItem{LG} && $readItem{CN}) {
print "Try to recover undefined ligation data for clone $readItem{CN}<br>\n";
#        if ($LigationReader->newClone($readItem{CN},1)) {
#            my $list = $LigationReader->list(1);
#            print "output Ligationreader: $list";
#        }
    }

# test if ligation is indicated in the read; if so, find it in the ligation table

    if ($readItem{LG}) {
        my @items = ('CN','SIL','SIH','SV');
        my ($hash, $column) = $LIGATIONS->locate($readItem{LG}); # exact match
        if ($column eq 'clone') {
# instead of the ligation name or number, the clone name is used
            $hash = $LIGATIONS->associate('hashref',$readItem{LG},'identifier');
            $column = 'identifier' if $hash;
  print "recovery hashref $hash column $column <br>";
        }

        if (!$hash) {
    # the ligation does not yet exist; find it in the Oracle database and add to LIGATIONS
            &logger("Ligation $readItem{LG} not in LIGATIONS: search in Oracle database");
            my $origin;
            my $ligation = LigationReader->new($readItem{LG});
            if ($ligation->build() > 0) {
                foreach my $item (@items) {
                    my $litem = $ligation->get($item);

#           if ($LigationReader->newLigation($readItem{LG})) { # get a new ligation
#               foreach my $item (@items) {
#                   my $litem = $LigationReader->get($item);

                    &logger("ligation: $item $litem");
                    if ($item eq 'SV' && !$readItem{$item} && !$isExperimentFile) {
                # pick the Sequence Vector information from the Ligation
                        $readItem{SV} = $litem;
                        if (!$SQVECTORS->counter('name',$readItem{SV},0)) {
                            $diagnosis .= "! Error in update of SEQUENCEVECTORS.name ";
                            $diagnosis .= "(ligation: $readItem{SV})\n";
                            $errors++;
                        }
                        $svector = $SQVECTORS->associate('svector',$readItem{SV},'name'); # get id            
                    }
                    if (!$readItem{$item} || $litem ne $readItem{$item}) {
                        $diagnosis .= "! Inconsistent data for ligation $readItem{LG} : $item ";
                        $diagnosis .= ": Oracle says \"$litem\", READ says:\"$readItem{$item}\"\n";
                        $readItem{RPS} += 256; # bit 9
                    # try to see if the indication matches the plate names
                        if ($item eq 'CN' && $ligation->get('cn') =~ /$readItem{CN}/) {
                            $diagnosis .= " ($readItem{CN} corresponds to $litem)\n";
                            $readItem{CN} = $litem; # replace by Oracle value
                            $warnings++;
                        }
                        elsif ($item =~ /SIH|SIL/ && ($litem>30000 || $readItem{$item}>30000)) {
                            $readItem{RPS} += 16; # bit 5
                            $diagnosis .= " (Overblown insert value(s) ignored)\n";
                            $warnings++; # flag, but ignore the range data
                        }
                        elsif ($litem && $litem =~ /$readItem{$item}/i) {
                            $diagnosis .= "Ligation accepted\n";
                            $warnings++;
	 	        }
                        else {
                            $warnings++ if (!$fatal);
                            $errors++   if  ($fatal);
                        }
                    }
                }
                $origin = 'O'; # Oracle data base
            } 
            else {
        # load with non-oracle id; possibly Oracle database inaccessible
                $origin = 'R'; # Defined in the Read itself
                $diagnosis .= "! Warning" if (!$fatal);
                $diagnosis .= "! CGI access Error" if ($fatal);
                $diagnosis .= ": ligation $readItem{LG} not found in Oracle database\n";
                $readItem{RPS} += 512; # bit 10
                $warnings++ if (!$fatal);
                $errors++   if  ($fatal);
                &logger(" ... NOT found!");
            }
        # update CLONES database table
            if (!$errors && !$CLONES->counter('clonename',$readItem{CN},0)) {
                $diagnosis .= "!Error in update of CLONES.clonename ($readItem{CN})\n";
                $errors++;
            }
        # if no errors detected, add to LIGATIONS table
            if (!$errors) {
                $LIGATIONS->newrow('identifier' , $readItem{LG});
                $LIGATIONS->update('clone'      , $readItem{CN});
# new  use ref    my $clone = $CLONES->associate('clone',$readItem{CN},'clonename' 0, 0, 1);
# new             $LIGATIONS->update('clone'      , $clone);
                $LIGATIONS->update('origin'     , $origin);
                $LIGATIONS->update('silow'      , $readItem{SIL});
                $LIGATIONS->update('sihigh'     , $readItem{SIH});
                $LIGATIONS->update('svector'    , $svector);
                &logger(" ... Found and stored in LIGATIONS!");
            }
            else {
                $diagnosis .= "! No new ligation added because of $errors error(s)\n";
            }
            $LIGATIONS->build(1,'ligation'); # rebuild the table
        } 
        elsif ($column ne 'identifier') {
# the ligation string is identified in table LIGATION but in the wrong column
            $diagnosis .= "! Invalid column name for ligation identifier $readItem{LG}: $column\n";
            $errors++;

        }
        else {
# the ligation is identified in the table; check matchings of other reads data
            &logger("Ligation $readItem{LG} found in LIGATIONS: test this against old data");
            undef my %itest;
            $itest{CN}  = $hash->{clone};
# new        $itest{CN}  = $CLONES->associate('clonename',$hash->{clone},'clone', 0, 0, 1);
            $itest{SIL} = $hash->{silow};
            $itest{SIH} = $hash->{sihigh};
            $svector    = $hash->{svector};
            $itest{SV}  = $SQVECTORS->associate('name',$svector,'svector');
            my $oldwarnings = $warnings;
            foreach my $item (keys %itest) {
                if (defined($itest{$item}) && $itest{$item} ne $readItem{$item}) {
                    $diagnosis .= "! Inconsistent data for ligation $readItem{LG} : ";
                    $diagnosis .= "$item ARCTURUS table:$itest{$item} Read:$readItem{$item}\n";
                    if ($itest{$item} =~ /$readItem{$item}/i) {
             #   $diagnosis .= " ($readItem{$item} replaced by $itest{$item}\n";
             #   $readItem{$item} = $itest{$item};
                        $warnings++; # matching, but incomplete
                    }
                    elsif ($readItem{$item} =~ /$itest{$item}/i) {
                        $warnings++; # matching, but overcomplete
                    }
                    elsif ($item eq 'SIH' && ($itest{$item}>30000 || $readItem{$item}>30000)) {
                        $readItem{RPS} += 16; # bit 5
                        $diagnosis .= " (Overblown insert value(s) ignored)\n";
                        $warnings++; # flag, but ignore the range data
                    }
                    elsif ($item eq 'CN' && $readItem{ID} =~ /$readItem{CN}/) {
                        $diagnosis .= " ($readItem{CN} corresponds to file name:";
                        $diagnosis .= " $itest{$item} replaces $readItem{CN})\n";
                        $readItem{CN} = $itest{$item};
                        $warnings++;
                    }
                    else {                    
             # total mismatch
                        $warnings++ if (!$fatal);
                        $errors++   if  ($fatal);
                    }
                }
                elsif (!defined($itest{$item})) {
                # the ligation table item is undefined
                    $diagnosis .= "! Ligation item $item undefined;";
                    $diagnosis .= "  value $readItem{$item} used\n";
                    $warnings++; 
                }
            }
            $readItem{RPS} += 1024 if ($warnings != $oldwarnings); # bit 11
        }
    } 
    else {
# NO ligation number is defined in the read; test read for other ligation data
        &logger("No ligation number defined; searching ARCTURUS table for matching data");
    # check if clone present in / or update CLONES database table
        $readItem{RPS} += 2048; # bit 12
        if (!$CLONES->counter('clonename',$readItem{CN},0)) {
            $diagnosis .= "!Error in update of CLONES.clonename ($readItem{CN})\n";
            $errors++;
        }
        my $clone = $CLONES->associate('clone',$readItem{CN},'clonename', 0, 0, 1); # exact match
        my $lastligation = 0;
        my $hash =  $LIGATIONS->nextrow(-1); # initialise counter
        while (1 && $clone) {
            $hash = $LIGATIONS->nextrow();
            last if (!defined($hash));
            $lastligation = $hash->{ligation};
            next if ($hash->{origin}  ne 'U'); # only consider previously unidentified 
            next if ($hash->{clone}   ne $readItem{CN});
# new        next if ($hash->{clone}   ne $clone);
            next if ($hash->{silow}   ne $readItem{SIL});
            next if ($hash->{sihigh}  ne $readItem{SIH});
            next if ($hash->{svector} != $svector);
        # here a match is found with a previously "unidentified" ligation; adopt this one
            $readItem{LG} = $hash->{identifier};
            &logger("Match found with previous ligation $hash->{identifier}");
            last; # exit while loop
        }

        # if still not found, makeup a new number (Uxxxxx) and add to database
            
        if (!$readItem{LG} && $clone) {
        # add a new ligation number to the table
            $readItem{LG} = sprintf ("U%05d",++$lastligation);
            print STDOUT "Add new ligation $readItem{LG} to ligation table\n";
            $LIGATIONS->newrow('identifier' , $readItem{LG});
# new           $LIGATIONS->update('clone'      , $clone);
            $LIGATIONS->update('clone'      , $readItem{CN});
            $LIGATIONS->update('origin'     , 'U');
            $LIGATIONS->update('silow'      , $readItem{SIL});
            $LIGATIONS->update('sihigh'     , $readItem{SIH});
            $LIGATIONS->update('svector'    , $svector);
            $LIGATIONS->build(1,'ligation'); # rebuild the table
        }
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

# get the database handle to the STRANDS table

    my $STRANDS = $READS->findInstanceOf('<self>.STRANDS') or die "undefined STRANDS";

# analyse the filename suffix

    my @fnparts = split /\./,$readItem{ID};
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
   &logger("Find Strands: suffix = $suffix");

# test strand identifier (=suffix[0]) against number of strands

    my $oldwarnings = $warnings;

    if ($isExperimentFile) {
    # the ST value is the number of strands
        my $strands = $STRANDS->associate('strands',$suffixes[0],'strand');
        if (defined($strands) && $readItem{ST} == $strands) {
            $readItem{ST} = $suffixes[0]; # replace original by identifier 
        }
        else {
            $diagnosis .= "! Mismatch of strands identifier: \"$suffixes[0]\"";
            $diagnosis .= " and number of strands $readItem{ST} given in read\n";
        # prepare for possible strand redefinition
            my $newstrand = 'z'; # completely unknown
            $newstrand = 'x' if ($readItem{ST} == 1);
            $newstrand = 'y' if ($readItem{ST} == 2);
      
            if ($suffixes[0] =~ /[a-z]/) {
            # test strand  description against sequence vector
                 my $string = $STRANDS->associate('description',$suffixes[0],'strand');
                &logger("test string:  $string");
                 my @fields = split /\s/,$string;
                 my $accept = 0;
                 foreach my $field (@fields) {
                     $accept = 1 if ($readItem{SV} =~ /$field/i);
                 }
                 if ($accept) {
                 # the file suffix seems to be correct
                     $diagnosis .= " ($readItem{SV} matches description";
                     $diagnosis .= " \"$string\": suffix $suffixes[0] accepted)\n";
                     $readItem{ST} = $suffixes[0];
                 }
                 else {
                 # the file suffix appears to be incorrect
                     $diagnosis .= " ($readItem{SV} conficts with description";
                     $diagnosis .= " \"$string\")\n";
                     $diagnosis .= "  suspect suffix $suffixes[0]: experiment file";
                     $diagnosis .= " value $readItem{ST} encoded as $newstrand\n";
                     $readItem{ST} = $newstrand;
                     $readItem{RPS} += 4096; # bit 13
                 }
            }
            elsif ($suffixes[0] =~ /\d/) { # no valid code available in suffix
                $diagnosis .= " (Invalid code in experiment file suffix)\n";
                $readItem{ST} = $newstrand;           
                $readItem{RPS} += 4096; # bit 13
            }
            else {
                $readItem{RPS} += 8192; # bit 14
                $diagnosis .= "! Invalid file extension \"$suffix\"\n";
                $errors++; # considered fatal
            }
        # the suffix is a number
            $warnings++;
        }
    }
    else {
    # from Oracle: either "forward or "reverse"
        my $strands = $STRANDS->associate('description',$suffixes[0],'strand');
        if (defined($strands) && $strands =~ /$readItem{ST}/i) {
            $readItem{ST} = $suffixes[0]; # replace original by identifier 
        } else {
            $diagnosis .= "! Mismatch of strands direction: \"$readItem{ST}\"";
            $diagnosis .= " for suffix type \"$suffixes[0]\"\n";
            if ($suffixes[0] =~ /[a-z]/) {
                $readItem{ST} = $suffixes[0]; # accept file extention code
                $readItem{RPS} += 4096; # bit 13
                $warnings++;
            } else {
                $readItem{RPS} += 8192; # bit 14
                $diagnosis .= "! Invalid file extension \"$suffix\"\n";
                $errors++; # considered fatal
            }
        }
    }

# test primer type

    $suffixes[1] = ' ' if (!defined($suffixes[1])); # ensure it's definition

    my $primertype = 5; # default unknown
    $primertype  = 1 if ($suffixes[0] =~ /[pstfw]/i); # forward
    $primertype  = 2 if ($suffixes[0] =~ /[qru]/i);   # reverse
    $primertype += 2 if ($primertype <= 2 && $suffixes[1] > 1); # custom primers

    if ($isExperimentFile) {
# PR value should match extension information
        if (defined($readItem{PR}) && $readItem{PR} != $primertype) {
            $diagnosis .= "! Mismatch of Primer type: \"$readItem{PR}\" (read)";
            $diagnosis .= " vs. \"$suffixes[0]$suffixes[1]\" (suffix)\n";
            if ($readItem{PR} == 3) {
                $diagnosis .= " (Probable XGap value replaced by Gap4 value $primertype)\n";
                $readItem{PR} = $primertype;
            } 
            else {
                $diagnosis .= " (Experiment file value $readItem{PR} accepted)\n";
	    }
            $warnings++;
            $readItem{RPS} += 16384; # bit 15
        } 
    }
    else {
# for Oracle data: accept the suffix value
        if ($primertype) {
            $readItem{PR} = $primertype;
        }
        else {
            $readItem{RPS} += 32768; # bit 16
            $diagnosis .= "! Missing Primer Type for \"$readItem{PR}\"";
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
    }

# determine the default chemistry type (default to undefined)

    $suffixes[2] = 'u' if (!defined($suffixes[2])); # ensure it's definition
    $readItem{CHT} = $suffixes[2];
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

# get the database handle to the CHEMISTRY and CHEMTYPES tables

    my $CHEMISTRY = $READS->findInstanceOf('<self>.CHEMISTRY')   or die "undefined CHEMISTRY";
    my $CHEMTYPES = $READS->findInstanceOf('arcturus.CHEMTYPES') or die "undefined CHEMTYPES";

# get description from SCF file

&logger("<br>** Default Chemistry Type: $readItem{CHT}<br>");
&logger("Test chemistry in file ${readFileName}SCF<br>");

    my $scffile = $readItem{SCF} || "${readFileName}SCF";
    if ($scffile !~ /\//) { # no directory indicated: try to find directory (temp fix for ORACLE data)
        if (!$READATADIR) {
            my $dirdata = `$BADGERDIR/pfind $READS->{database}`;
            my @dirdata = split /\s+/,$dirdata;
            $READATADIR = $dirdata[4];
        }
        $scffile = "$READATADIR/*/$scffile";
    }

#                                           $SCFREADDIR/get_scf_field $scffile | grep -E '(dye|DYE)'
    my $chemistry = `$RECOVERDIR/recover.sh $SCFREADDIR/get_scf_field $scffile`;
    chomp $chemistry;
    undef $chemistry if ($chemistry =~ /load.+disabled/i);
    $chemistry =~ s/dye.*\=\s*//ig; # remove clutter from SCF data
&logger("SCF chemistry: $chemistry <br>");

# test against entries in the CHEMISTRY table (exact matches because $chemistry may contain wildcard symbols)

    if ($chemistry && $CHEMISTRY->associate('chemistry',$chemistry,'identifier',-1,0,1)) {
&logger("chemistry $chemistry found in ARCTURUS database table");
        $diagnosis .= "chemistry $chemistry found in ARCTURUS database table\n";
# the chemistry is already in the table; check CHT
        my $chtype = $CHEMISTRY->associate('chemtype',$chemistry,'identifier',-1,0,1); # exact match
        if (ref($chtype) eq 'ARRAY') {
            $diagnosis .= "! Multiple hits on chemistry identifier $chemistry: @$chtype\n";
# print "REPORT $report<br>";
            $errors++;
        }
        elsif ($readItem{CHT} eq 'u' && $chtype ne 'u') {
            $diagnosis .= "! Undefined chemistry type for $chemistry replaced by \"$chtype\"\n";
            $readItem{CHT} = $chtype;
            $readItem{RPS} += 32768*2 ; # bit 17 
            $warnings++;
        }
        elsif ($chtype ne $readItem{CHT}) {
            $diagnosis .= "! Warning: inconsistent chemistry identifier for $chemistry ";
            $diagnosis .= ": \"$readItem{CHT}\" (file) vs. \"$chtype\" (database table)\n";
            $readItem{CHT} = $chtype unless ($chtype eq 'u' || !$chtype); # use table value
            $diagnosis .= "  ARCTURUS data base table value $chtype adopted\n" if ($readItem{CHT} eq $chtype);
            $readItem{RPS} += 32768*4 ; # bit 18 
            $warnings++;
# if chemtype is not defined in the table, here is an opportunity to update
            if (!$chtype) {
                $CHEMISTRY->update('chemtype',$readItem{CHT},'identifier',$chemistry, 0, 1);
                $diagnosis .= "CHEMISTRY.chemtype is inserted for chemistry $chemistry\n";
            }
        } 
        $readItem{CH} = $chemistry;

    }
    elsif ($chemistry) {
&logger("chemistry \"$chemistry\" NOT found in ARCTURUS database");
        $diagnosis .= "chemistry \"$chemistry\" NOT found in ARCTURUS database\n";
    # the chemistry is not yet in the CHEMISTRY table; before adding, test against CHT
        my $field = `grep \"$chemistry\" $GELMINDDIR/phred/phredpar.dat`; # identify in phred file
        $field    = `grep \"$chemistry\" $GELMINDDIR/*/phredpar.dat` if (!$field); # try other places
        chomp $field;
&logger("Gelminder chemistry data fields: \"$field\"");
#$diagnosis .= "Gelminder chemistry data fields: \"$field\"";
        $field =~ s/[\'\"]?\s*$chemistry\s*[[\'\"]?/x /g; # remove chemistry and any quotations
#        $field =~ s/\b[\'\"]|[[\'\"]\b/ /g; # remove any quotations
#        $field =~ s/^\s*$chemistry/x/; # to ensure three words on the line
        $field =~ s/\-/./; # replace hyphens by any symbol match
        my @fields = split /\s+/,$field;
        if ($readItem{CHT} ne 'u') {
# $readItem{CHT} = 'f' if ($readItem{CHT} eq 'e'); # force read with invalid data through (1)  
# $readItem{CHT} = 'e' if ($readItem{CHT} eq 't'); # force read through (2)
    # get description from chemistry type
            my $description = $CHEMTYPES->associate('description',$readItem{CHT},'chemtype');
&logger("test Gelminder description against type $readItem{CHT}");
            if (@fields) {
&logger("@{fields}\n$fields[1]\n$fields[2]");
        # require both to match
                if (!($description =~ /$fields[1]/i) || !($description =~ /$fields[2]/i)) {
#$diagnosis = "fields: '$fields[0]' '$fields[1]' '$fields[2]'\n";
                    $diagnosis .= "! Mismatch between Gelminder: '$field' and description: ";
                    $diagnosis .= "'$description' for chemtype $readItem{CHT}\n";
        # try to recover by re-assembling and testing the description field
                    $field = $fields[1].' '.$fields[2];
                    $field =~ s/^\s*(primer|terminator)\s*(\S*.)$/$2 $1/;
      $diagnosis .= "test field: $field<br>";
                    $field =~ s/Rhoda/%hoda/i; # to avoid case sensitivities 
                    $field =~ s/\s+|\./%/g;
                    my $chtype = $CHEMTYPES->associate('chemtype',$field,'description');
                    if ($chtype && ref($chtype) ne 'ARRAY') {
                        $diagnosis .= "Chemistry type recovered as: $chtype\n";
                        $readItem{CHT} = $chtype;
                        $warnings++;
                    }
                    else {
                        $errors++   if  ($fatal && $readItem{CHT} ne 'l');
                        $warnings++ if (!$fatal || $readItem{CHT} eq 'l' && $description =~ /Licor/i);
                    } 
                    $readItem{RPS} += 32768*4 ; # bit 18 
               }
            }
            else {
        # assume CHT is correct
                $diagnosis .= "! Warning: incomplete Chemistry data in phredpar.dat\n";
                $readItem{RPS} += 32768*2 ; # bit 17 
                $warnings++;
            }
        }
        else {
    # CHT not defined; find matching description for fields 1 and 2
&logger(" CHT not defined: test Gelminder description against ARTURUS chemistry data");
            if (@fields) {
                for (my $n=1 ; $n<=10 ; $n++) {
                    my $description = $CHEMTYPES->associate('description',$n,'number');
&logger("description = $description");
                    if ($description =~ /$fields[1]/i && $description =~ /$fields[2]/i) {
                        $readItem{CHT} = $CHEMTYPES->associate('chemtype',$n,'number');
&logger(" ... identified (type = $readItem{CHT})");
                    }
                }
            }
            if ($readItem{CHT} eq 'u') {
                $diagnosis .= "Unrecognized Gelminder chemistry type\n";
                $readItem{RPS} += 32768*8 ; # bit 19 
                $warnings++; 
            }
        }
        $readItem{CH} = $chemistry;

        if (!$errors) {
            $CHEMISTRY->newrow('identifier', $chemistry);
            $CHEMISTRY->update('chemtype'  , $readItem{CHT});
            $CHEMISTRY->build(1); # rebuild internal table
        }
        else {
            $diagnosis .= "! Chemistry $chemistry NOT added because of $errors error(s)\n";
        }
    }
    else {
# undefined chemistry
        $warnings++ if (!$fatal);
        $errors++   if  ($fatal);
        if ($readItem{CHT} eq 'u') {
            $diagnosis .= "! Undefined (CH=$readItem{CH}) ";
        }
        elsif ($readItem{CHT}) {
            $diagnosis .= "! Unverified ($readItem{CHT}) ";
        }
        else { 
            $diagnosis .= "! Unspecified (CH=$readItem{CH}) ";
        }
        $diagnosis .= "chemistry: no SCF info available ";
        $diagnosis .= "($SCFREADDIR/get_scf_field ${readFileName}SCF)\n";
        $readItem{RPS} += 32768*16 ; # bit 20 
# try to recover using Chemtype description
        if ($chemistry = $CHEMTYPES->associate('description',$readItem{CHT},'chemtype')) {
            $readItem{CH} = $chemistry;
&logger("... recovered: = $readItem{CH})");
        }
        else {
&logger("... NOT recovered: = $readItem{CH})");
            delete $readItem{CH}; # remove meaningless info
        }
print "REPORT $report<br>";
    }
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

    undef my $error;
    undef my $scount;
    if ($scm && ($scm == 1 || $scm == 2)) {
        $readItem{sequence} = $readItem{SQ};
       ($scount,$readItem{SQ}) = $Compress->sequenceEncoder($readItem{SQ},$scm);
        $error .= $self->enter('SCM',$scm);
    }
    elsif ($scm) {
        $error .= "Invalid Sequence Encoding option=$scm\n";
    }
    my $sqcstatus = $Compress->status;

    undef my $qcount;
    if ($qcm && $qcm >= 1 && $qcm <= 3 ) {
        $readItem{quality } = $readItem{AV};
       ($qcount,$readItem{AV}) = $Compress->qualityEncoder($readItem{AV},$qcm);
        $error .= $self->enter('QCM',$qcm);
    }
    elsif ($qcm) {
        $error .= "Invalid Quality Encoding option=$qcm\n";
    }
    my $qdcstatus = $Compress->status;

# further status checking

    if (!$qcount || !$scount || $qcount != $scount) {
        $error .= "Mismatch of sequence ($scount) and quality data ($qcount)\n";
    }
    else {
        $error .= $self->enter('SLN',$scount);
    }

    $error .= "Sequence encoding error $sqcstatus\n" if $sqcstatus;
    $error .= "Quality  encoding error $qdcstatus\n" if $qdcstatus;

    return $error;
}

#############################################################################

sub insert {
# insert a new record in the READS database table
    my $self = shift;

# get the columns of the READS table (all of them) and find the reads key

    $self->makeLinks() if !keys(%linkItem);
    return 0 if $errors;

# get the links to the dictionary tables

    my $linkhash = $READS->traceTable();

    undef my %columntags;
    foreach my $key (keys %$linkhash) {
# get the flat file item correspondiong to the column name in $1
        if ($key =~ /\.READS\.(\S+)$/) {
            $columntags{$key} = $linkItem{$1};
        }
    }

# now go through all columns and update the dictionary tables

    foreach my $key (sort keys %columntags) {
        my $tag = $columntags{$key}; my $tagHasValue = 0;
        $tagHasValue = 1 if (defined($readItem{$tag}) && $readItem{$tag} =~ /\w/);
        my $link = $linkhash->{$key};
        if ($link && $tagHasValue) {
# it's a linked column; find the link table, column and table handle
            my ($database,$linktable,$linkcolumn) = split /\./,$link;
            $linktable = $database.'.'.$linktable;
            my $linkhandle = $READS->findInstanceOf($linktable);
# find the proper column name in the dictionary table
            undef my @columns;
            my $pattern = "name|identifier";
            foreach my $column (@{$linkhandle->{columns}}) {
                if ($column ne $linkcolumn && $column =~ /\b(\S*$pattern)\b/i) {
                    push @columns, $1;
                }
            }
# replace the read entry by the reference
            if (@columns == 1) {
                $linkhandle->counter($columns[0],$readItem{$tag});
                my $reference = $linkhandle->associate($linkcolumn,$readItem{$tag},$columns[0], 0, 0, 1);
                $readItem{$tag} = $reference;
            }
            elsif (!@columns) {
                my $level = $linkhandle->counter($linkcolumn,$readItem{$tag});
                $diagnosis .= "$linkhandle->{errors}<br>" if !$level;
            }
            else {
                $diagnosis .= "No unambiguous name/identifier column found (@columns) ";
                $diagnosis .= "in linked table $linktable\n";
                $warnings++;
            }
        }
    }

# finally, enter the defined read items in a new record of the READS table 

    my $counted = 0;
    if (!defined($readItem{ID}) || $readItem{ID} !~ /\w/) {
        $diagnosis .= "! Undefined or Invalid Read Name\n";
        $errors++;
    } 
    else {
        $counted = 1;
        undef my @columns;
        undef my @cvalues;
	foreach my $column (keys %linkItem) {
            my $tag = $linkItem{$column};
            if ($tag ne 'ID' && $tag ne 'RN' && $column ne 'readname') {
                my $entry = $readItem{$tag};
                if (defined($entry) && $entry =~ /\S/) {
                    push @columns,$column;
                    push @cvalues,$entry;
                    $counted++;
                }
            }
        }
        if (!$READS->newrow('readname',$readItem{ID},\@columns,\@cvalues)) {
# here develop update of previously loaded reads
            $diagnosis = "Failed to create new entry for read $readItem{ID}";
            $diagnosis .= ": $READS->{qerror}" if $READS->{qerror};
            $diagnosis .= "\n";
            $counted = 0;
            $errors++;
        } 
    }

    return $counted;
}

#############################################################################

sub readback {
# read last inserted record back and test against readItem
    my $self = shift;

    undef my $error;
    my %options = (traceQuery => 0);
    my $hash = $READS->associate('hashref','where','read_id=LAST_INSERT_ID()',\%options);
   
    if ($hash->{readname} && $hash->{readname} ne $readItem{ID}) {
        print "LAST INSERT select failed ..";
        $hash = $READS->associate('hashref',$readItem{ID},'readname',\%options);
print " recovered $hash .. ";
    }

    my ($count, $string);

    my $scm = $hash->{scompress};
    my $sequence = $hash->{sequence};
    if ($scm && ($scm == 1 || $scm == 2)) {
       ($count, $string) = $Compress->sequenceDecoder($sequence,$scm,1);
    }
    elsif (!defined($scm) || $scm) {
        $scm = 0 if !$scm; $count = 0; # just to have them defined
        $error .= "Invalid sequence encoding method readback: $scm\n";
    }
    if ($string !~ /\S/ || $string !~ /^$readItem{sequence}\s*$/) {
        my $slength = length($sequence); # encoded sequence
        $error .= "Error in readback of DNA sequence (length = $count / $slength):\n";
        $error .= "Original : $readItem{sequence}\nRetrieved: $string\n\n"; 
    } 

    my $qcm = $hash->{qcompress};
    my $quality = $hash->{quality};
    if ($qcm && $qcm >= 1 && $qcm <= 3) {
       ($count, $string) = $Compress->qualityDecoder($quality,$qcm,1);
    }
    elsif (!defined($qcm) || $qcm) {
        $qcm = 0 if !$qcm; $count = 0; # just to have them defined
        $error .= "Invalid sequence encoding method readback: $qcm\n";
    }
    if ($string !~ /\S/ || $readItem{quality} !~ /^\s*$string\s*$/) {
        my $qlength = length($quality); # encode quality data
        $error .= "Error in readback of quality data (length = $count / $qlength):\n";
        $error .= "Original : $readItem{sequence}\nRetrieved: $string\n\n"; 
    } 

    return $error; # undefined if none
}

#############################################################################

sub logger {
    my $line = shift;

    if (defined($line)) {
        $report .= $line;
    }
    else {
        $report = '';
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
        updated =>    "30 Sep 2002",
        date    =>    "15 Aug 2001",
    };
}

1;
