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

my $Compress; # reference to encoding/decoding module
my $MODEL;    # reference to READMODEL database table
my $READS;    # table handle to the READS table

my %instance; # hash for all ReadsRecall instances 

my %reverse;  # hash for reverse substitutions of DNA

#############################################################################
# constructor item init; serves only to create a handle the stored READS
# database and the Compress module
#############################################################################

sub init {
# initialize the readobjects constructor
    my $prototype = shift;
    my $tblhandle = shift || &dropDead; # handle of DbaseTable for READS 

    my $class = ref($prototype) || $prototype;
    my $self  = {};

# test if input table handle is of the READS table

    $READS = $tblhandle->spawn('READS','self');

    $Compress = Compress->new(@_); # build decoding table

    %reverse = ( A => 'T', T => 'A', C => 'G', G => 'C', '-' => '-',
                 a => 't', t => 'a', c => 'g', g => 'c',
                 U => 'A', u => 'a');

    bless ($self, $class);
    return $self;
}

#############################################################################

sub dropDead {
    my $text = shift;

    die "$text" if $text; 

    die "module 'ReadsRecall' must be initialized with a READS table handle";
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

    bless ($self, $class);

    $self->{readhash} = {}; # hash table for read data
    $self->{sequence} = []; # array of DNA sequence
    $self->{quality}  = []; # array of quality data
    $self->{range}    = []; # base range of sufficient quality data
    $self->{toContig} = {}; # read-contig mapping
    $self->{contig}   = ''; # reference

    $self->{index}    = []; # array of data index
    $self->{status}   = {}; # error status reporting
    $self->{links}    = {}; # links to items in other data tables

# okay, now select how to find the data and build the read object

    if (ref($readitem) eq 'HASH') {
# build the read instance directly from the input hash
# print "1 new read for hash $readitem \n";
        &loadReadData(0,$self,$readitem);        
        $readitem = $self->{readhash}->{read_id} || $self->{readhash}->{readname} || 0;
    }

    elsif (defined($itsvalue)) {
# select read using readitem and itsvalue
        $self->getLabeledRead($readitem, $itsvalue);
        $readitem = $self->{readhash}->{read_id};
    } 

    elsif (defined($readitem)) {
# select read as number or as name
print "get read $readitem \n";
        if ($readitem =~ /[0-9]+/  && !($readitem =~ /[a-z]/i)) {
print "numbered read \n";
            $self->getNumberedRead($readitem);
        }
        else {
            $self->getNamedRead($readitem);
        }
    }

    $instance{$readitem} = $self if $readitem; # add to class inventory

    return $self;
}

#############################################################################

sub spawnReads {
# spawn a number of read objects for the given read-IDs
    my $self    = shift;
    my $readids = shift; # reference to array of read_ids
    my $items   = shift || 'hashrefs'; # (optional) selected readitems

    my $status = $self->{status};
    $status->{errors} =  0;
    $status->{report} = '';

    if ($items ne 'hashrefs') {
# there must be a minimum set of read items
        $items .= ',scompress' if ($items =~ /sequence/ && $items !~ /scompress/);
        $items .= ',qcompress' if ($items =~ /quality/  && $items !~ /qcompress/);
        $items .= ',slength'   if ($items !~ /compress/ && $items !~ /slength/);
        $items .= ',read_id'   if ($items !~ /read_id/);
        $items .= ',readname'  if ($items !~ /readname/);
        $items .= ',chemistry' if ($items !~ /chemistry/);
        $items .= ',strand'    if ($items !~ /strand/);
    }

    undef my @reads;
    if (ref($readids) ne 'ARRAY') {
        push @reads,$self->new($readids);
    }
    elsif (my $hashrefs = $READS->associate($items,$readids,'read_id',{returnScalar => 0})) {
        undef my %reads;
        foreach my $read (@$readids) {
            $reads{$read}++;
        }
        foreach my $hash (@$hashrefs) {
            push @reads,$self->new($hash);
            delete $reads{$hash->{read_id}}; # remove from list
        }
# test number of read instances against input
        if (my $leftover = keys(%reads)) {
            $status->{errors}++;
            $status->{report} = "$leftover reads NOT spawned!";
            return 0;
        }
    }

    return \@reads;
}

#############################################################################

sub findInstanceOf {
# find the instance of the ReadsRecall class %instances
    my $self = shift;
    my $name = shift;

    if ($name) {
        return $instance{$name} || 0;
    }
    else {
        return \%instance;
    }  
}

#############################################################################

