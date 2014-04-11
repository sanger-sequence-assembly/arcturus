#!/usr/local/bin/perl

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


require "badgerGetOpt.pl";
use FileHandle;

$prog = "xmatchfilter";
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
	 "type" => "boolean",
	 "var"  => \$partials,
	 "def" => 0,
	 "help" => "SHow partial matches"
      },
};

$options = join(' ',@ARGV);
&badgerGetOpt($prog, $usage, $opts) && die "Quit\n";

die "No input file specified" unless $infile;
die "Input file does not exist" unless -f $infile;
die "Cannot open input file" unless open(INFILE, $infile);

#die "No output file specified" unless $outfile;
#die "Cannot open output file" unless open(OUTFILE, "> $outfile");

while ($in = <INFILE>) {
    chop($in);
    $out = &FilterMatches($in, $partials, $fuzz, $maxsubs, $maxindel);
    next unless $out;
    ($end1, $name1, $start1, $finish1, $len1, $end2, $name2, $start2, $finish2, $len2, $score) =
	@{$out};

    $frac = $score/$len2;

    printf "%6d %4.2f %1s %-20s %6d %6d %6d   %1s %-20s %6d %6d %6d\n", $score, $frac,
    $end1, $name1, $len1, $start1, $finish1, $end2, $name2, $len2, $start2, $finish2;
}

close(INFILE);
#close(OUTFILE);

exit(0);

sub FilterMatches {
    my ($line, $partials, $fuzz, $max_sub, $max_indel, $junk) = @_;

    $fuzz = 1 unless $fuzz;
    $max_sub = 5 unless $max_sub;
    $max_indel = 5 unless $max_indel;

    my (@words, $score, $subs, $dels, $inss, $name1, $start1, $finish1,
	$tail1, $compl, $name2, $start2, $finish2, $tail2, $star);

    my ($len1, $len2, $end1, $end2, $s2, $f2, $outdata);
    my ($tag1, $tag2);

    return 0 unless $line =~ /^\s*\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+/;

    $line =~ s/^\s+//;
    @words = split(/\s+/,$line);

    $score = shift @words;

    $subs  = shift @words;
    $dels  = shift @words;
    $inss  = shift @words;

    return 0 if ($subs > $max_sub);
    return 0 if (($dels > $max_indel || $inss > $max_indel));

    $name1 = shift @words;
    $start1 = shift @words;
    $finish1 = shift @words;
    $tail1 = shift @words;

    if ($words[0] eq 'C') {
	$compl = 1;
	shift @words;
	$name2 = shift @words;
	$tail2 = shift @words;
	$start2 = shift @words;
	$finish2 = shift @words;
    } else {
	$compl = 0;
	$name2 = shift @words;
	$start2 = shift @words;
	$finish2 = shift @words;
	$tail2 = shift @words;
    }

    undef $star;
    $star = shift @words if scalar(@words);
    
    ($tail1) = $tail1 =~ /\((\d+)\)/;
    ($tail2) = $tail2 =~ /\((\d+)\)/;

    $len1 = $finish1 + $tail1;
    $len2 = ($compl ? $start2 : $finish2) + $tail2;

    undef $end1;
    undef $end2;

    $end1 = 'L' if $start1 <= $fuzz;
    if ($finish1 > $len1 - $fuzz) {
	$end1 = defined($end1) ? 'C' : 'R';
    }

    return 0 if ($end1 eq 'C');

    my $rev1 = ($start1 < $finish1) ? 0 : 1;
    my $rev2 = ($start2 < $finish2) ? 0 : 1;

    ($s2, $f2) = ($start2 < $finish2) ? ($start2, $finish2) : ($finish2, $start2);

    $end2 = 'L' if $s2 <= $fuzz;
    if ($f2 > $len2 - $fuzz) {
	$end2 = defined($end2) ? 'C' : 'R';
    }

    return ['W', $name1, $start1, $finish1, $len1, 'C', $name2, $start2, $finish2, $len2, $score]
	if ($end2 eq 'C');

    return [$end1, $name1, $start1, $finish1, $len1, $end2, $name2, $start2, $finish2, $len2, $score]
	if (defined($end1) && defined($end2));

    return 0 unless $partials;

    return ['W', $name1, $start1, $finish1, $len1, 'P', $name2, $start2, $finish2, $len2, $score]
	 unless defined($end1);

    return 0;
}
