package ReadsRecall;

#############################################################################
#
# retrieve a READ from the ARCTURUS database
#
#############################################################################

use strict;

use Compress;

#############################################################################
# Global variables
#############################################################################

my $dbREADS;  # hash reference to READS database table
my $Compress; # reference to encoding/decoding module
my $Layout;   # hash reference to LAYOUT database table

#############################################################################
# constructor item init; serves only to create a handle the stored READS
# database and the Compress module
#############################################################################

sub init {
# initialize the readobjects constructor module
    my $prototype = shift;
    my $datatable = shift; # handle of DbaseTable for READS 

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $dbREADS  = $datatable;
    $Compress = Compress->new();
    $Layout   = $dbREADS->findInstanceOf('arcturus.READMODEL');

    bless ($self, $class);
    return $self;
}

#############################################################################
# constructor item new; serves only to create a handle to a stored read
# subsequently ->getRead will load a (new) read
#############################################################################

sub new {
# create a new Read object
    my $prototype = shift;
    my $readitem  = shift;
    my $itsvalue  = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $self->{readhash} = {}; # hash table for read data
    $self->{sequence} = []; # array of DNA sequence
    $self->{quality}  = []; # array of quality data
    $self->{range}    = []; # base range of sufficient quality data
    $self->{Index}    = []; # array of data index
    $self->{Status}   = {}; # error status reporting
    $self->{links}    = {}; # links to items in other data tables

# okay, now select how to find the data and build the read object

    if (defined($itsvalue)) {
# select read using readitem and itsvalue
        &getLabeledRead($self, $readitem, $itsvalue);

    } elsif (defined($readitem)) {
# select read as number or as name
        if ($readitem =~ /[0-9]+/  && !($readitem =~ /[a-z]/i)) {
            &getNumberedRead($self,$readitem);
        } else {
print "getNamedRead $readitem <br>";
            &getNamedRead($self,$readitem);
        }
    }

    bless ($self, $class);
    return $self;
}

#############################################################################

sub getNamedRead {
# ingest a new read, return reference to hash table of Read items
    my $self = shift;
    my $readname = shift; # the name of the read (unique)

    &clear($self); # clear all buffers
    &loadReadData ($self,$readname) if defined($readname);

    return &status($self,0);
}

#############################################################################

sub getNumberedRead {
# reads a numbered Read file 
    my $self     = shift;
    my $number   = shift;

    my $status = $self->{Status};

# retrieve the (unique, if any) read name for the given number 

    my $readname = $dbREADS->associate('readname',$number,'read_id',0);

    &clear($self);
    if ($readname) {
        &loadReadData ($self,$readname);
    } else {
        $status->{diagnosis} .= "! Read nr. $number does not exist";
        $status->{errors}++;
    }

    return &status($self,0);
}

#############################################################################

sub getLabeledRead {
# reads a Read file for a given value of a given column 
    my $self     = shift;
    my $readitem = shift;
    my $itsvalue = shift;

    my $status = $self->{Status};

# retrieve the (first encountered) read name for the specified condition 

    my $readname = $dbREADS->associate('readname',$itsvalue,$readitem);

    if ($readname) {
        &clear($self); # clear all buffers
        &loadReadData ($self,$readname);
    } else {
        $status->{diagnosis} .= "! No read found for $readitem = $itsvalue";
        $status->{errors}++;
    }

    return &status($self,0);
}

#############################################################################
# private methods: clear  getReadData
#############################################################################

sub clear {
# reset internal buffers and counters
    my $self = shift;
    my $mode = shift;

    my $status = $self->{Status};

    undef @{$self->{sequence}};
    undef @{$self->{quality}};
    undef @{$self->{Index}};
    undef @{$self->{range}};
    undef $self->{sstring};
    undef $self->{qstring};
# reset error logging
    undef $status->{diagnosis};
    $status->{errors}   = 0;
    $status->{warnings} = 0;
}

#############################################################################

