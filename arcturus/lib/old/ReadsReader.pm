package ReadsReader;

#############################################################################
#
# Read a standard Sanger format READ from a file
#
#############################################################################

use strict;
use vars qw($VERSION);

use LigationReader;
use Ligationreader;

#############################################################################

my $readFileName;
my %readEntry;
my %linkEntry;
my $OracleData;
my $isExperimentFile;
my $LigationReader;

my $errors;
my $warnings;
my $diagnosis;
#my $comments;
my $report;

my $SCFREADDIR = '/usr/local/badger/distrib-1999.0/alpha-bin';
my $GELMINDDIR = '/nfs/disk54/badger/src/gelminder';
my $RECOVERDIR = '/nfs/pathsoft/arcturus/dev/cgi-bin';

my $READS; # the database handle for the READS table
my $fatal; # flag to switch some warnings to errors

#############################################################################

# constructor item new

sub new {
   my $prototype = shift;
   my $readtable = shift; # the reference to the READS database table

   my $class = ref($prototype) || $prototype;
   my $self  = {};

# transfer table handles to the class variables

   $READS = $readtable or die "Missing database handle for READS table";

# create a handle to the ligation reader

   $LigationReader = Ligationreader->new();

# if run under CGI control, some warnings relating to ORACLE and SCF are
# replaced by an error status

   $fatal = 1; # default errors treated as fatal 
#   $fatal = 1 if (defined($ENV{PATH_INFO})); # CGI mode

   bless ($self, $class);
   return $self;
}

#############################################################################

sub linkToOracle {
# sets up a link to an Orace reader ADB_get_caf as alternative READS source 
    my $self = shift;
    my $link = shift;

    $OracleData = $link;
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

    undef %readEntry;
    undef $diagnosis;
    $isExperimentFile = 0;
#    undef $comments;
    $warnings = 0;
    $errors = 0;

    &logger(); # clear report

    if (defined($file)) {
        &readReadData($file) if (!defined($type) || $type == 0);
        &newConsensusRead($file) if (defined($type) && $type);
    }

    if ($errors) {
        return 0;
    } 
    else {
        return \%readEntry;
    }
}

#############################################################################

