#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

my $instance = 'dev';
my $organism;
my $verbose = 0;
my $minbridges = 1;
my $minlen = 0;

###
### Parse arguments
###

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $minbridges = shift @ARGV if ($nextword eq '-minbridges');
    $minlen = shift @ARGV if ($nextword eq '-minlen');
    $verbose = 1 if ($nextword eq '-verbose');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

die "Organism not specified" unless defined($organism);

###
### Create the ArcturusDatabase proxy object
###

my $adb = new ArcturusDatabase(-instance => $instance,
			       -organism => $organism);

###
### Establish a connection to the underlying MySQL database
###

my $dbh = $adb->getConnection();

###
### Enumerate the list of active contigs, excluding singletons and
### ordering them by size, largest first.
###

my $contiglength = {};
my @contiglist;

my $query = "select CONTIG.contig_id,CONTIG.length".
    "  from CONTIG left join C2CMAPPING".
    "    on CONTIG.contig_id = C2CMAPPING.parent_id".
    " where C2CMAPPING.parent_id is null and CONTIG.nreads > 1 and CONTIG.length >= $minlen" .
    " order by CONTIG.length desc";

my $sth = $dbh->prepare($query);
&db_die("prepare($query) failed");

$sth->execute();
&db_die("execute($query) failed");

while (my ($ctgid, $ctglen) = $sth->fetchrow_array()) {
    $contiglength->{$ctgid} = $ctglen;
    push @contiglist, $ctgid;
}

$sth->finish();

###
### Create statement handles for all the queries that we will need
### later.
###

my $statements = &CreateStatements($dbh);

###
### Process each contig in turn
###

my $contigtoscaffold = {};
my @scaffoldlist;

foreach my $contigid (@contiglist) {
    ###
    ### Skip this contig if it has already been assigned to a
    ### scaffold.
    ###

    next if defined($contigtoscaffold->{$contigid});

    ###
    ### This contig is not yet in a scaffold, so we create a new
    ### scaffold and put the current contig into it.
    ###

    my $ctglen = $contiglength->{$contigid};

    my $scaffold = [[$contigid, 'F']];

    $contigtoscaffold->{$contigid} = $scaffold;

    push @scaffoldlist, $scaffold;

    my $seedcontigid = $contigid;

    ###
    ### Extend scaffold to the right
    ###

    my $lastcontigid = $seedcontigid;
    my $lastend = 'R';

    while (my $nextbridge = &FindNextBridge($lastcontigid, $lastend, $minbridges,
					    $statements, $contiglength, $contigtoscaffold, $verbose)) {
	my ($nextcontig, $nextgap) = @{$nextbridge};

	my ($nextcontigid, $linkend) = @{$nextcontig};

	my $nextdir = ($linkend eq 'L') ? 'F' : 'R';

	$contigtoscaffold->{$nextcontigid} = $scaffold;

	push @{$scaffold}, $nextgap, [$nextcontigid, $nextdir];

	$lastcontigid = $nextcontigid;

	$lastend = ($linkend eq 'L') ? 'R' : 'L';
    }

    ###
    ### Extend scaffold to the left
    ###

    my $lastcontigid = $seedcontigid;
    my $lastend = 'L';

    while (my $nextbridge = &FindNextBridge($lastcontigid, $lastend, $minbridges,
					    $statements, $contiglength, $contigtoscaffold, $verbose)) {
	my ($nextcontig, $nextgap) = @{$nextbridge};

	my ($nextcontigid, $linkend) = @{$nextcontig};

	my $nextdir = ($linkend eq 'R') ? 'F' : 'R';

	$contigtoscaffold->{$nextcontigid} = $scaffold;

	unshift @{$scaffold}, [$nextcontigid, $nextdir], $nextgap;

	$lastcontigid = $nextcontigid;

	$lastend = ($linkend eq 'L') ? 'R' : 'L';
    }

    ###
    ### Display the scaffold
    ###

    next unless (scalar(@{$scaffold}) > 1);

    my $report = "";

    my $isContig = 1;
    my $totlen = 0;
    my $totgap = 0;
    my $totctg = 0;

    while (my $item = shift @{$scaffold}) {
	if ($isContig) {
	    my ($contigid, $contigdir) = @{$item};
	    my $contiglen = $contiglength->{$contigid};
	    $report .= "  CONTIG $contigid ($contiglen) $contigdir\n";
	    $totlen += $contiglen;
	    $totctg += 1;
	} else {
	    my ($gapsize, $bridges) = @{$item};
	    $report .= "     GAP $gapsize [" . join(",", @{$bridges}).  "]\n";
	    $totgap += $gapsize;
	}

	$isContig = !$isContig;
    }

    print "SCAFFOLD $totctg $totlen $totgap\n\n";

    print $report;

    print "\n";
}

$dbh->disconnect();

exit(0);

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub CreateStatements {
    my $dbh = shift;

    my %queries = (
		   "leftendreads", 
		   "select read_id,cstart,cfinish,direction from" .
		   " MAPPING left join SEQ2READ using(seq_id) where contig_id=?" .
		   " and cfinish < ? and direction = 'Reverse'",

		   "rightendreads",
		   "select read_id,cstart,cfinish,direction from" .
		   " MAPPING left join SEQ2READ using(seq_id) where contig_id=?" .
		   " and cstart > ? and direction = 'Forward'",
	
		   "template",
		   "select template_id,strand from READS where read_id = ?",
		   
		   "ligation",
		   "select silow,sihigh from TEMPLATE left join LIGATION using(ligation_id)" .
		   " where template_id = ?",

		   "linkreads",
		   "select READS.read_id,seq_id from READS left join SEQ2READ using(read_id)" .
		   " where template_id = ? and strand != ?",

		   "mappings",
		   "select contig_id,cstart,cfinish,direction from MAPPING where seq_id = ?"
		   );

    my $statements = {};

    foreach my $query (keys %queries) {
	$statements->{$query} = $dbh->prepare($queries{$query});
    }

    return $statements;
}