sub loadReadData {
# reads a Read file
    my $self = shift;
    my $name = shift;

    my $status = $self->{Status};
    my $range  = $self->{range};

# retrieve the (uniquely) named read as reference to a (temporary) hash table 

    $name =~ s/^\s*|\s*$//g; # remove possible leading or trailing blanks
    my $hash = $dbREADS->associate('hashref',$name,'readname',0);
#    print "readname = $name  hash=$hash lastquery=$dbREADS->{lastQuery}<br>";

# if the read exists, build the (local) buffers with the sequence data

    my $scount = 0; my $sstring = 0;
    my $qcount = 0; my $qstring = 0;

    my $length = 0;

    if (defined($hash)) {

        $self->{readhash} = $hash;
        undef $self->{sequence};
        undef $self->{quality};

# decode the sequence

        if (defined($hash->{scompress}) && defined($Compress)) {
            if (defined($hash->{sequence})) {
                my $dc = $hash->{scompress};
               ($scount, $sstring) = $Compress->sequenceDecoder($hash->{sequence},$dc,0);
#               ($scount, $sstring) = $Compress->huffmanDecoder ($hash->{sequence}) if ($dc == 2);
                if (!($sstring =~ /\S/)) {
                    $status->{diagnosis} .= "! Missing or empty sequence\n";
                    $status->{errors}++;
                } else {
                    $sstring =~ s/\s+//g;
                    $sstring =~ s/(.{60})/$1\n/g;
                }
            } else {
                $status->{diagnosis} .= "! Missing DNA sequence\n";
                $status->{errors}++;   
            }
        } elsif (defined($hash->{scompress})) {
            $status->{diagnosis} .= "! Missing parameter for Compress::Compress\n";
            $status->{errors}++;
        }

# decode the quality data

        if (defined($hash->{qcompress}) && defined($Compress)) {
            if (defined($hash->{quality})) {
                my $dq = $hash->{qcompress};
               ($qcount, $qstring) = $Compress->qualityDecoder($hash->{quality},$dq);
#               ($qcount, $qstring) = $Compress->huffmanDecoder($hash->{quality}) if ($dq == 2);
                if (!($qstring =~ /\S/)) {
                    $status->{diagnosis} .= "! Missing or empty quality data\n";
                    $status->{errors}++;
                } else {
                    $qstring =~ s/\b(\d)\b/0$1/g;
                    $qstring =~ s/(.{90})/$1\n/g;
                }
            } else {
                $status->{diagnosis} .= "! Missing Quality Data\n";
                $status->{errors}++;
            }
        }

    } elsif ($name) {
        $status->{diagnosis} .= "! READ $name NOT found in ARCTURUS READS\n";
        $status->{errors} += 2;
    } else {
        $status->{diagnosis} .= "! MISSING readname in ReadsRecall\n";
        $status->{errors}++;
     }

# cleanup the sequences and store in buffers @sequnce and @quality

    if (!$status->{errors}) {

        $self->{sstring} = $sstring;
        $self->{qstring} = $qstring;
        @{$self->{sequence}} = split /\s+|/,$sstring;
        @{$self->{quality}}  = split  /\s+/,$qstring;

    # test lengths against database

        $length = $hash->{slength} if (defined($hash->{slength}));
        $length = $scount if ($scount == $qcount && $length == 0); # temporary recovery
        if ($scount != $qcount || $scount != $length || $length == 0) {
            $status->{diagnosis} .= "! Sequence length mismatch: $scount, $qcount, $length\n";
            $status->{errors}++;    
        } else {
        # default mask
            $range->[0] = 1;
            $range->[1] = $length;
        }
    }

# apply masking (counted from 1, not 0!)

    $range->[0] = $hash->{lqleft}  + 1  if ($hash->{lqleft});
    $range->[1] = $hash->{lqright} - 1  if ($hash->{lqright});
    $range->[0] = 1 if ($range->[0] <= 0); # protection just in case
    $range->[1] = $length if (!$range->[1] || $range->[1] > $length); # ibid

#    print "window: $range->[0]  $range->[1]\n";

    if (defined($hash->{cvleft})  && $hash->{cvleft}  >= $range->[0]) {
        $range->[0] =  $hash->{cvleft} + 1;
    }
    if (defined($hash->{cvright}) && $hash->{cvright} <= $range->[1]) {
        $range->[1] = $hash->{cvright} - 1;
    }

#    print "window: $range->[0]  $range->[1]\n";

    if (defined($hash->{svleft})  && $hash->{svleft}  >= $range->[0]) {
        $range->[0] =  $hash->{svleft} + 1;
    }
    if (defined($hash->{svright}) && $hash->{svright} <= $range->[1]) {
        $range->[1] = $hash->{svright} - 1;
    }

#    print "window: $range->[0]  $range->[1]\n";
    $range->[0]--;
    $range->[1]--;
#    print "window: $range->[0]  $range->[1]\n";

#print "status $status->{errors} $status->{diagnosis}<br>";
#    &indexing($self);
}

