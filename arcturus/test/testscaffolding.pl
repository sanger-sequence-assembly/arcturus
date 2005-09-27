#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

use FileHandle;

my $instance;
my $organism;
my $verbose = 0;
my $progress = 0;
my $seedcontig;
my $puclimit = 8000;
my $minlen = 0;
my $minbridges = 2;

###
### Parse arguments
###

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');

    $seedcontig = shift @ARGV if ($nextword eq '-contig');

    $puclimit = shift @ARGV if ($nextword eq '-puclimit');

    $minbridges = shift @ARGV if ($nextword eq '-minbridges');

    $minlen = shift @ARGV if ($nextword eq '-minlen');

    $verbose = 1 if ($nextword eq '-verbose');
    $progress = 1 if ($nextword eq '-progress');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance) && defined($seedcontig)) {
    print STDERR "ERROR: One or more mandatory parameters are missing.\n\n";
    &showUsage();
    exit(0);
}

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
### Create statement handles for all the queries that we will need
### later.
###

my $statements = &createStatements($dbh);

my $sth_contiginfo = $statements->{'contiginfo'};
my $sth_leftendreads = $statements->{'leftendreads'};
my $sth_rightendreads = $statements->{'rightendreads'};
my $sth_template = $statements->{'template'};
my $sth_ligation = $statements->{'ligation'};

my @contigset;
my %processedcontigs;

push @contigset, $seedcontig;

my $graph = {};

while (my $contigid = shift @contigset) {
    next if defined($graph->{$contigid});

    $sth_contiginfo->execute($contigid);

    my ($contiglength, $gap4name, $projectid) = $sth_contiginfo->fetchrow_array();

    next unless defined($contiglength);

    $graph->{$contigid}= {} unless defined($graph->{$contigid});

    next if ($contiglength < $minlen);

    printf STDERR "CONTIG %8d %-30s %8d project=%d\n", $contigid, $gap4name, $contiglength, $projectid if $progress;

    my $links_score = {};

    foreach my $end ('L', 'R') {
	my $sth_endreads;

	my $endcode = ($end eq 'R') ? 0 : 2;

	if ($end eq 'L') {
	    $sth_leftendreads->execute($contigid, $puclimit);
	    $sth_endreads =$sth_leftendreads;
	} else {
	    $sth_rightendreads->execute($contigid, $contiglength - $puclimit);
	    $sth_endreads =$sth_rightendreads;
	}

	while (my ($readid, $seqid, $cstart, $cfinish, $direction) = $sth_endreads->fetchrow_array()) {

	    $sth_template->execute($readid);

	    my ($templateid, $strand) = $sth_template->fetchrow_array();

	    next unless (defined($templateid) && defined($strand));

	    $sth_ligation->execute($templateid);

	    my ($silow, $sihigh) = $sth_ligation->fetchrow_array();;

	    next unless (defined($silow) && defined($sihigh));

	    my $overhang = ($end eq 'L') ? $sihigh - $cfinish : $cstart + $sihigh - $contiglength;

	    ###
	    ### Skip this read if it turns out that it is too far from the end of
	    ### the contig
	    ###

	    next if ($overhang < 0);

	    ###
	    ### Skip this read if it not a short-range template
	    ###
	    
	    next unless ($sihigh < $puclimit);

	    $end, $readid, $seqid, $cstart, $cfinish, $direction, $strand;

	    ###
	    ### List the reads from the other end of the template
	    ###

	    my $sth_linkreads = $statements->{'linkreads'};
	    
	    $sth_linkreads->execute($templateid, $strand);

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
		    
		    next if defined($processedcontigs{$link_contig});

		    $sth_contiginfo->execute($link_contig);

		    my ($link_ctglen, $link_gap4name, $link_projectid) = $sth_contiginfo->fetchrow_array();
		    
		    ###
		    ### Skip this contig if it is not a current contig
		    ###
		    
		    next unless defined($link_ctglen);

		    ###
		    ### Skip this contig if it is too short
		    ###

		    next if ($link_ctglen < $minlen);
		    
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

		    my $link_endcode = $endcode;
		    $link_endcode += ($link_end eq 'L') ? 0 : 1;

		    $links_score->{$link_contig}->{$link_endcode} += 1;

		    ###
		    ### Add this pUC bridge to the lnkage graph
		    ###

		    $graph->{$contigid}->{$link_contig} = {}
		    unless defined($graph->{$contigid}->{$link_contig});

		    $graph->{$contigid}->{$link_contig}->{$endcode} = {}
		    unless defined$graph->{$contigid}->{$link_contig}->{$endcode};

		    my $link =  $graph->{$contigid}->{$link_contig}->{$endcode};

		    $link->{$templateid} = {} unless defined($link->{$templateid});

		    $link->{$templateid}->{'A'} = {} unless defined($link->{$templateid}->{'A'});
		    $link->{$templateid}->{'B'} = {} unless defined($link->{$templateid}->{'B'});

		    $link->{$templateid}->{'A'}->{$readid} = 1;
		    $link->{$templateid}->{'B'}->{$link_read_id} = 1;

		    $link->{$templateid}->{'gap'} = $gap_size
			if (!defined($link->{$templateid}->{'gap'}) || $gap_size < $link->{$templateid}->{'gap'});

		    ###
		    ### Print out the pUC bridge information
		    ###
		    if ($verbose) {
			printf STDERR "%8d %8d %1d %8d %8d", $contigid, $link_contig, $link_endcode, $contiglength, $link_ctglen;
			printf STDERR " %2d %2d", $projectid, $link_projectid;
			printf STDERR " // TEMPLATE %8d %6d %6d", $templateid, $silow, $sihigh;
			printf STDERR " // READ %8d %8d %8d %7s %7s", $readid, $cstart, $cfinish, $direction, $strand;
			printf STDERR " // READ %8d %8d %8d %7s", $link_read_id, $link_cstart, $link_cfinish, $link_direction;
			printf STDERR " // GAP %6d\n",$gap_size;
		    }
		}
		
		$sth_mappings->finish();
	    }
	    
	    $sth_linkreads->finish();
	}
    }

    foreach my $link_contig (keys %{$links_score}) {
	next if defined($graph->{$link_contig});

	unshift @contigset, $link_contig
	    if ($links_score->{$link_contig}->{0} >= $minbridges ||
		$links_score->{$link_contig}->{1} >= $minbridges ||
		$links_score->{$link_contig}->{2} >= $minbridges ||
		$links_score->{$link_contig}->{3} >= $minbridges);
    }
}

