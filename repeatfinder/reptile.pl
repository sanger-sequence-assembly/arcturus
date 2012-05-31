#!/usr/local/bin/perl -w

use strict;

use FileHandle;
use Carp;
use ArcturusDatabase;

my $validkeys = "instance|i|organism|o|mode|m|";
my $validmode = "sam|sql|gff|";
my ($nextword, $instance, $organism, $mode);

#------------------------------------------------------------------------------

while (my $nextword = shift @ARGV) {

    if ($nextword !~ $validkeys) {
        &showUsage("Invalid keyword '$nextword'"); # and exit
				exit 1;
    }

    if ($nextword eq '-instance' || $nextword eq '-i') { # mandatory
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') { # mandatory
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism = shift @ARGV;
		}

    if ($nextword eq '-mode' || $nextword eq '-m') { # mandatory
        $mode = shift @ARGV;
    }  
}

#------------------------------------------------------------------------------
# Check input parameters
#------------------------------------------------------------------------------

unless (defined($instance)) {
    &showUsage("No instance name specified");
    exit 1;
}

unless (defined($organism)) {
    &showUsage("No organism name specified");
    exit 1;
}

unless (defined($mode)) {
    &showUsage("No mode specified for the output: $validmode)");
    exit 1;
}

if ($mode !~ $validmode) {
    &showUsage("Invalid mode $mode specified for the output: $validmode");
    exit 1;
}

#------------------------------------------------------------------------------
# get a Project instance
#------------------------------------------------------------------------------

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
     &showUsage("Invalid organism '$organism' on instance '$instance'");
     exit 2;
}

my $dbh = $adb->getConnection();
my $sth = $dbh->prepare("select contig_id from CONTIG where gap4name = ?");

#-------------------------------------------------------------------------------------------------------
# Read the matches file, look up the contig id from the contig name and write the appropriate SQL insert
# matches file format is  "%6d %4.2f %1s %-20s %6d %6d %6d   %1s %-20s %6d %6d %6d\n"
#-------------------------------------------------------------------------------------------------------

my $count = 0;
my $line_count = 0;
my $not_found = 0;
my $invalid = 0;

my $contig_id = 0;

my $line = "";
my ($dummy, $score, $frac, $end1, $name1, $len1, $start1, $finish1, $end2, $name2, $len2, $start2, $finish2);

while ($line = <STDIN>) {
		$line_count++;
    chop($line);

    if ($line =~ /^\s*\d+\s+\d+\.\d+\s+\S+\s+\S+\s+\d+\s+\d+\s+\d+\s+\S+\s+\S+\s+\d+\s+\d+\s+\d+/) {
			($dummy, $score, $frac, $end1, $name1, $len1, $start1, $finish1, $end2, $name2, $len2, $start2, $finish2) 
    	 = split(/\s+/,$line, 13);

			$count++;

			$sth->execute($name1);

			my $contig_id;
				$sth->bind_col(1, \$contig_id);
				while ($sth->fetch) { 
					#print " $contig_id $name1\n";
				}

			if ($contig_id == 0) {
					$not_found++;
					print STDERR "$line_count: cannot find contig id for contig $name1\n";
				}
			else {
					my $cigar = $len2."M";
					print STDOUT "insert into SAMTAG (SAMtagtype, SAMtype, GAPtagtype,  tagcomment, contig_id, start, length, tag_seq_id, strand, comment) values ('CT', 'i', 'REPT', '$name2 auto-generated by REPTILE', $contig_id, $start1, $len2, 0, 'U', null);\n" if ($mode eq "sql");
					print STDOUT "*\t768\t$name1\t$start1\t255\t$cigar\t *\t0\t0\t*\t*\tCT:Z:+;REPT;Note=$name2 length $len2 auto-generated by REPTILE\n" if ($mode eq "sam");
					print STDOUT "$name1\treptile\tRepeat\t$start1\t$finish1\t0.0\t.\t.\thid=$name2; hstart=$start1; hend=$finish1\n" if ($mode eq "gff");
			}
		} # if input line in matches file is valid
		else {
					$invalid++;
					print STDERR "$line_count: invalid input line $line";
		}
}

my $found = $count - $invalid - $not_found;

print STDERR "\n\n$found $mode generated\n";
print STDERR "$not_found $mode cannot be generated because the contig id cannot be found\n";
print STDERR"$invalid $mode cannot be generated because the matches file line was invalid\n";
$adb->disconnect();

exit(0);

#-------------------------------------------------------------------------------

sub showUsage {
    my $code = shift;

    print STDERR "\n";
    print STDERR "\nERROR for $0: $code \n" if defined($code);
    print STDERR "\n";
    print STDERR "Generate samTAG sql for Arcturus Minerva 2, sam for GAP 5 or gff for Artemis from repeats.matches file\n";
    print STDERR "\n";
    print STDERR "perl -I/software/arcturus/lib/ reptile.pl -instance(i) Database instance name -organism(o) Arcturus database name -mode(m) output mode\n";
    print STDERR "\n";
    print STDERR "Redirect inpout and output e.g. < repeats.matches > repeats.sql (specify different directory if required)\n";
    print STDERR "\n";
    print STDERR "\nERROR for $0: $code \n" if defined($code);
    exit 1;
}

#------------------------------------------------------------------------------

