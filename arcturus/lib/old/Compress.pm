package Compress;

#############################################################################
#
# Triplet substitution and Huffman compression for strings
#
#############################################################################

use strict;

#############################################################################

my %encodeTable;
my @decodeTable;
my $existsTable = 0;
my $status = 0;

#############################################################################

# constructor item new ( TABLEINIT )

sub new {
   my $prototype = shift;
   my $tableinit = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $self->{encode} = {};
   $self->{decode} = [];
   $self->{status} = 0;

   &buildCodeTables($tableinit) if (defined($tableinit));

   bless ($self, $class);
   return $self;
}

#############################################################################

# destructor

sub DESTROY {
   my $self = shift;

   return 1;
}

#############################################################################

sub buildCodeTables {
# sets up hash tables for encoding/decoding DNA strings
#    my $self = shift;
    my $RNA = shift;

    my @seqsymbols;
    @seqsymbols = split  //, 'ACGT- ' if !$RNA;
    @seqsymbols = split  //, 'ACGU- ' if ($RNA && length($RNA) != 6);
    @seqsymbols = split  //, $RNA     if ($RNA && length($RNA) == 6);

# build hash table for encoding and array for decoding

#    my $encodeTable = $self->{encode};
#    my $decodeTable = $self->{decode};

    undef %encodeTable;
    undef @decodeTable;

    my $i = 0;
    foreach my $leader (@seqsymbols) {
        foreach my $centre (@seqsymbols) {
            foreach my $trailer (@seqsymbols) {
                my $radix = "$leader$centre$trailer";
# avoid ' and " (34, 39, 94) ?
                $encodeTable{$radix} = $i;
                $decodeTable[$i] = $radix;
                $i++;
            }
        }
    }
    $existsTable = 1;
}

#############################################################################

sub sequenceEncoder {
# encodes an input string
    my $self   = shift;
    my $string = shift;
    my $method = shift;

    return &tripletEncoder($self,$string)  if ($method == 1);
 
    return &huffmanEncoder($self,$string)  if ($method == 2);

    die "Invalid encoding method $method";    
}


#############################################################################

sub sequenceDecoder {
# encodes an input string
    my $self   = shift;
    my $string = shift;
    my $method = shift;

    return &tripletDecoder($self,$string,@_)  if ($method == 1);
 
    return &huffmanDecoder($self,$string)     if ($method == 2);

    die "Invalid encoding method $method";    
}

#############################################################################

sub tripletEncoder {
# encode input DNA (or RNA) base sequence string using encoding table
    my $self  = shift;
    my $input = shift;

#    my $encodeTable = $self->{encode};
    $self->{status} = 0;

    $status = 0;

#    &buildCodeTables(0) if (!%$encodeTable); # default table
    &buildCodeTables(0) if (!$existsTable); 

    $input .= '  ';                    # add two blanks to ensure a complete triplet at end
    $input =~ s/(...)/$1:/g;           # mark every third position in input string
    my @stradixes = split /:/, $input; # get character triplets in array

    my $radix;
    my $number;
    undef my $output;
    for (my $triple=0 ; $triple <= $#stradixes ; $triple++) { 
        $radix = $stradixes[$triple];
        if (length($radix) == 3 && defined ($encodeTable{$radix})) {
            $number = $encodeTable{$radix}; 
            $output .= chr($number);
        } elsif ($triple < $#stradixes) {
        # flag undefined triples, except for the last one which may be incomplete
            print "Serious problem in sequenceEncoder at triplet $triple: ";
            print " invalid triplet key value \"$radix\"\n";
            $status++; # keep track of errors
#            $self->{status}++;
        }
    }

    $input =~ s/\s|\://g; # remove all blanks to get number of characters

    return  length($input),$output;
}

############################################################################

sub tripletDecoder {
# decode encoded input DNA/RNA base sequence using decoding table
    my $self   = shift;
    my $input  = shift;
    my $blanks = shift; # keep blanks, else remove blanks

#    my $decodeTable = $self->{decode};
    $status = 0;

#    &buildCodeTables(0) if (!@$decodeTable)
    &buildCodeTables(0) if (!$existsTable); 

    my @chrnumbers = split //,$input; # split into individual characters (bytes)

    my $count = 0;
    undef my $output;
    foreach my $symbol (@chrnumbers) {
        my $number = unpack('C*',$symbol); # the encoding number
        my $string = $decodeTable[$number]; # the corresponding character triplet
        $output .= $string;
        $string =~ s/\s//g;
        $count += length($string); # count number of non-blank characters
    }

    $output =~ s/\s//g if !$blanks;
 
    $count,$output;
}