sub status {
# query the status of the table contents; define list for diagnosis
    my $self = shift; 
    my $list = shift;
    my $html = shift;

    my $output;
    if (defined($list)) {
# list = 0 for summary, > 0 for errors, > 1 for warnings as well
        my $n = keys %readEntry;
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
}

#############################################################################
# private method readReadData
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
                $readEntry{SQ} .= $1.' ';
            }
        # read the quality data
            elsif ($record =~ /^AV\s+(\d.*?)\s?$/) {
                $readEntry{AV} .= $1.' ';
            }
        # concatenate comments (including tags)
            elsif ($record =~ /^[CC|TG]\s+(\S.*?)\s?$/) {
                $readEntry{CC} .= "\n" if ($readEntry{CC});
                $readEntry{CC} .= $1;
                $readEntry{CC} =~ s/\s+/ /; # remove redundant blanks
            }
        # read the other descriptors                 
            elsif ($record =~ /^(\w+)\s+(\S.*?)\s?$/) {
                my $item = $1; my $value = $2;
                $value = '' if ($value =~ /HASH/);
                $value = '' if ($value =~ /^none$/i);
                $readEntry{$item} = $value if ($value =~ /\S/);
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
        if (keys(%readEntry) <= 0) {
            $diagnosis .= "! file $file contains no intelligible data\n\n";
            $errors++;
        }

    } elsif (defined($OracleData)) {
# try to read the data from a previously built Oracle set (see ADB_get_caf)
        my $hash = $OracleData->readHash($file);
        if (defined($hash)) {
            $readFileName  = $file;
#            $readFileName =~ s/\S+\///g;
            $readEntry{ID} = $file;
            $readEntry{SQ} = $hash->{DNA};
            $readEntry{SQ} =~ s/n/-/g;
            $readEntry{AV} = $hash->{BaseQuality};
            $readEntry{RPS} = 0; # read-parsing error code
            my @fields = split /\n/,$hash->{Sequence};
            foreach my $field (@fields) {
# print "$field  \n";
                my @items = split /\s/,$field;
                if ($items[0] =~ /Temp/i) {
                    $readEntry{TN} = $items[1];
                }
                elsif ($items[0] =~ /Ins/i) {
                    $readEntry{SI} = "$items[1]..$items[2]";
                }
                elsif ($items[0] =~ /Liga/i) {
                    $readEntry{LG} = $items[1];
                }
                elsif ($items[0] =~ /Seq/i) {
                    $readEntry{SL} = $items[3] if ($items[2] <= 1);
                    $readEntry{SL}++           if ($items[2] == 0);
                    $readEntry{SR} = $items[4] if ($items[2]  > 1);
                    $field =~ s/Seq.*\d\s+\d+\s+(\S.*)$/$1/;
                    $field =~ s/[\"\']//g;
                    $readEntry{SV} = $field;

                }
                elsif ($items[0] =~ /Pri/i) {
                    $readEntry{PR} = $items[1];
                }
                elsif ($items[0] =~ /Str/i) {
                    $readEntry{ST} = $items[1];
                }
                elsif ($items[0] =~ /Dye/i) {
                    $readEntry{CH} = $items[1];

                }
                elsif ($items[0] =~ /Clo/i) {
                    $readEntry{CN} = $items[1];
                }
                elsif ($items[0] =~ /Pro/i) {
                    $readEntry{PS} = $items[1];
                }
                elsif ($items[0] =~ /Asp/i) {
                    $readEntry{DT} = $items[1];
                }
                elsif ($items[0] =~ /Bas/i) {
                    $readEntry{BC} = $items[1];
                }
                elsif ($items[0] =~ /Cli/i) {
                    $readEntry{QL} = $items[2];
                    $readEntry{QR} = $items[3];
                }
            }
        }
        else {
            $diagnosis .= "! No data found in Oracle hash";
            $errors++;
        }

    }
    else {
    # the file presumably is not present or is corrupted
        $diagnosis .= "! file $file cannot be opened: $!\n"; 
        $errors++;
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
        $readEntry{ID} = $readFileName;
        $readEntry{CC} = 'Consensus Read ';     
    # decode data in data file and test
        my $line = 0;
        undef my $sequence;
        undef my $quality;
        while (defined($record = <READ>)) {
            chomp $record; $line++;
            next if (!($record =~ /\S/));
            if ($record =~ /[^atcgnATCGN-\s]/) {
                $record =~ s/\s+//g;
                $readEntry{CC} .= $record;
                next;
            }
            $record =~ s/\s//g; # no blanks
            $readEntry{SQ} .= $record;
            $readEntry{SQ} =~ tr/A-Z/a-z/; # ensure lower case throughout
        }
        close READ;
    # create a dummy quality sequence of 1 throughout
       ($readEntry{AV} = $readEntry{SQ}) =~ s/(.)/ 1/g;
    # test number of fields read
        if (keys(%readEntry) <= 0) {
            $diagnosis .= "! file $file contains no intelligible data\n\n";
            $errors++;
        }
        else {
    # defined other required read items
            $readEntry{DR}  = ' '; # direction unspecified
#            $readEntry{CN}  = 'unknown';
#            $readEntry{TN}  = 'unknown';
            $readEntry{ST}  = 'z';
            my @timer = localtime;
            $timer[4]++; # to get month
            $timer[5] += 1900; # & year
            $readEntry{DT}  = "$timer[5]-$timer[4]-$timer[3]";
            $readEntry{QL}  = 0;
            $readEntry{QR}  = length($readEntry{SQ})+1;
#            $readEntry{LG}  = 0;  # unknown
            $readEntry{PR}  = 5;  # undefined
        }
    }
}

#############################################################################
# public methods for access and testing
#############################################################################

sub update {
# add a new hash entry ($value defined) or remove one ($value undefined)
    my $self  = shift;
    my $item  = shift;
    my $value = shift;

    my $success = 0;
    if (defined($item) && defined($value)) {
        $readEntry{$item} = $value;
        $success = 1;
    }
    elsif (defined($item)) {
        delete $readEntry{$item};
    }

    $success;
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
    foreach my $key (sort keys (%readEntry)) {
        $result .= "$key: $readEntry{$key}$tag" if ($key ne 'AV' && $key ne 'SQ');
        $result .= "$key: $readEntry{$key}$tag" if ($key eq 'SQ' && !$readEntry{SCM});
        $result .= "$key: $readEntry{$key}$tag" if ($key eq 'AV' && !$readEntry{QCM});
    }

    undef $result if ($full <= 1);
    my ($status, $error) = &status($self,2,$html);
    $result .= $status;

    $result .= $report.$tag if ($full > 1);

    return $result;
}