&finishStatements($statements);

$dbh->disconnect();

###
### Now analyse the graph
###

foreach my $contiga (keys %{$graph}) {
    foreach my $contigb (keys %{$graph->{$contiga}}) {
	next if ($contiga > $contigb);

	foreach my $endcode (keys %{$graph->{$contiga}->{$contigb}}) {
	    my $link = $graph->{$contiga}->{$contigb}->{$endcode};

	    my @templates = keys %{$link};

	    my $ntemplates = scalar(@templates);

	    next if ($ntemplates < $minbridges);

	    my $gapsize;

	    foreach my $templateid (@templates) {
		$gapsize = $link->{$templateid}->{'gap'}
		if (!defined($gapsize) || $gapsize > $link->{$templateid}->{'gap'});
	    }

	    my $leftarrow = ($endcode < 2) ? '--->' : '<---';
	    my $rightarrow = (($endcode % 2) == 0) ? '--->' : '<---';

	    printf "%8d %s [%2d %6d] %s %8d\n", $contiga, $leftarrow, $ntemplates, $gapsize, $rightarrow, $contigb;
	}
    }
}

exit(0);

sub db_die {
    return unless $DBI::err;
    my $msg = shift;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub createStatements {
    my $dbh = shift;

    my %queries = ("contiginfo",
		   "select length,gap4name,project_id" .
		   "  from CONTIG  left join C2CMAPPING" .
		   "    on CONTIG.contig_id = C2CMAPPING.parent_id" .
		   " where CONTIG.contig_id = ? and C2CMAPPING.parent_id is null",

		   "leftendreads", 
		   "select read_id,MAPPING.seq_id,cstart,cfinish,direction from" .
		   " MAPPING left join SEQ2READ using(seq_id) where contig_id=?" .
		   " and cfinish < ? and direction = 'Reverse'",

		   "rightendreads",
		   "select read_id,MAPPING.seq_id,cstart,cfinish,direction from" .
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
		   "select contig_id,cstart,cfinish,direction from MAPPING where seq_id = ?",
		   );

    my $statements = {};

    foreach my $query (keys %queries) {
	$statements->{$query} = $dbh->prepare($queries{$query});
	&db_die("Failed to create query \"$query\"");
    }

    return $statements;
}

sub finishStatements {
    my $statements = shift;

    foreach my $key (keys %{$statements}) {
	my $stmt = $statements->{$key};
	$stmt->finish();
    }
}

sub showUsage {
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "-contig\t\tUse this contig as the seed for pUC scaffolding\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-verbose\tShow lots of detail (default: false)\n";
    print STDERR "-progress\tDisplay progress info on STDERR (default: false)\n";
    print STDERR "-puclimit\tMaximum insert size for pUC subclones (default: 8000)\n";
    print STDERR "-minbridges\tMinimum number of pUC bridges (default: 2)\n";
    print STDERR "-minlen\t\tMinimum contig length (default: 0)\n";
}