#############################################################################
# encoding/decoding Quality data
#############################################################################

sub qualityEncoder {
# encodes an input string
    my $self   = shift;
    my $string = shift;
    my $method = shift;

    return &numbersEncoder($self,$string)  if ($method == 1);
 
    return &huffmanEncoder($self,$string)  if ($method == 2);
 
    return &differsEncoder($self,$string)  if ($method == 3);

    die "Invalid encoding method $method for quality";    
}


#############################################################################

sub qualityDecoder {
# encodes an input string
    my $self   = shift;
    my $string = shift;
    my $method = shift;

    return &numbersDecoder($self,$string)  if ($method == 1);
 
    return &huffmanDecoder($self,$string)  if ($method == 2);
 
    return &differsDecoder($self,$string)  if ($method == 3);

    die "Invalid decoding method $method for quality";    
}

#############################################################################

sub numbersEncoder {
# encode an input string with integer numbers [0-255] using byte representation
    my $self  = shift;
    my $input = shift;

    $status = 0;

    $input =~ s/^\s+|\s+$//g; # remove leading and trailing blanks
#    $input =~ s/^\s+//; # remove leading blanks
    my @strnumbers = split /\s+/,$input; # put values in array

    my $count = 0;
    undef my $output;
    foreach my $number (@strnumbers) {
        if ($number >= 0 && $number <= 255) { 
            $output .= chr($number);
            $count++; # count number of integers
        } else {
            print STDOUT "number $number out of range\n";
            $status++; # keep track of errors
        }
    }

    $count,$output;
}

#############################################################################

sub differsEncoder {
# encode an input string with integer numbers [0-255] using differences & huffman code
    my $self  = shift;
    my $input = shift;

    $status = 0;

    $input =~ s/^\s+|\s+$//g; # remove leading and trailing blanks
#print "\ninput $input\n";
    my @strnumbers = split /\s+/,$input; # put values in array

    my $last = $strnumbers[0];
    for (my $i = 1 ; $i < @strnumbers ; $i++) {
	my $next = $strnumbers[$i];
        $strnumbers[$i] -= $last;
        $last = $next;
    }

    my $string = '';
    foreach my $number (@strnumbers) {
        $string .= sprintf("%4d",$number);
    }

    $string =~ s/\s(\d)/+$1/g; # add '+' before positive numbers
    $string =~ s/\s+//g; # and remove all blanks
#print "\nconverted:  $string\n";

    my ($dummy, $output) = &huffmanEncoder($self,$string);

    my $count  = @strnumbers;

    $count, $output;
}

#############################################################################

sub numbersDecoder {
# expand input into string of integer numbers separated by blanks 
    my $self  = shift; 
    my $input = shift;

    $status = 0;
    
    my @chrnumbers = split //,$input;

    my $count = 0;
    undef my $output;
    foreach my $number (@chrnumbers) {
        $output .= ' '.unpack ('C*',$number);
        $count++;
    }

    $count,$output;
}

#############################################################################

sub differsDecoder {
# expand input into string of integer numbers separated by blanks 
    my $self  = shift; 
    my $input = shift;

    my ($dummy, $string) = &huffmanDecoder($self, $input);
    
# print "differs restored: $string \n\n";
    $string =~ s/([\+\-]\d)/ $1/g;
    $string =~ s/^[\s\+]+//; # remove leading blanks
# print "differs prepared: $string \n\n";
    my @chrnumbers = split /\s+/,$string;

    my $count = 1;
    for (my $i = 1 ; $i < @chrnumbers ; $i++) {
        $chrnumbers[$i] += $chrnumbers[$i-1];
        $count++; 
    }

    $string = join ' ',@chrnumbers;

    $count,$string;
}

#############################################################################
# Huffman Coding: public methods
#############################################################################