#############################################################################

sub format {
#  Testing for standard Sanger format (error sets bit 1 or 2)

    if ($isExperimentFile) {
    # only test if data originate from a flat file
        if ($readFileName !~ /$readEntry{ID}/) {
            $diagnosis .= "!Mismatch between filename $readFileName and ";
            $diagnosis .= "read name $readEntry{ID}\n";
        # recover if mismatch is a 1 replaced by 'l' in suffix 
            foreach my $key (keys %readEntry) {
                $readEntry{$key} =~ s/(\.\w)l(\w)/${1}1$2/;
  	    }
            $readEntry{RPS} += 2; # error on read ID
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
        elsif ($readEntry{ID} ne $readEntry{EN}) {
            $diagnosis .= "! ID and EN mismatch in $readEntry{ID}\n";
            $readEntry{RPS} += 1; # flag mismatch            
            $warnings++; # what about outside data ?
        }
        elsif (!($readEntry{ID} =~ /$readEntry{TN}/)) {
            $diagnosis .= "! ID and TN mismatch in  $readEntry{ID}\n";
            $readEntry{RPS} += 1; # flag mismatch
            $warnings++;
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

# get the database handle to the LIGATIONS and SEQUENCEVECTOR tables

    my $LIGATIONS = $READS->findInstanceOf('<self>.LIGATIONS')       or die "undefined LIGATIONS";
    my $SQVECTORS = $READS->findInstanceOf('<self>.SEQUENCEVECTORS') or die "undefined SEQUENCEVECTORS";
    my $CLVECTORS = $READS->findInstanceOf('<self>.CLONINGVECTORS')  or die "undefined CLONINGVECTORS";
    my $CLONES    = $READS->findInstanceOf('<self>.CLONES')          or die "undefined CLONES";

   &logger ("** Test or find Ligation Data"); 

    if (my $rdsi = $readEntry{SI}) {
        my ($vl, $vu) = split /\s+|\.+/, $rdsi;
        if ($vl && $vu) {
            $vl *= 1000; $vl /= 1000 if ($vl >= 1.0E4);
            $vu *= 1000; $vu /= 1000 if ($vu >= 1.0E4);
            $readEntry{SIL} = $vl;
            $readEntry{SIH} = $vu;   
        } else {
            $diagnosis .= "! Invalid Sequence Vector insertion length (SI = $rdsi)\n";
            $readEntry{RPS} += 4; # bit 3
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
    } else {
        $diagnosis .= "! No Sequencing Vector insertion length (SI) specified\n";
        $readEntry{RPS} += 8; # bit 4
        $warnings++;
    }

# test and possibly update (sequence) vector table (tblv)

    undef my $svector;
    if ($readEntry{SV} && $readEntry{SV} !~ /none/i) {
        if (!$SQVECTORS->counter('name',$readEntry{SV},0)) {
            $diagnosis .= "! Error in update of SEQUENCEVECTORS.name (read: $readEntry{SV})\n";
            $errors++;
        }
        $svector = $SQVECTORS->associate('svector',$readEntry{SV},'name'); # get id number           
    }
    else {
        $diagnosis .= "! No Sequencing Vector (SV) specified\n";
        $readEntry{RPS} += 32; # bit 6
        $warnings++;
    }

# check cloning vector presence and cover

    if ($readEntry{CV} && $readEntry{CV} !~ /none/i) {
        if (!$CLVECTORS->counter('name',$readEntry{CV},0)) {
            $diagnosis .= "! Error in update of CLONINGVECTORS.name (read: $readEntry{CV})\n";
            $errors++;
        }
    }
    else {
        delete $readEntry{CV} if ($readEntry{CV}); # delete 'none'
        $diagnosis .= "! No Cloning Vector (CV) specified\n";
        $readEntry{RPS} += 128; # bit 8
        $warnings++;
    }

    if (my $cvsi = $readEntry{CS}) {
        my ($cl, $cu) = split /\s+|\.+/, $cvsi;
        if ($cl && $cu) {
            $readEntry{CL} = $cl;
            $readEntry{CR} = $cu;
        } elsif (!$cl && $cu) {
            $cl = 1;
            $cu++;
        } else {
            $diagnosis .= "! Failed to decode Cloning Vector cover $cvsi\n";
            $readEntry{RPS} += 64; # bit 7
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
    }

# if ligation not specified or equals '99999', try recovery via clone

    if (!$readEntry{LG} && $readEntry{CN}) {
print "Try to recover undefined ligation data for clone $readEntry{CN}<br>\n";
#        if ($LigationReader->newClone($readEntry{CN},1)) {
#            my $list = $LigationReader->list(1);
#            print "output Ligationreader: $list";
#        }
    }

# test if ligation is indicated in the read; if so, find it in the ligation table

    if ($readEntry{LG}) {
        my @items = ('CN','SIL','SIH','SV');
        my ($hash, $column) = $LIGATIONS->locate($readEntry{LG}); # exact match

        if (!defined($hash)) {
    # the ligation does not yet exist; find it in the Oracle database and add to LIGATIONS
            &logger("Ligation $readEntry{LG} not in LIGATIONS: search in Oracle database");
            my $origin;
            my $ligation = LigationReader->new($readEntry{LG});
            if ($ligation->build() > 0) {
                foreach my $item (@items) {
                    my $litem = $ligation->get($item);

#           if ($LigationReader->newLigation($readEntry{LG})) { # get a new ligation
#               foreach my $item (@items) {
#                   my $litem = $LigationReader->get($item);

                    &logger("ligation: $item $litem");
                    if ($item eq 'SV' && !$readEntry{$item} && !$isExperimentFile) {
                # pick the Sequence Vector information from the Ligation
                        $readEntry{SV} = $litem;
                        if (!$SQVECTORS->counter('name',$readEntry{SV},0)) {
                            $diagnosis .= "! Error in update of SEQUENCEVECTORS.name ";
                            $diagnosis .= "(ligation: $readEntry{SV})\n";
                            $errors++;
                        }
                        $svector = $SQVECTORS->associate('svector',$readEntry{SV},'name'); # get id            
                    }
                    if (!$readEntry{$item} || $litem ne $readEntry{$item}) {
                        $diagnosis .= "! Inconsistent data for ligation $readEntry{LG} : $item ";
                        $diagnosis .= ": Oracle says \"$litem\", READ says:\"$readEntry{$item}\"\n";
                        $readEntry{RPS} += 256; # bit 9
                    # try to see if the indication matches the plate names
                        if ($item eq 'CN' && $ligation->get('cn') =~ /$readEntry{CN}/) {
                            $diagnosis .= " ($readEntry{CN} corresponds to $litem)\n";
                            $readEntry{CN} = $litem; # replace by Oracle value
                            $warnings++;
                        }
                        elsif ($item eq 'SIH' && ($litem>30000 || $readEntry{$item}>30000)) {
                            $readEntry{RPS} += 16; # bit 5
                            $diagnosis .= " (Overblown insert value(s) ignored)\n";
                            $warnings++; # flag, but ignore the range data
                        }
                        elsif ($litem && $litem =~ /$readEntry{$item}/i) {
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
                $diagnosis .= ": ligation $readEntry{LG} not found in Oracle database\n";
                $readEntry{RPS} += 512; # bit 10
                $warnings++ if (!$fatal);
                $errors++   if  ($fatal);
                &logger(" ... NOT found!");
            }
        # update CLONES database table
            if (!$errors && !$CLONES->counter('clonename',$readEntry{CN},0)) {
                $diagnosis .= "!Error in update of CLONES.clonename ($readEntry{CN})\n";
                $errors++;
            }
        # if no errors detected, add to LIGATIONS table
            if (!$errors) {
                $LIGATIONS->newrow('identifier' , $readEntry{LG});
                $LIGATIONS->update('clone'      , $readEntry{CN});
# new  use ref    my $clone = $CLONES->associate('clone',$readEntry{CN},'clonename' 0, 0, 1);
# new             $LIGATIONS->update('clone'      , $clone);
                $LIGATIONS->update('origin'     , $origin);
                $LIGATIONS->update('silow'      , $readEntry{SIL});
                $LIGATIONS->update('sihigh'     , $readEntry{SIH});
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
            $diagnosis .= "! Invalid column name for ligation identifier $readEntry{LG}: $column\n";
            $errors++;

        }
        else {
    # the ligation is identified in the table; check matchings of other reads data
            &logger("Ligation $readEntry{LG} found in LIGATIONS: test this against old data");
            undef my %itest;
            $itest{CN}  = $hash->{clone};
# new        $itest{CN}  = $CLONES->associate('clonename',$hash->{clone},'clone', 0, 0, 1);
            $itest{SIL} = $hash->{silow};
            $itest{SIH} = $hash->{sihigh};
            $svector    = $hash->{svector};
            $itest{SV}  = $SQVECTORS->associate('name',$svector,'svector');
            my $oldwarnings = $warnings;
            foreach my $item (keys %itest) {
                if (defined($itest{$item}) && $itest{$item} ne $readEntry{$item}) {
                    $diagnosis .= "! Inconsistent data for ligation $readEntry{LG} : ";
                    $diagnosis .= "$item ARCTURUS table:$itest{$item} Read:$readEntry{$item}\n";
                    if ($itest{$item} =~ /$readEntry{$item}/i) {
             #   $diagnosis .= " ($readEntry{$item} replaced by $itest{$item}\n";
             #   $readEntry{$item} = $itest{$item};
                        $warnings++; # matching, but incomplete
                    }
                    elsif ($readEntry{$item} =~ /$itest{$item}/i) {
                        $warnings++; # matching, but overcomplete
                    }
                    elsif ($item eq 'SIH' && ($itest{$item}>30000 || $readEntry{$item}>30000)) {
                        $readEntry{RPS} += 16; # bit 5
                        $diagnosis .= " (Overblown insert value(s) ignored)\n";
                        $warnings++; # flag, but ignore the range data
                    }
                    elsif ($item eq 'CN' && $readEntry{ID} =~ /$readEntry{CN}/) {
                        $diagnosis .= " ($readEntry{CN} corresponds to file name:";
                        $diagnosis .= " $itest{$item} replaces $readEntry{CN})\n";
                        $readEntry{CN} = $itest{$item};
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
                    $diagnosis .= "  value $readEntry{$item} used\n";
                    $warnings++; 
                }
            }
            $readEntry{RPS} += 1024 if ($warnings != $oldwarnings); # bit 11
        }
    } 
    else {
# NO ligation number is defined in the read; test read for other ligation data
        &logger("No ligation number defined; searching ARCTURUS table for matching data");
    # check if clone present in / or update CLONES database table
        $readEntry{RPS} += 2048; # bit 12
        if (!$CLONES->counter('clonename',$readEntry{CN},0)) {
            $diagnosis .= "!Error in update of CLONES.clonename ($readEntry{CN})\n";
            $errors++;
        }
        my $clone = $CLONES->associate('clone',$readEntry{CN},'clonename', 0, 0, 1); # exact match
        my $lastligation = 0;
        my $hash =  $LIGATIONS->nextrow(-1); # initialise counter
        while (1 && $clone) {
            $hash = $LIGATIONS->nextrow();
            last if (!defined($hash));
            $lastligation = $hash->{ligation};
            next if ($hash->{origin}  ne 'U'); # only consider previously unidentified 
            next if ($hash->{clone}   ne $readEntry{CN});
# new        next if ($hash->{clone}   ne $clone);
            next if ($hash->{silow}   ne $readEntry{SIL});
            next if ($hash->{sihigh}  ne $readEntry{SIH});
            next if ($hash->{svector} != $svector);
        # here a match is found with a previously "unidentified" ligation; adopt this one
            $readEntry{LG} = $hash->{identifier};
            &logger("Match found with previous ligation $hash->{identifier}");
            last; # exit while loop
        }

        # if still not found, makeup a new number (Uxxxxx) and add to database
            
        if (!$readEntry{LG} && $clone) {
        # add a new ligation number to the table
            $readEntry{LG} = sprintf ("U%05d",++$lastligation);
            print STDOUT "Add new ligation $readEntry{LG} to ligation table\n";
            $LIGATIONS->newrow('identifier' , $readEntry{LG});
# new           $LIGATIONS->update('clone'      , $clone);
            $LIGATIONS->update('clone'      , $readEntry{CN});
            $LIGATIONS->update('origin'     , 'U');
            $LIGATIONS->update('silow'      , $readEntry{SIL});
            $LIGATIONS->update('sihigh'     , $readEntry{SIH});
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

    my @fnparts = split /\./,$readEntry{ID};
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
        if (defined($strands) && $readEntry{ST} == $strands) {
            $readEntry{ST} = $suffixes[0]; # replace original by identifier 
        }
        else {
            $diagnosis .= "! Mismatch of strands identifier: \"$suffixes[0]\"";
            $diagnosis .= " and number of strands $readEntry{ST} given in read\n";
        # prepare for possible strand redefinition
            my $newstrand = 'z'; # completely unknown
            $newstrand = 'x' if ($readEntry{ST} == 1);
            $newstrand = 'y' if ($readEntry{ST} == 2);
      
            if ($suffixes[0] =~ /[a-z]/) {
            # test strand  description against sequence vector
                 my $string = $STRANDS->associate('description',$suffixes[0],'strand');
                &logger("test string:  $string");
                 my @fields = split /\s/,$string;
                 my $accept = 0;
                 foreach my $field (@fields) {
                     $accept = 1 if ($readEntry{SV} =~ /$field/i);
                 }
                 if ($accept) {
                 # the file suffix seems to be correct
                     $diagnosis .= " ($readEntry{SV} matches description";
                     $diagnosis .= " \"$string\": suffix $suffixes[0] accepted)\n";
                     $readEntry{ST} = $suffixes[0];
                 }
                 else {
                 # the file suffix appears to be incorrect
                     $diagnosis .= " ($readEntry{SV} conficts with description";
                     $diagnosis .= " \"$string\")\n";
                     $diagnosis .= "  suspect suffix $suffixes[0]: experiment file";
                     $diagnosis .= " value $readEntry{ST} encoded as $newstrand\n";
                     $readEntry{ST} = $newstrand;
                     $readEntry{RPS} += 4096; # bit 13
                 }
            }
            elsif ($suffixes[0] =~ /\d/) { # no valid code available in suffix
                $diagnosis .= " (Invalid code in experiment file suffix)\n";
                $readEntry{ST} = $newstrand;           
                $readEntry{RPS} += 4096; # bit 13
            }
            else {
                $readEntry{RPS} += 8192; # bit 14
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
        if (defined($strands) && $strands =~ /$readEntry{ST}/i) {
            $readEntry{ST} = $suffixes[0]; # replace original by identifier 
        } else {
            $diagnosis .= "! Mismatch of strands direction: \"$readEntry{ST}\"";
            $diagnosis .= " for suffix type \"$suffixes[0]\"\n";
            if ($suffixes[0] =~ /[a-z]/) {
                $readEntry{ST} = $suffixes[0]; # accept file extention code
                $readEntry{RPS} += 4096; # bit 13
                $warnings++;
            } else {
                $readEntry{RPS} += 8192; # bit 14
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
        if (defined($readEntry{PR}) && $readEntry{PR} != $primertype) {
            $diagnosis .= "! Mismatch of Primer type: \"$readEntry{PR}\" (read)";
            $diagnosis .= " vs. \"$suffixes[0]$suffixes[1]\" (suffix)\n";
            if ($readEntry{PR} == 3) {
                $diagnosis .= " (Probable XGap value replaced by Gap4 value $primertype)\n";
                $readEntry{PR} = $primertype;
            } 
            else {
                $diagnosis .= " (Experiment file value $readEntry{PR} accepted)\n";
	    }
            $warnings++;
            $readEntry{RPS} += 16384; # bit 15
        } 
    }
    else {
# for Oracle data: accept the suffix value
        if ($primertype) {
            $readEntry{PR} = $primertype;
        }
        else {
            $readEntry{RPS} += 32768; # bit 16
            $diagnosis .= "! Missing Primer Type for \"$readEntry{PR}\"";
            $warnings++ if (!$fatal);
            $errors++   if  ($fatal);
        }
    }

# determine the default chemistry type (default to undefined)

    $suffixes[2] = 'u' if (!defined($suffixes[2])); # ensure it's definition
    $readEntry{CHT} = $suffixes[2];
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

&logger("<br>** Default Chemistry Type: $readEntry{CHT}<br>");
&logger("Test chemistry in file ${readFileName}SCF<br>");

    my $command = "$SCFREADDIR/get_scf_field ${readFileName}SCF | grep -E '(dye|DYE)'";

#&logger("Command $command<br>");
#    my $chemistry = `$command`;
#&logger("first attempt chemistry='$chemistry' Estat='$?'<br>");
#    undef $chemistry if ($chemistry =~ /load.+disabled/i);
#    if (!$chemistry) {
#&logger("trying to recover:");

        my $chemistry = `$RECOVERDIR/recover.sh $SCFREADDIR/get_scf_field ${readFileName}SCF`;
&logger("recovered chemistry=\"$chemistry\"<br>");
        undef $chemistry if ($chemistry =~ /load.+disabled/i);
#    }
    chomp $chemistry;
&logger("SCF chemistry found: $chemistry<br>");
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
        elsif ($readEntry{CHT} eq 'u' && $chtype ne 'u') {
            $diagnosis .= "! Undefined chemistry type for $chemistry replaced by \"$chtype\"\n";
            $readEntry{CHT} = $chtype;
            $readEntry{RPS} += 32768*2 ; # bit 17 
            $warnings++;
        }
        elsif ($chtype ne $readEntry{CHT}) {
            $diagnosis .= "! Warning: inconsistent chemistry identifier for $chemistry ";
            $diagnosis .= ": \"$readEntry{CHT}\" (file) vs. \"$chtype\" (database table)\n";
            $readEntry{CHT} = $chtype unless ($chtype eq 'u' || !$chtype); # use table value
            $diagnosis .= "  ARCTURUS data base table value $chtype adopted\n" if ($readEntry{CHT} eq $chtype);
            $readEntry{RPS} += 32768*4 ; # bit 18 
            $warnings++;
# if chemtype is not defined in the table, here is an opportunity to update
            if (!$chtype) {
                $CHEMISTRY->update('chemtype',$readEntry{CHT},'identifier',$chemistry, 0, 1);
                $diagnosis .= "CHEMISTRY.chemtype is inserted for chemistry $chemistry\n";
            }
        } 
        $readEntry{CH} = $chemistry;

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
        if ($readEntry{CHT} ne 'u') {
# $readEntry{CHT} = 'f' if ($readEntry{CHT} eq 'e'); # force read with invalid data through (1)  
# $readEntry{CHT} = 'e' if ($readEntry{CHT} eq 't'); # force read through (2)
    # get description from chemistry type
            my $description = $CHEMTYPES->associate('description',$readEntry{CHT},'chemtype');
&logger("test Gelminder description against type $readEntry{CHT}");
            if (@fields) {
&logger("@{fields}\n$fields[1]\n$fields[2]");
        # require both to match
                if (!($description =~ /$fields[1]/i) || !($description =~ /$fields[2]/i)) {
#$diagnosis = "fields: '$fields[0]' '$fields[1]' '$fields[2]'\n";
                    $diagnosis .= "! Mismatch between Gelminder: '$field' and description: ";
                    $diagnosis .= "'$description' for chemtype $readEntry{CHT}\n";
        # try to recover by re-assembling and testing the description field
                    $field = $fields[1].' '.$fields[2];
                    $field =~ s/^\s*(primer|terminator)\s*(\S*.)$/$2 $1/;
      $diagnosis .= "test field: $field<br>";
                    $field =~ s/Rhoda/%hoda/i; # to avoid case sensitivities 
                    $field =~ s/\s+|\./%/g;
                    my $chtype = $CHEMTYPES->associate('chemtype',$field,'description');
                    if ($chtype && ref($chtype) ne 'ARRAY') {
                        $diagnosis .= "Chemistry type recovered as: $chtype\n";
                        $readEntry{CHT} = $chtype;
                        $warnings++;
                    }
                    else {
                        $errors++   if  ($fatal && $readEntry{CHT} ne 'l');
                        $warnings++ if (!$fatal || $readEntry{CHT} eq 'l' && $description =~ /Licor/i);
                    } 
                    $readEntry{RPS} += 32768*4 ; # bit 18 
               }
            }
            else {
        # assume CHT is correct
                $diagnosis .= "! Warning: incomplete Chemistry data in phredpar.dat\n";
                $readEntry{RPS} += 32768*2 ; # bit 17 
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
                        $readEntry{CHT} = $CHEMTYPES->associate('chemtype',$n,'number');
&logger(" ... identified (type = $readEntry{CHT})");
                    }
                }
            }
            if ($readEntry{CHT} eq 'u') {
                $diagnosis .= "Unrecognized Gelminder chemistry type\n";
                $readEntry{RPS} += 32768*8 ; # bit 19 
                $warnings++; 
            }
        }
        $readEntry{CH} = $chemistry;

        if (!$errors) {
            $CHEMISTRY->newrow('identifier', $chemistry);
            $CHEMISTRY->update('chemtype'  , $readEntry{CHT});
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
        if ($readEntry{CHT} eq 'u') {
            $diagnosis .= "! Undefined ";
 $diagnosis .= "chemistry=$readEntry{CH} ";
        }
        elsif ($readEntry{CHT}) {
            $diagnosis .= "! Unverified ($readEntry{CHT}) ";
            delete $readEntry{CH}; # remove meaningless info
        }
        else { 
            $diagnosis .= "! Unspecified ";
 $diagnosis .= "chemistry=$readEntry{CH} ";
        }
        $diagnosis .= "chemistry: no SCF info available ";
        $diagnosis .= "($SCFREADDIR/get_scf_field ${readFileName}SCF)\n";
        $readEntry{RPS} += 32768*16 ; # bit 20 
print "REPORT $report<br>";
    }
}
# error reporting coded as:

# bit 17  : Incomplete Chemistry data (recovered)
# bit 18  : Inconsistent Chemistry description
# bit 19  : Unrecognised Gelminder chemistry type
# bit 20  : Missing chemistry

#############################################################################

sub insert {
# insert a new record in the READS database table
    my $self = shift;
    $self->list(1);

# get the columns of the READS table (all of them) and find the reads key

    if (!(keys %linkEntry)) {
# initialize the correspondence between tags and column names
        my $READMODEL = $READS->findInstanceOf('arcturus.READMODEL');
        if (!$READMODEL) {
            $diagnosis = "READMODEL handle NOT found\n";
            $errors++;
        }
        else {
            my $hashes = $READMODEL->associate('hashrefs','where',1,-1);
# build internal linkEntry hash
            if (ref($hashes) eq 'ARRAY') {
                foreach my $hash (@$hashes) {
                    my $column = $hash->{'column_name'};
                    $linkEntry{$column} = $hash->{'item'};
                }
            }
            else {
                $diagnosis .= "READMODEL cannot be read\n";
                $errors++;
            }
        }
        return 0,0 if $errors;
    }

# get the links to the dictionary tables

    my $linkhash = $READS->traceTable();

    undef my %columntags;
    foreach my $key (keys %$linkhash) {
# get the flat file item correspondiong to the column name in $1
        if ($key =~ /\.READS\.(\S+)$/) {
            $columntags{$key} = $linkEntry{$1};
        }
    }

# now go through all columns and update the dictionary tables

    foreach my $key (sort keys %columntags) {
        my $tag = $columntags{$key}; my $tagHasValue = 0;
        $tagHasValue = 1 if (defined($readEntry{$tag}) && $readEntry{$tag} =~ /\w/);
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
                $linkhandle->counter($columns[0],$readEntry{$tag});
                my $reference = $linkhandle->associate($linkcolumn,$readEntry{$tag},$columns[0], 0, 0, 1);
                $readEntry{$tag} = $reference;
            }
            elsif (!@columns) {
                my $level = $linkhandle->counter($linkcolumn,$readEntry{$tag});
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

    undef my ($counted, $parity);
    if (!defined($readEntry{ID}) || $readEntry{ID} !~ /\w/) {
        $diagnosis .= "! Undefined or Invalid Read Name\n";
        $errors++;
    } 
    else {
        $counted = 1;
        undef my @columns;
        undef my @cvalues;
	foreach my $column (keys %linkEntry) {
            my $tag = $linkEntry{$column};
            if ($tag ne 'ID' && $tag ne 'RN' && $column ne 'readname') {
                my $entry = $readEntry{$tag};
                if (defined($entry) && $entry =~ /\S/) {
                    push @columns,$column;
                    push @cvalues,$entry;
                    $counted++;
                }
            }
        }
        $parity = @columns + 1;
        if (!$READS->newrow('readname',$readEntry{ID},\@columns,\@cvalues)) {
# here develop update of previously loaded reads
            $diagnosis = "Failed to create new entry for read $readEntry{ID}";
            $diagnosis .= ": $READS->{errors}" if $READS->{errors};
            $diagnosis .= "\n";
            $counted = 0;
            $errors++;
        } 
    }
    return $counted, $parity;
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
        updated =>    "02 Jul 2002",
        date    =>    "15 Aug 2001",
    };
}

1;