sub getNamedRead {
# ingest a new read, return reference to hash table of Read items
    my $self     = shift;
    my $readname = shift; # the name of the read


    my $status = $self->clear;

    &dropDead if !$READS;

    $readname =~ s/^\s*|\s*$//g; # remove possible leading or trailing blanks
    my $readhash = $READS->associate('hashref',$readname,'readname');

    if ($readhash) {
        &loadReadData(0,$self,$readhash);
    }
    else {
        $status->{report} .= "! Read $readname NOT found in ARCTURUS READS\n";
        $status->{errors} += 2;
    }

    return $self->status;
}

#############################################################################

sub getNumberedRead {
# reads a numbered Read file 
    my $self     = shift;
    my $number   = shift;

    my $status = $self->clear;

    &dropDead if !$READS;

    my $readhash = $READS->associate('hashref',$number,'read_id');

    if ($readhash) {
        &loadReadData(0,$self,$readhash);
    }
    else {
        $status->{report} .= "! Read nr. $number does not exist";
        $status->{errors}++;
    }

    return $self->status;
}

#############################################################################

sub getLabeledRead {
# reads a Read file for a given value of a given column 
    my $self     = shift;
    my $readitem = shift;
    my $itsvalue = shift;

    my $status = $self->clear;

    &dropDead if !$READS;

# retrieve the (first encountered) read name for the specified condition 

    my $readhash = $READS->associate('readhash',$itsvalue,$readitem);

    if ($readhash) {
        &loadReadData(0,$self,$readhash);
    } 
    else {
        $status->{report} .= "! No read found for $readitem = $itsvalue";
        $status->{errors}++;
    }

    return $self->status;
}

#############################################################################

sub clear {
# reset internal buffers and counters
    my $self = shift;
    my $mode = shift;

    my $status = $self->{status};

    undef @{$self->{sequence}};
    undef @{$self->{quality}};
    undef @{$self->{index}};
    undef @{$self->{range}};
    undef $self->{sstring};
    undef $self->{qstring};

# reset error logging

    undef $status->{report};
    $status->{errors}   = 0;
    $status->{warnings} = 0;

    return $status;
}

#############################################################################
# private protected method
#############################################################################