sub FindNextBridge {
    my ($contigid, $contigend, $minbridges, $statements, $contiglength, $contigtoscaffold, $junk) = @_;

    my $contiglen = $contiglength->{$contigid};

    ###
    ### Assume pUC insert size no larger than 8kb
    ###

    my $puclimit = 8000;

    my $limit = ($contigend eq 'R') ? $contiglen - $puclimit : $puclimit;

    ###
    ### Select reads which are close to the specified end of the contig
    ###

    my $sth_endread = ($contigend eq 'R') ? $statements->{'rightendreads'} : $statements->{'leftendreads'};

    $sth_endread->execute($contigid, $limit);

    ###
    ### Hash table to store list of bridges for each contig/end combination
    ###

    my %bridges;

    ###
    ### Process each candidate read in the current contig
    ###

    while (my @ary = $sth_endread->fetchrow_array()) {
	my ($read_id, $cstart, $cfinish, $direction) = @ary;

	###
	### Get the template ID and strand for this read
	###

	my $sth_template = $statements->{'template'};

	$sth_template->execute($read_id);
	my ($template_id, $strand) = $sth_template->fetchrow_array();
	$sth_template->finish();

	###
	### Get the insert size range via the ligation
	###

	my $sth_ligation = $statements->{'ligation'};

	$sth_ligation->execute($template_id);
	my ($silow, $sihigh) = $sth_ligation->fetchrow_array();
	$sth_ligation->finish();

	###
	### Calculate the overhang i.e. the amount by which the maximum insert size
	### projects beyond the end of the contig
	###

	my $overhang = ($contigend eq 'L') ? $sihigh - $cfinish : $cstart + $sihigh - $contiglen;

	###
	### Skip this read if it turns out that it is too far from the end of
	### the contig
	###

	next if ($overhang < 0);

	###
	### Skip this read if it not a short-range template
	###

	next unless ($sihigh < $puclimit);

	###
	### List the reads from the other end of the template
	###

	my $sth_linkreads = $statements->{'linkreads'};

	$sth_linkreads->execute($template_id, $strand);

	while (my @linkary = $sth_linkreads->fetchrow_array()) {
	    my ($link_read_id, $link_seq_id) = @linkary;

	    ###
	    ### Find the contig in which the complementary read lies
	    ###

	    my $sth_mappings = $statements->{'mappings'};

	    $sth_mappings->execute($link_seq_id);

	    while (my @mapary = $sth_mappings->fetchrow_array()) {
		my ($link_contig, $link_cstart, $link_cfinish, $link_direction) = @mapary;

		###
		### Skip this contig if it is the same contig as the one we're processing
		###

		next if ($contigid == $link_contig);

		###
		### Skip this contig if it is already part of another scaffold
		###

		next if defined($contigtoscaffold->{$link_contig});

		my ($link_ctglen) = $contiglength->{$link_contig};

		###
		### Skip this contig if it is not a current contig
		###

		next unless defined($link_ctglen);

		my $link_end;
		my $gap_size;

		if ($link_direction eq 'Forward') {
		    ###
		    ### The right end of the link contig
		    ###

		    $gap_size = $overhang - ($link_ctglen - $link_cstart);
		    $link_end = 'R';
		} else {
		    ###
		    ### The left end of the link contig
		    ###

		    $gap_size = $overhang - $link_cfinish;
		    $link_end = 'L';
		}

		next unless ($gap_size > 0);

		if ($verbose) {
		    printf "CONTIG %d.%s (%d) -- ", $contigid, $contigend, $contiglen;
		    printf "READ %d : %d..%d  %s\n", $read_id, $cstart, $cfinish, $direction;
		    printf "  TEMPLATE %d  STRAND %s  INSERT_SIZE(%d, %d)\n", $template_id, $strand, $silow, $sihigh;
		    printf "    CONTIG %d.%s (%d) READ %d %d..%d  DIRECTION %s\n",
		    $link_contig, $link_end, $link_ctglen, $link_read_id, $link_cstart, $link_cfinish, $link_direction;
		    printf "      GAP %d\n\n",$gap_size;
		}

		my $linkname = "$link_contig.$link_end";

		$bridges{$linkname} = [] unless defined($bridges{$linkname});

		push @{$bridges{$linkname}}, [$template_id, $gap_size];
	    }

	    $sth_mappings->finish();
	}

	$sth_linkreads->finish();
    }

    ###
    ### Examine each bridge to find the best one
    ###

    my $bestlink;
    my $bestscore = 0;

    foreach my $linkname (keys %bridges) {
	my $score = scalar(@{$bridges{$linkname}});
	if ($score > $bestscore) {
	    $bestlink = $linkname;
	    $bestscore = $score;
	}
    }

    return 0 if ($bestscore < $minbridges);

    my ($bestcontig, $bestend) = split(/\./, $bestlink);

    my $bestgap;
    my $templatelist = [];

    foreach my $bridge (@{$bridges{$bestlink}}) {
	my ($template_id, $gap_size) = @{$bridge};
	push @{$templatelist}, $template_id;
	$bestgap = $gap_size if (!defined($bestgap) || $gap_size < $bestgap);
    }

    return [[$bestcontig, $bestend], [$bestgap, $templatelist]];
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance (default: 'dev')\n";
    print STDERR "-minbridges\tMinimum number of pUC bridges (default: 1)\n";
    print STDERR "-minlen\t\tMinimum contig length (default: all contigs)\n";
    print STDERR "-verbose\tShow lots of detail (default: false)\n";
}