sub huffmanEncoder {
# encode input string using Huffman's method
    my ($self, $string) = @_;

    $status = 0;
 
    undef my $seed;
    undef my $output;
    undef my $encoding;

# build histogram of the input string

    $string .= ' ' if (!($string =~ /\ /)); # ensure at least one padding symbol
    my $f = &huffmanHistogram($string);

# build the huffman tree for the input data

    my $dtree = &huffmanTree ($f);
# and generate both the seed and the corresponding encoding string
    foreach my $token (keys(%$dtree)) {
        $encoding .= join('',@{$dtree->{$token}}).' ';
        $seed .= $token;
    }

# use default tree for encoding of codestring

    my %ctree;
    @{$ctree{'0'}} = ('0');
    @{$ctree{'1'}} = ('1', '1');
    @{$ctree{' '}} = ('1', '0');
# encode the code stringand get its length
    my ($count, $codes) = &encodeHuffman (\%ctree,$encoding);
    my $lc = length($codes); 

#     The encoded output string consists of 4 parts:
# (1) first byte: number of occurring tokens in the string, stored as char e.g. 6
# (2) the seed, string with all occurring tokens listed                    e.g. "ACGT- "
# (3) next byte : the length of the coded codestring
# (4) the hoffman encoded encoding string of token codes separated by ' '  e.g. "10 00 011 11 0100 0101"
# (5) the hoffman encoded input string

    $output  = chr(length($seed))  . $seed;
    $output .= chr(length($codes)) . $codes;
   ($count, $codes) = &encodeHuffman($dtree,$string);
    $output .= $codes;

    $count, $output;
}

#############################################################################

sub huffmanDecoder {
# encode input string using Huffman's method
    my ($self, $string) = @_;

#     The encoded input string consists of 4 parts:
# (1) first byte: number of occurring tokens in the string, stored as char
# (2) the seed, string with all occurring tokens listed                   
# (3) next byte : the length of the coded codestring
# (4) the hoffman encoded encoding string of token codes separated by " " 
# (5) the hoffman encoded data string

    $status = 0;

    undef my $count;
    undef my $output;

    my $number = unpack('C*',substr($string,0,1));
    my $seed = substr($string,1,$number);
    my $lcoder = unpack('C*',substr($string,++$number,1));
    my $encoding = substr($string,++$number,$lcoder);
    $number += $lcoder;

# use default tree for decoding of codestring

    undef my %ctree;
    @{$ctree{'0'}} = ('0');
    @{$ctree{'1'}} = ('1', '1');
    @{$ctree{' '}} = ('1', '0');
# encode the code stringand get its length
   ($count, $encoding) = &decodeHuffman (\%ctree,$encoding);

# build the decoding tree for the data

    undef my %tree;
    my @tokens = split //,$seed;
    my @codons = split /\s+/,$encoding;
    for (my $i=0 ; $i <= $#tokens ; $i++) {
        @{$tree{$tokens[$i]}} = split //,$codons[$i];
    }

   ($count, $output) = &decodeHuffman (\%tree,substr($string,$number));

    $count, $output;
}

#############################################################################
# Huffman Coding: private methods
#############################################################################

sub huffmanHistogram {
# count characters in the input string
    my $string = shift;

    my $f; # create reference to a hash

# split string into individual characters
 
    my @elements = split //,$string;

    foreach (@elements) {
        $f->{$_}++;
    }
    delete $f->{''};

# return the reference to the hash

    $f;
}

#############################################################################

sub huffmanTree {
# build Huffman tree from input frequency hash (built in histogram)
    my $fhash = shift;

    my %tree = ();

    while (keys %$fhash >= 2) {
# find the two least frequent (remaining) entries in the hash
        my ($key1, $key2) = huffmanLeast2($fhash);
    # get the total frequency
        my $weight = $fhash->{$key1} + $fhash->{$key2};
    # remove the nodes
        delete $fhash->{$key1};     
        delete $fhash->{$key2};
    # build the encoding hash
        foreach my $base (split(/$;/o, $key1)) {
            push @{$tree{$base}}, 0;
        }     
        foreach my $base (split(/$;/o, $key2)) {
            push @{$tree{$base}}, 1;
        }     
    # add the combined node back to the hash
	$fhash->{join $; => $key1, $key2} = $weight;
    }
# finally reorder the encoding keys?
    foreach my $binary (keys %tree) {
        @{$tree{$binary}} = reverse @{$tree{$binary}};
    }
# return the reference to the tree hash
    \%tree;
}

#############################################################################