#############################################################################

sub indexing {
# build index on active DNA sequence
    my $self = shift;

    my %enumerate = ('A','0','C','1','G','2','T','3','U','3',
                     'a','0','c','1','g','2','t','3','u','3');

    my $sequence = $self->{sequence};
    my $range    = $self->{range};
    my $index    = $self->{Index};

    for (my $i=0 ; $i<=$range->[1] ; $i++) {
        $$index[$i] = 0;
        if ($i >= $range->[0]+3 && $i <= $range->[1]-3) {
            my $accept = 1;
            for (my $j=0 ; $j<7 ; $j++) {
                if (defined($enumerate{$$sequence[$i+$j-3]}) && $accept) {
                    $$index[$i] *= 4 if ($$index[$i]);
                    $$index[$i] += $enumerate{$$sequence[$i+$j-3]};
                } else {
                    $$index[$i] = -1;
                    $accept = 0;
                }
            }
        }
    }
#    print "index: @{$index}\n";
}

#############################################################################
# public methods for access and testing
#############################################################################

sub edit {
# replace individual bases by a specified new value in lower case
    my $self = shift;
    my $edit = shift; # the edit recipe as string

    my $sequence = $self->{sequence};

# edits encoded as string nnnCcnnnCc., to replace existing base nnn S by s
# successful replacement only if base nr. nnn is indeed S

    undef my $miss;
    while ($edit =~ s/^(\d+)([ACTGU-])([actgu])//) {
        if (defined($$sequence[$1]) && $$sequence[$1] eq $2) {
                $$sequence[$1] = $3;
        } else {
            $miss .= $1.$2.$3;
        }
    }
    $miss .= $edit if ($edit);
    return $miss;
}

#############################################################################

sub align {
# align segment of read to consensus contig
    my $self = shift;
    my $alignment = shift;


}

#############################################################################

sub status {
# query the status of the table contents; define list for diagnosis
    my $self = shift; 
    my $list = shift;

    my $hash = $self->{readhash};
    my $status = $self->{Status};

    if (defined($list) && $list>0) {
    # list > 0 for summary of errors, > 1 for warnings as well
        my $n = keys %{$hash};
        $hash->{readname} = "UNDEFINED" if (!$hash->{readname});
        print STDOUT "Read $hash->{readname}: $n items found; ";
        print STDOUT "$status->{errors} errors, $status->{warnings} warnings\n";
        $list-- if (!$status->{errors}); # switch off if only listing of errors
        print STDOUT "$status->{diagnosis}" if ($list && defined($status->{diagnosis}));
    }

    $status->{errors};
}

#############################################################################

