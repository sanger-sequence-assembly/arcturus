#!/usr/local/bin/perl

require "badgerGetOpt.pl";
use FileHandle;

$prog = "xmatch-filter";
$usage = "Usage: $prog [options ...]\n";

$opts = {
    "-in" => {
	"type" => "text",
	"var"  => \$infile,
	"help" => "Name of input file"
	},
    "-out" => {
	"type" => "text",
	"var"  => \$outfile,
	"help" => "Name of output file"
	},
     "-fuzz" => {
	 "type" => "integer",
	 "var"  => \$fuzz,
	 "def" => 1,
	 "help" => "Fuzz for end-matching"
	 },
     "-maxsubs" => {
	 "type" => "integer",
	 "var"  => \$maxsubs,
	 "def" => 2,
	 "help" => "Maximum percentage substitution"
      },
     "-maxindel" => {
	 "type" => "integer",
	 "var"  => \$maxindel,
	 "def" => 2,
	 "help" => "Maximum percentage insertion/deletion"
      },
     "-partials" => {
	 "type" => "integer",
	 "var"  => \$partials,
	 "def" => 0,
	 "help" => "Show partial matches"
      },
      "-nosingle" => {
	 "type" => "integer",
	 "var"  => \$multipleassignments,
	 "def" => 0,
	 "help" => "Show multiple matches only"
      },
    "-qfile" => {
	 "type" => "text",
	 "var"  => \$qualityfile,
	 "help" => "Name of file with quality clipping info"
      },
      "-format" => {
	 "type" => "integer",
	 "var"  => \$format,
	 "def" => 0,
	 "help" => "output list; 1 for long"
      },
      "-test" => {
	 "type" => "integer",
	 "var"  => \$test,
	 "def"  => 0,
	 "help" => "activate test mode"
      }
};

$options = join(' ',@ARGV);
&badgerGetOpt($prog, $usage, $opts) && die "Quit\n";

die "No input file specified" unless $infile;
die "Input file does not exist" unless -f $infile;
die "Cannot open input file" unless open(INFILE, $infile);

$qhash = &readqhash($qualityfile) if $qualityfile;

my $readcontighash = {};

my $rch = {}; # read count hash

my $line = 0;
while ($in = <INFILE>) {
    chop($in); $line++;
    $out = &FilterMatches($in,$partials,$fuzz,$maxsubs,$maxindel,$qhash,$rch);
    next unless $out;

    print STDOUT "test : $out->[6] ($out->[7] - $out->[8])) matches "
               . "to $out->[1] ($out->[4], $out->[0]-$out->[5])\n" if ($test > 1);

    if (my $allocations = $readcontighash->{$out->[6]}) {
        my @contigs = keys %$allocations;
    }

    $readcontighash->{$out->[6]} = {} unless $readcontighash->{$out->[6]};

    if ($readcontighash->{$out->[6]}->{$out->[1]}) {
        $readcontighash->{$out->[6]}->{"$out->[1].$line"} = $out;
	next unless $test;
        print STDOUT "multiple allocations of $out->[6] to same $out->[1]\n";
    }
    else {
        $readcontighash->{$out->[6]}->{$out->[1]} = $out;
    }
}

close(INFILE);

my $s = "cross_match output filter";
my $numberofplacedreads = scalar(keys %$rch);
print STDOUT "$s : total number of placed reads : $numberofplacedreads\n";

die "No output file specified" unless $outfile;
die "Cannot open output file" unless open(OUTFILE, "> $outfile");

my $numberofacceptedreads = 0;
foreach my $read (sort keys %$readcontighash) {
    my $contigs = $readcontighash->{$read};
    my @contigs = keys %$contigs;
    if (scalar(@contigs) == 1) {
# the read is placed on one contig only
        next if $multipleassignments;
# export unique assignments only (default)
    }
    else {
# the read is placed on more than on contig
        next unless ($test || $multipleassignments);
        print STDOUT "multiple allocations of $read: ".scalar(@contigs)."\n";
	next unless $multipleassignments;
# export multiple assignments only
    }

    $numberofacceptedreads++;

    foreach my $contig (@contigs) {

#    my $contig = $contigs[0];

        my $out = $readcontighash->{$read}->{$contig};

       ($end1, $name1, $start1, $finish1, $len1, 
        $end2, $name2, $start2, $finish2, $len2, $score) = @{$out};

        $frac = $score/$len2;

        my $line;
        if ($format) {

            $line =
            sprintf "%6d %4.2f %1s %-20s %6d %6d %6d   %1s %-20s %6d %6d %6d", 
                     $score, $frac,$end1, $name1, $len1, $start1, $finish1, 
                     $end2, $name2, $len2, $start2, $finish2;
        }
        else {
            $alignment = ($start2 > $finish2) ? R : F;
            $line = sprintf "%-20s  %1s  %-20s  %6d %6d",
 	                    $name2,$alignment,$name1, $start1, $finish1;
        }
        print OUTFILE "$line\n";
    }
}

print STDOUT "$s : total number of accepted reads : $numberofacceptedreads\n";

close OUTFILE;

exit(0);