sub loadReadData {
# reads a Read file
    my $lock = shift;
    my $self = shift;
    my $hash = shift;

    &dropDead('Invalid usage of loadReadData method') if $lock;

    my $status = $self->{status};
    my $range  = $self->{range};

# if the read exists, build the (local) buffers with the sequence data

    my $scount = 0; my $sstring = 0;
    my $qcount = 0; my $qstring = 0;
    my $length = 0;

    if (defined($hash) && ref($hash) eq 'HASH') {

        $self->{readhash} = $hash;
        undef @{$self->{sequence}};
        undef @{$self->{quality}};

# decode the sequence

        if (defined($hash->{scompress}) && defined($Compress)) {

            if (defined($hash->{sequence})) {
                my $dc = $hash->{scompress};
               ($scount, $sstring) = $Compress->sequenceDecoder($hash->{sequence},$dc,0);
                if (!($sstring =~ /\S/)) {
                    $status->{report} .= "! Missing or empty sequence\n";
                    $status->{errors}++;
                }
                else {
                    $sstring =~ s/\s+//g;
                    $sstring =~ s/(.{60})/$1\n/g;
                    $qcount = $scount; # preset for absent quality data
                }
            }
            else {
                $status->{report} .= "! Missing DNA sequence\n";
                $status->{errors}++;   
            }
        }
        elsif (defined($hash->{scompress})) {
            $status->{report} .= "! Cannot access the Compress module\n";
            $status->{errors}++;
        }

# decode the quality data (allow for its absence)

        if (defined($hash->{qcompress}) && defined($Compress)) {

            if (defined($hash->{quality})) {
                my $dq = $hash->{qcompress};
               ($qcount, $qstring) = $Compress->qualityDecoder($hash->{quality},$dq);
                if (!($qstring =~ /\S/)) {
                    $status->{report} .= "! Missing or empty quality data\n";
                    $status->{errors}++;
                }
                else {
                    $qstring =~ s/\b(\d)\b/0$1/g;
                    $qstring =~ s/(.{90})/$1\n/g;
                }
            }
        }
    } 
    else {
        $status->{report} .= "! MISSING readname in ReadsRecall\n";
        $status->{errors}++;
    }

# cleanup the sequences and store in buffers @sequnce and @quality

    if (!$status->{errors}) {

        $self->{sstring} = $sstring;
        $self->{qstring} = $qstring;
        @{$self->{sequence}} = split /\s+|/,$sstring if $sstring;
        @{$self->{quality}}  = split  /\s+/,$qstring if $qstring;

# test length against database value

        $length = $hash->{slength} if (defined($hash->{slength}));
        $length = $scount if ($scount == $qcount && $length == 0); # temporary recovery
        if ($scount != $qcount || $scount != $length || $length == 0) {
            $status->{report} .= "! Sequence length mismatch: $scount, $qcount, $length\n";
            $status->{errors}++;    
        }
        else {
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
        $range->[0] = $hash->{cvleft}  + 1;
    }
    if (defined($hash->{cvright}) && $hash->{cvright} <= $range->[1]) {
        $range->[1] = $hash->{cvright} - 1;
    }

#    print "window: $range->[0]  $range->[1]\n";

    if (defined($hash->{svleft})  && $hash->{svleft}  >= $range->[0]) {
        $range->[0] = $hash->{svleft}  + 1;
    }
    if (defined($hash->{svright}) && $hash->{svright} <= $range->[1]) {
        $range->[1] = $hash->{svright} - 1;
    }

    $range->[0]--;
    $range->[1]--;
}

#############################################################################
# read-to-contig mapping
#############################################################################

sub readToContig {
# input of reads to contig mapping
    my $self     = shift;
    my $maphash  = shift; # hash with mapping data of individual read section

    return if ($maphash->{deprecated} && $maphash->{deprecated} !~ /M|N/);  

    my $rtoc = $self->{toContig};

    my $prstart = $maphash->{prstart};
    my $prfinal = $maphash->{prfinal};
    my $rlength = $prfinal - $prstart + 1;
    my $mapkey = sprintf("%04d",$prstart).sprintf("%04d",$prfinal);
    undef @{$rtoc->{$mapkey}}; $rtoc = $rtoc->{$mapkey};
    my $pcstart = $maphash->{pcstart};
    my $pcfinal = $maphash->{pcfinal};
    my $k = 0; $k = 1 if ($pcfinal < $pcstart);
# in case of inversion (k=1) ensure contig window is aligned by swapping indices
    $rtoc->[$k]   = $prstart; $rtoc->[1-$k] = $prfinal;
    $rtoc->[2+$k] = $pcstart; $rtoc->[3-$k] = $pcfinal;
    my $clength = $rtoc->[3] - $rtoc->[2] + 1;

    $self->{contig} = $maphash->{contig_id};

    $self->contigRange;

    return $clength - $rlength; # should be 0
}

#############################################################################

sub shiftMap {
# linear shift on reads to contig mapping
    my $self   = shift;
    my $shift  = shift;
    my $contig = shift; # (optional) new contig reference

    my $rtoc = $self->{toContig};
    foreach my $key (keys %$rtoc) {
        my $map = $rtoc->{$key};
        $map->[2] += $shift; 
        $map->[3] += $shift;
    } 

    $self->contigRange;

    $self->{contig} = $contig if $contig;
}

#############################################################################

sub invertMap {
# invert the to contig mapping given length of contig
    my $self   = shift;
    my $length = shift || return; # length of contig
    my $contig = shift; # (optional) new contig reference

# invert the contig mapping window

    my $rtoc = $self->{toContig};
    foreach my $key (keys %$rtoc) {
        my $map = $rtoc->{$key};
        $map->[2] = $length - $map->[2] + 1; 
        $map->[3] = $length - $map->[3] + 1;
# ensure contig window is aligned by swapping boundaries
        if ($map->[2] > $map->[3]) {
            my $store = $map->[0]; 
            $map->[0] = $map->[1]; 
            $map->[1] = $store;
            $store = $map->[2]; 
            $map->[2] = $map->[3]; 
            $map->[3] = $store;
        }
    }

# replace sequence by complement (?)

    my $sequence = $self->{sequence};
    foreach my $allele (@$sequence) {
        $allele = $reverse{$allele} || '-';
    }

    $self->contigRange;

    $self->{contig} = $contig if $contig;    
}

#############################################################################

sub contigRange {
# get the coverage of this read on the contig
    my $self = shift;

    $self->{clower} = 0;
    $self->{cupper} = 0;
    $self->{ranges} = 0;

    my $rtoc = $self->{toContig};
    foreach my $key (keys %$rtoc) {
        my $map = $rtoc->{$key};
        $self->{clower} = $map->[2] if (!$self->{clower} || $map->[2] < $self->{clower}); 
        $self->{cupper} = $map->[3] if (!$self->{cupper} || $map->[3] > $self->{cupper});
        $self->{ranges}++;
    }     
}

#############################################################################

sub inContigWindow {
# sample part of read in specified contig window
    my $self   = shift;
    my $wstart = shift; # start on contig
    my $wfinal = shift; # end on contig (start<end ?)

    undef my @output; undef my @quality;
    for (my $i = $wstart; $i <= $wfinal; $i++) {
	$output[$i-$wstart] = '-';
	$quality[$i-$wstart] = 0;
    }

    my $rtoc = $self->{toContig};
    my $sequence = $self->{sequence};
    my $quality  = $self->{quality};
    
    my $count = 0;
    my $length = 0;
    my $reverse = 0;
    foreach my $key (keys %$rtoc) {
        my $map = $rtoc->{$key};
        my $cstart = $wstart; $cstart = $map->[2] if ($cstart < $map->[2]); 
        my $cfinal = $wfinal; $cfinal = $map->[3] if ($cfinal > $map->[3]);
        if ($cstart <= $cfinal && $map->[0] <= $map->[1]) { # aligned
            my $j = $map->[0] - $map->[2] - 1; 
            for (my $i = $cstart; $i <= $cfinal; $i++) {
                $output[$i - $wstart] = $sequence->[$j + $i];
                $quality[$i - $wstart] = $quality->[$j + $i] if $quality;
                $length = $i - $wstart + 1  if (($i - $wstart + 1) > $length);
            }
            $count += $cfinal - $cstart + 1;
        }
        elsif ($cstart <= $cfinal) { # counter aligned
            my $j = $map->[0] + $map->[2] - 1;
            for (my $i = $cstart; $i <= $cfinal; $i++) {
                my $allele = $sequence->[$j - $i];
                $output[$i - $wstart] = $reverse{$allele} || '-';
                $quality[$i - $wstart] = $quality->[$j - $i] if $quality;
                $length = $i - $wstart + 1  if (($i - $wstart + 1) > $length);
            }
            $count += $cfinal - $cstart + 1;
        }
    }

    if ($length) {
        push @output,' ';
        push @output,'R' if $reverse;
        undef my @SQ;
        $SQ[0] = \@output;
        $SQ[1] = \@quality if $quality;
        $SQ[2] = $length;
        $SQ[3] = $self->{readhash}->{chemistry};
        $SQ[4] = $self->{readhash}->{strand};
        $SQ[5] = $count;
        return \@SQ;
    }
    else {
        return 0; # no data in window
    }
}

#############################################################################
#############################################################################

sub indexing {
# build index on active DNA sequence
    my $self = shift;

    my %enumerate = ('A','0','C','1','G','2','T','3','U','3',
                     'a','0','c','1','g','2','t','3','u','3');

    my $sequence = $self->{sequence};
    my $range    = $self->{range};
    my $index    = $self->{index};

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
    my $status = $self->{status};

    if (defined($list) && $list>0) {
    # list > 0 for summary of errors, > 1 for warnings as well
        my $n = keys %{$hash};
        $hash->{readname} = "UNDEFINED" if (!$hash->{readname});
        print STDOUT "Read $hash->{readname}: $n items found; ";
        print STDOUT "$status->{errors} errors, $status->{warnings} warnings\n";
        $list-- if (!$status->{errors}); # switch off if only listing of errors
        print STDOUT "$status->{report}" if ($list && defined($status->{report}));
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
    my $status = $self->{status};
    my $links  = $self->{links};

    undef my $readname;
    $readname =  $hash->{readname} if (defined( $hash->{readname}));
    $readname =  $hash->{ID} if (!$readname && defined( $hash->{ID}));
    $readname = "UNDEFINED" if (!$readname);
    $report .= "<CENTER><h3>" if ($html);
    $report .= "\nContents of read $readname:\n\n";
    $report .= "</h3></center>" if ($html);
    $report .= "<CENTER><TABLE BORDER=1 CELPADDING=2 VALIGN=TOP WIDTH=98%>" if ($html);
    $report .= "<TR><TH>key</TH><TH ALIGN=LEFT>value</TH></TR>" if ($html);

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
        $report .= "<TR><TD ALIGN=CENTER>$key</TD><TD $wrap>$string</TD></TR>" if ($html);
    }
    $report .= "</TABLE><P>" if ($html);

    if (!$html || $status->{errors}) {
        $report .= "\n$n items found; $status->{errors} errors";
        $report .= ", $status->{warnings} warnings\n";
        $report .= "<P>" if ($html);
        $report .= "$status->{report}\n" if (defined($status->{report}));
    }

    $report .= "</CENTER>" if ($html);
    
    return $report;
}

#############################################################################

sub touch {
# get the reference to the data hash; possibly apply key translation 
    my $self = shift;

    $MODEL = $READS->findInstanceOf('arcturus.READMODEL') if !$MODEL;

    my $hash = $self->{readhash};

    if ($MODEL) {
        foreach my $key (keys %$hash) {
            my $newkey = $MODEL->associate('item',$key,'column_name');
            if (defined($newkey)) {
                $hash->{$newkey} = $hash->{$key};
                delete $hash->{$key};
            }
        }
    }

    return \%{$hash}; # ?
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