sub list {
# list current data (straight list if html=0, HTML format if html=1)
    my $self = shift;
    my $html = shift;

    undef my $report;

    my $hash   = $self->{readhash};
    my $status = $self->{Status};
    my $links  = $self->{links};

    undef my $readname;
    $readname =  $hash->{readname} if (defined( $hash->{readname}));
    $readname =  $hash->{ID} if (!$readname && defined( $hash->{ID}));
    $readname = "UNDEFINED" if (!$readname);
    $report .= "<CENTER><p><h3><b>" if ($html);
    $report .= "\nContents of read $readname:\n\n";
    $report .= "</b><h3>" if ($html);
    $report .= "<CENTER><TABLE BORDER=1 CELPADDING=2 WIDTH=100%>" if ($html);
    $report .= "<TR><TH>key</TH><TH ALIGN=LEFT>value</TH></TR>\n" if ($html);

    my $n = 0;
    foreach my $key (sort keys (%{$hash})) {
        undef my $string;
        my $wrap = 'WRAP';
        if (defined($hash->{$key})) { 
            $string = $self->{sstring} if ($key eq 'sequence' || $key eq 'SQ');
            $string = $self->{qstring} if ($key eq 'quality'  || $key eq 'AV');
            if ($string && $html) {
                $string = "<code>$string</code>";
                $string = "<small>$string</small>" if ($key eq 'quality'  || $key eq 'AV');
                $string =~ s/\n/\<\/code>\<BR\>\<code\>/g;
                $wrap = 'NOWRAP';
	    }
            $string = $hash->{$key} if (!$string);
            $string = "&nbsp" if ($string !~ /\S/);
        # test for linked information
            if ($links->{$key}) {
                my ($dbtable,$dbalias,$dbtarget) = split ('/',$links->{$key});
                my $alias = $dbtable->associate($dbalias,$key,$dbtarget);
                $key .= " ($alias)" if ($alias); 
            }
            $n++;
        } else {
            $string = "&nbsp";
	}
        $report .= "$key = $string\n" if (!$html);
        $report .= "<TR><TD ALIGN=CENTER>$key</TD><TD $wrap>$string</TD></TR>\n" if ($html);
    }
    $report .= "</TABLE><P>\n" if ($html);

    if (!$html || $status->{errors}) {
        $report .= "\n$n items found; $status->{errors} errors";
        $report .= ", $status->{warnings} warnings\n";
        $report .= "<P>" if ($html);
        $report .= "$status->{diagnosis}\n" if (defined($status->{diagnosis}));
    }

    $report .= "</CENTER>\n" if ($html);
    
    return $report;
}

#############################################################################

sub touch {
# get the reference to the data hash; possibly apply key translation 
    my $self = shift;

    my $hash = $self->{readhash};

    if ($Layout) {
        foreach my $key (keys (%{$hash})) {
            my $newkey = $Layout->associate('item',$key,'column_name');
            if (defined($newkey)) {
                $hash->{$newkey} = $hash->{$key};
                delete $hash->{$key};
            }
        }
    }

    return \%{$hash};
}


#############################################################################

sub link {
# link a table item to a value in anotherv table
    my $self     = shift;
    my $dbtable  = shift; # the databse table to be linked
    my $dbtarget = shift; # the table item to be replaced
    my $dbalias  = shift; # by the alias value


}

#############################################################################

sub minimize {
# reduce the amount of space occupied by this read (irreversible)
    my $self = shift;

# remove all data except from the sequence & quality arrays

    foreach my $key (keys (%$self)) {
        if ($key ne 'sequence' && $key ne 'quality' && $key ne 'index') {
            if (ref($key) =~ /HASH/) {
                foreach my $qey (keys (%$key)) {
                    delete $key->{$qey};
                }
            } elsif (ref($key) =~ /ARRAY/) {
		undef @{$self->{$key}};
            }
            delete $self->{$key};
        }
    }

}

#############################################################################
#############################################################################

sub colofon {
    return colofon => {
        author  => "E J Zuiderwijk",
        id      =>  "ejz, group 81",
        version =>             0.8 ,
        date    =>    "15 Jan 2001",
    };
}

1;