#------------------------------------------------------------------------------

sub FilterMatches {
    my ($line,$partials,$fuzz,$max_sub,$max_indel,$qhash,$rca,$junk) = @_;

    $fuzz = 1 unless $fuzz;
    $max_sub = 5 unless $max_sub;
    $max_indel = 5 unless $max_indel;

    my (@words, $score, $subs, $dels, $inss, $seq1name, $seq1start, $seq1final,
	$tail1, $compl, $seq2name, $seq2start, $seq2final, $tail2, $star);

    my ($len1, $len2, $end1, $end2, $s2, $f2, $outdata);
    my ($tag1, $tag2);

    return 0 unless $line =~ /^\s*\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+/;

    $line =~ s/^\s+//;
    @words = split(/\s+/,$line);

    $score = shift @words; # cross_match alignment score

    $subs  = shift @words; # percentage substitutions
    $dels  = shift @words; # percentage deletions
    $inss  = shift @words; # presentage inserts

# reject alignments with too many substitutions,inserts or deletions

    if ($dels > $max_indel || $inss > $max_indel || $subs > $max_sub) {
        return 0; # read doesn't pass the scoring filter
    }

# 

    $seq1name  = shift @words;  # contig name
    $seq1start = shift @words;  # begin on contig
    $seq1final = shift @words;  # end on contig
    $tail1     = shift @words;  # remainder beyond last matching position

    if ($words[0] eq 'C') {
	$compl = 1;
	shift @words;
	$seq2name  = shift @words;
	$tail2     = shift @words;
	$seq2start = shift @words;
	$seq2final = shift @words;
    } else {
	$compl = 0;
	$seq2name  = shift @words;
	$seq2start = shift @words;
	$seq2final = shift @words;
	$tail2     = shift @words;
    }

    $rch->{$seq2name}++ if $rch; # count reads surviving the scoring filter

    undef $star;
    $star = shift @words if scalar(@words);
    
    ($tail1) = $tail1 =~ /\((\d+)\)/;
    ($tail2) = $tail2 =~ /\((\d+)\)/;

    $len1 = $seq1final + $tail1; # length of seq1 (contig)
    $len2 = ($compl ? $seq2start : $seq2final) + $tail2; # length of seq2 (r)

    undef $end1;
    undef $end2;

# end1 : L matches on the left, R matches on the right, undef in the middle
#        C matches completely

    $end1 = 'L' if $seq1start <= $fuzz;
    if ($seq1final > $len1 - $fuzz) {
	$end1 = defined($end1) ? 'C' : 'R';
    }

    return 0 if ($end1 eq 'C'); # rare ? read covers the whole contig

#    my $rev1 = ($seq1start < $seq1final) ? 0 : 1;
#    my $rev2 = ($seq2start < $seq2final) ? 0 : 1; # not used?

    ($s2, $f2) = ($seq2start < $seq2final) ? ($seq2start, $seq2final) : ($seq2final, $seq2start);

# checking coverage on read or quality masked section of read 

   ($lqleft,$lqright) = $qhash ? @{$qhash->{$seq2name}} : (undef,undef);  

    if ($lqleft && $lqright) {
# quality modified test
        $end2 = 'L' if $s2 <= $lqleft + $fuzz;
        if ($f2 > $lqright - $fuzz) {
	    $end2 = defined($end2) ? 'C' : 'R';
	}
    }
    else{
# original DH test
        $end2 = 'L' if $s2 <= $fuzz;
        if ($f2 > $len2 - $fuzz) {
	    $end2 = defined($end2) ? 'C' : 'R';
        }
    }

    return ['W', $seq1name, $seq1start, $seq1final, $len1, 'C', $seq2name, $seq2start, $seq2final, $len2, $score]
	if ($end2 eq 'C'); # seq2 (r) matches somewhere 'in centre' of seq1

    return [$end1, $seq1name, $seq1start, $seq1final, $len1, $end2, $seq2name, $seq2start, $seq2final, $len2, $score]
	if (defined($end1) && defined($end2)); # seq2 is placed near end seq1

# the remaining matches are partial (if either $end1 or $end2 defined)

    unless ($partials) {
#print STDOUT "partials REJECT : $line   ($dels $inss $subs; $end1 $end2)\n";
        return 0;
    }

# if $end1 is defined (hence $end2 not) the read matches partially at the end
# end of the contig; if $end2 is defined, the read matches centrally

    return ['W', $seq1name, $seq1start, $seq1final, $len1, 'P', $seq2name, $seq2start, $seq2final, $len2, $score]
	unless defined($end1);
#	if (defined($end1) || defined($end2)); # ?

    return 0;
}


sub readqhash {
    $file = shift;

    die "Cannot open quality file" unless open(QFILE, $file);

    $hash = {};

    while ($in = <QFILE>) {
        chomp($in);
	$in =~ s/^\s+//;
        ($name,$lgl,$lgh,@dummy) = split /\s+/,$in;
        $lgl++; # first base position on left
        $lgh--; # last base position on right
        $hash->{$name} = [($lgl,$lgh)];
    }

    close(QFILE);
    return $hash;
}
