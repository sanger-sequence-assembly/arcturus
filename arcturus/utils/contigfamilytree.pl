#!/usr/local/bin/perl

use ArcturusDatabase;
use Read;

use FileHandle;

use strict;

my $nextword;
my $instance;
my $organism;
my $contigid;
my $doAncestors;
my $doDescendants;
my $indent;
my $maxdepth;

while ($nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $contigid = shift @ARGV if ($nextword eq '-contig');

    $doAncestors = 1 if ($nextword eq '-parents' ||
			 $nextword eq '-ancestors');

    $doDescendants = 1 if ($nextword eq '-children' ||
			   $nextword eq '-descendants');

    $indent = shift @ARGV if ($nextword eq '-indent');

    $maxdepth = shift @ARGV if ($nextword eq '-maxdepth');
}

unless (defined($instance) && defined($organism) && defined($contigid)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

$indent = 5 unless defined($indent);

$maxdepth = 0 unless defined($maxdepth);

$doAncestors = 1 unless (defined($doAncestors) || defined($doDescendants));

my $padding = '';
for (my $n = 0; $n < $indent; $n++) {
    $padding .= ' ';
}

$indent = $padding;

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

die "Failed to create ArcturusDatabase" unless $adb;

my $dbh = $adb->getConnection();

my $query = "SELECT nreads,project_id,length,updated FROM CONTIG WHERE contig_id=$contigid";

my $stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

my ($nreads, $projectid, $ctglen, $updated) = $stmt->fetchrow_array();

$stmt->finish();

unless (defined($nreads) && defined($ctglen) && defined($updated)) {
    print STDERR "Contig $contigid cannot be found.\n";
    $dbh->disconnect();
    exit(1);
}

$query = "SELECT project_id,name FROM PROJECT";

$stmt = $dbh->prepare($query);
&db_die("Failed to create query \"$query\"");

$stmt->execute();
&db_die("Failed to execute query \"$query\"");

my $projects = {};

while (my ($projid, $projname) = $stmt->fetchrow_array()) {
    $projects->{$projid} = $projname;
}

$stmt->finish();

my $depth = 0;

if ($doAncestors) {
    print "ANCESTORS OF CONTIG $contigid\n\n";

    &displayContig($contigid, $projects->{$projectid}, $nreads, $ctglen, $updated, $indent, $depth);

    $query = "SELECT parent_id,project_id,nreads,length,updated,cstart,cfinish,direction" .
	" FROM C2CMAPPING left join CONTIG on C2CMAPPING.parent_id=CONTIG.contig_id" .
	    " WHERE C2CMAPPING.contig_id = ? ORDER BY cstart ASC";

    $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    &displayParents($projects, $contigid, $nreads, $stmt, $indent, $depth, $maxdepth);
}

if ($doDescendants) {
    print "DESCENDANTS OF CONTIG $contigid\n\n";

    &displayContig($contigid, $projects->{$projectid}, $nreads, $ctglen, $updated, $indent, $depth);

    $query = "SELECT C2CMAPPING.contig_id,project_id,nreads,length,updated,cstart,cfinish,direction" .
	" FROM C2CMAPPING left join CONTIG USING(contig_id)" .
	    " WHERE C2CMAPPING.parent_id = ?";

    $stmt = $dbh->prepare($query);
    &db_die("Failed to create query \"$query\"");

    &displayChildren($projects, $contigid, $stmt, $indent, $depth, $maxdepth);
}

$dbh->disconnect();

exit(0);

sub displayParents {
    my ($projects, $contigid, $creads, $stmt, $indent, $depth, $maxdepth) = @_;

    return unless ($maxdepth < 1 || $depth < $maxdepth);

    $stmt->execute($contigid);

    my @parents;
    my $preads = 0;

    while (my ($parentid, $projectid, $nreads, $ctglen, $updated, $cstart, $cfinish, $direction) =
	   $stmt->fetchrow_array()) {
	push @parents, [$parentid, $projectid, $nreads, $ctglen, $updated, $cstart, $cfinish, $direction];
	$preads += $nreads;
    }

    $stmt->finish();

    return unless (scalar(@parents) > 0);

    foreach my $parent (@parents) {
	my ($parentid, $projectid, $nreads, $ctglen, $updated, $cstart, $cfinish, $direction) = @{$parent};

	&displayContig($parentid, $projects->{$projectid}, $nreads, $ctglen, $updated, $indent, $depth + 1,
		       $cstart, $cfinish, $direction);

	&displayParents($projects, $parentid, $nreads, $stmt, $indent, $depth + 1, $maxdepth);
    }

    if ($creads > $preads) {
	&displayNewReads($creads - $preads, $indent, $depth + 1);
    }
}

sub displayChildren {
    my ($projects, $contigid, $stmt, $indent, $depth, $maxdepth) = @_;

    return unless ($maxdepth < 1 || $depth < $maxdepth);

    $stmt->execute($contigid);

    my @children;
    my $preads = 0;

    while (my ($childid, $projectid, $nreads, $ctglen, $updated, $cstart, $cfinish, $direction) =
	   $stmt->fetchrow_array()) {
	push @children, [$childid, $projectid, $nreads, $ctglen, $updated, $cstart, $cfinish, $direction];
	$preads += $nreads;
    }

    $stmt->finish();

    return unless (scalar(@children) > 0);

    foreach my $child (@children) {
	my ($childid, $projectid, $nreads, $ctglen, $updated, $cstart, $cfinish, $direction) = @{$child};

	&displayContig($childid, $projects->{$projectid}, $nreads, $ctglen, $updated, $indent, $depth + 1,
		       $cstart, $cfinish, $direction);

	&displayChildren($projects, $childid, $stmt, $indent, $depth + 1, $maxdepth);
    }
}

sub displayContig {
    my ($contigid, $project, $nreads, $ctglen, $updated, $indent, $depth,
	$cstart, $cfinish, $direction) = @_;

    for (my $n = 0; $n < $depth; $n++) {
	print $indent;
    }

    $project = defined($project) ? "$project, " : "";

    print "CONTIG $contigid ($project$nreads rd, $ctglen bp, $updated)";

    if (defined($cstart) && defined($cfinish) && defined($direction)) {
	print " $cstart..$cfinish $direction";
    }

    print "\n\n";
}

sub displayNewReads {
    my ($nreads, $indent, $depth) = @_;

    for (my $n = 0; $n < $depth; $n++) {
	print $indent;
    }

    print "NEW READS: $nreads\n\n";
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "-contig\t\tID of contig\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PRAMETERS\n";
    print STDERR "\n";
    print STDERR "-ancestors\tDisplay ancestors of initial contig\n";
    print STDERR "-parents\tDisplay ancestors of initial contig\n";
    print STDERR "\n";
    print STDERR "-descendants\tDisplay descendants of initial contig\n";
    print STDERR "-children\tDisplay descendants of initial contig\n";
    print STDERR "\n";
    print STDERR "-indent\t\tIndent each generation by this amount\n";
}