sub huffmanLeast2 {
# return the two smallest items from the frequency histogramme
    my $f = shift; # the input frequency hash

    my ($key  , $value);
    my ($keyl1, $value1);
    my ($keyl2, $value2);
    undef $keyl1;
    undef $keyl2;

# and setup reference tree

    if (keys %$f >= 2) {

       ($keyl1, $value1) = each %$f;
       ($keyl2, $value2) = each %$f;
        if ($value2 < $value1) {
            ($keyl1,$value1, $keyl2,$value2) =
	    ($keyl2,$value2, $keyl1,$value1);
        }

        while (($key, $value) = each %$f) {
	    if ($value < $value1) {
                ($keyl2, $value2) = ($keyl1, $value1);
                ($keyl1, $value1) = ($key  , $value);
            } elsif ($value < $value2) {
                ($keyl2, $value2) = ($key, $value);
            }
        }

    }
   ($keyl1, $keyl2);
}

#############################################################################

sub encodeHuffman {
# encode the input string given the encoding tree (hash)
    my $tree   = shift;
    my $string = shift;

# print "encodeHuffman: string=$string  tree=$tree\n";

    undef my $output;
    my $ccount = 0;

    my $i = 0;
    my $l = 0; 
    my $n = 0;
    my $in = length($string);
    return 0 if (!$in);

    my @bitlist;
    my $token; 
    my $pad = substr($string,0,1); # use the first symbol as padding

    while ($l >= 0) {
    # add string to output bit list; keep track of total nr bits
        $token = ' ' if ($i >= $in); # pad with blanks
        $token = substr($string,$i,1) if ($i < $in);
        $ccount++ if ($token ne ' '); # count non-blanks

        if (!defined($tree->{$token})) {
            print "undefined tree value for token nr $i:\"$token\"\n";
        } else {
            push @bitlist, @{$tree->{$token}};
            $l += @{$tree->{$token}} if ($i < $in);
        }
    # scavenge the output bits for the next character to be written
        while (@bitlist >= 8) {
	    my @bits = splice @bitlist, 0, 8;
	    $output .= pack 'B8', (join '',@bits);
            $l -= 8;
            $n++;
	}
        $i++;
        $l = -1 if ($l == 0 && $i >= $in); 
    }
# return number of non-blank characters and encoded input string
    $ccount, $output;
} 

#############################################################################

sub decodeHuffman {
# decode the inputstring given the huffman tree
    my $tree   = shift;
    my $string = shift;

    my $ccount = 0;
    undef my $output;

    my $in = length($string);

# build a decoding table for the tokens

    my %decode; 
    my $max = 0; 
    my $min = 8;
    foreach my $token (keys(%$tree)) {
        my $base = join '',@{$tree->{$token}};
        $decode{$base} = $token;
        my $size = length($base);
        $max = $size if ($size > $max);
        $min = $size if ($size < $min);
    }

    my $i = 0; 
    my $count = 0;
    undef my @bitlist; 
    undef my $nextcode; 

    for (my $i=0 ; $i < $in ; $i++) {
        my $code = substr($string,$i,1);
    # decode bits in code and add to bitlist
        my $byte = unpack 'B8', $code;
        @bitlist = split //,$byte;

    # find the next matching decode string(s)

        foreach my $bit (@bitlist) {
            $nextcode .= $bit; 
            $count++;
            if (defined($decode{$nextcode})) {
                $output .= $decode{$nextcode};
                $ccount++ if ($decode{$nextcode} ne ' ');
                undef $nextcode;
                $count = 0;

            } elsif ($count >= $max) {
                print "undefined code $nextcode at position $i\n";
                $status++; # keep track of errors
            # try to recover by matching substrings (if found, remove up to match
                foreach $code (sort keys (%decode)) {
                    if ($nextcode =~ s/\d*$code//) {
                        $output .= '*'.$decode{$code};
                        $ccount++ if ($decode{$code} ne ' ');
                        $count = length($nextcode);
                    }
                }
            }
        }
    }
# return number of non-blank characters and decoded input string
    $ccount, $output;
}

#############################################################################

sub status {
# returns the error status of last operation
    my $self = shift;
  
#    return $self->{status};
    return $status;
}

#############################################################################
#############################################################################

sub colophon {
    return  colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             1.1 ,
        date    =>    "18 Dec 2000",
        update  =>    "03 Jul 2002",
    };
}

1;

__END__
