#!/usr/local/bin/perl

use WGSassembly;
use ArcturusDatabase;
use DBI;
use DataSource;
use FileHandle;

use strict;

my $minscore = 70;
my $minmatch = 30;

my $instance;
my $organism;
my $assemblyname;

my $fosends;
my $root;
my $dlimit = 4 * 1024 * 1024;

#####################################################################
# Parse command-line arguments

while (my $nextword = shift @ARGV) {
    $instance       = shift @ARGV if ($nextword eq '-instance');
    $organism       = shift @ARGV if ($nextword eq '-organism');
    $assemblyname   = shift @ARGV if ($nextword eq '-assembly');

    $minscore       = shift @ARGV if ($nextword eq '-minscore');
    $minmatch       = shift @ARGV if ($nextword eq '-minmatch');

    $fosends        = shift @ARGV if ($nextword eq '-fosends');

    $root           = shift @ARGV if ($nextword eq '-root');

    $dlimit         = shift @ARGV if ($nextword eq '-dlimit');
}

unless (defined($organism) && defined($instance) && defined($assemblyname) && defined($root)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(1);
}

#####################################################################
# Project specific variables:

my $project = $assemblyname;

my $assembly = "$root/assembly";
my $split = "$root/split";
my $trash = 'BIN';

my @fos_ends = defined($fosends) ? split(/,/, $fosends) : undef;

my $repeats = 'repeats.dbs';

my $webDir = "/nfs/WWWdev/INTWEB_docs/htdocs/Projects/B_pertussis/bpst24";

#####################################################################
# These should not need to be edited:

my $tmpdir = "/tmp/$project.$$";
mkdir($tmpdir);

my $previous = "$tmpdir/previous.caf";
my $newReads = "$tmpdir/all.caf";

my $remove = "readings_to_remove";
my $distribution = "contig_list_for_distribution";
my $destinations = "read_destinations";

my $version = 0;
my $newAssembly = "$tmpdir/$project.$version.caf";

my $contigsFasta = "$project.contigs.fasta";
my $failures = "$project.$version.failures";
my $templates = "$project.$version.templ";
my $pairs = "$project.$version.pairs";
my $unassembled = "$project.unassembled.matches";

my $log = "$assembly/ame.log";
my $memUsage = "memory_usage";

#####################################################################
# Assembly program starts here:

my $ds = new DataSource(-instance => $instance, -organism => $organism);

my $dbh = $ds->getConnection();

unless (defined($dbh)) {
    print STDERR "Failed to connect to DataSource(instance=$instance, organism=$organism)\n";
    print STDERR "DataSource URL is ", $ds->getURL(), "\n";
    print STDERR "DBI error is $DBI::errstr\n";
    die "getConnection failed";
}

my $query = "select PROJECT.name,directory from PROJECT left join ASSEMBLY using(assembly_id)" .
    " where ASSEMBLY.name = ? and lockowner is null and lockdate is null and directory is not null";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute($assemblyname);
&db_die("execute($query) failed");

my $projectdirs = {};

while (my ($projname, $projdir) = $sth->fetchrow_array()) {
    $projectdirs->{$projname} = $projdir;
}

$sth->finish();

my @projects = sort keys %{$projectdirs};

print "Projects: ",join(" ",@projects),"\n";

$dbh->disconnect();

#####################################################################
# Assembly program starts here:

&WGSassembly::setDlimit($dlimit);

#my $saveSTDERR = &redirectSTDERR($log);

chdir($assembly) || die "Couldn't cd to $assembly\n";
#system("usageMonitor $$ > $memUsage &");

my $cmd = $ENV{'ARCTURUS_UTILS_DIR'} . "/calculateconsensus";

my $rc = system("$cmd -instance $instance -organism $organism -quiet -lowmem");

$cmd = $ENV{'ARCTURUS_UTILS_DIR'} . "/project-export";

unlink($previous) if -f $previous;

foreach my $project (@projects) {
    print STDERR "Exporting $project.\n";
    $rc = system("$cmd -instance $instance -organism $organism -project $project -caf $previous -append -lock");
    print STDERR "Export of $project ",($rc == 0 ? " succeeded" : " failed with error code $rc"),"\n";
}

$cmd = $ENV{'ARCTURUS_UTILS_DIR'} . "/getunassembledreads";

print STDERR "Getting unassembled reads\n";
$rc = system("$cmd -instance $instance -organism $organism -caf $newReads");
print STDERR ($rc == 0) ? "OK\n" : "Failed with error code $rc\n";

&my_reassemble_bayesian($previous, $newReads, $project,
			$minmatch, $minscore, $newAssembly, 2);

if (@fos_ends) {
    &tagLibs($newAssembly, {
        'Fosmid ends' => \@fos_ends,
    });
}

&crossMatchTagRepeats($newAssembly, $repeats, 100);

my $depadcaf = "$tmpdir/depadded.caf";

print STDERR "Depadding assembly CAF file\n";
$rc = system("caf_depad < $newAssembly > $depadcaf");
print STDERR ($rc == 0) ? "OK\n" : "Failed with error code $rc\n";

print STDERR "Importing assembly into Arcturus\n";
$rc = system("contig-loader -instance $instance -organism $organism" .
	     " -caf $depadcaf -setprojectby readcount");
print STDERR ($rc == 0) ? "OK\n" : "Failed with error code $rc\n";

$cmd = $ENV{'ARCTURUS_UTILS_DIR'} . "/exportfromarcturus";

my $unlock = $ENV{'ARCTURUS_UTILS_DIR'} . "/project-unlock";

foreach my $project (@projects) {
    print STDERR "Exporting $project as Gap4 database.\n";
    $rc = system("$cmd -instance $instance -organism $organism -project $project");
    print STDERR "Export of $project ",($rc == 0 ? " succeeded" : " failed with error code $rc"),"\n";
}

&finishedMessage();

exit;

sub my_reassemble_bayesian {
    my ($old, $new, $project, $minmatch, $minscore, $out, $parallel) = @_;

    my $para = (defined($parallel)) ? "-parallel $parallel" : "";

    my $dlimit = &getDlimit();

    my $cmd = ("ulimit -d $dlimit ; "
	       ."reassembler "
	       ."-project $project "
	       ."-minscore $minscore -minmatch $minmatch "
	       ."-phrapexe phrap.manylong -qual_clip phrap "
	       ."-dlimit $dlimit -nocons99 -notrace_edit $old $new > $out");

    print STDERR "$cmd\n";

    system($cmd) && die "Error running reassembler $!\n";
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
    exit(0);
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "    -instance\t\tName of instance\n";
    print STDERR "    -organism\t\tName of organism\n";
    print STDERR "    -assembly\t\tName of assembly\n";
    print STDERR "    -root\t\tRoot directory for assembly\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "    -minmatch\t\tParameter for phrap\n";
    print STDERR "    -minscore\t\tParameter for phrap\n";
    print STDERR "    -dlimit\t\tData size limit\n";
}
