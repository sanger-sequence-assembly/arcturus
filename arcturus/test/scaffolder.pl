#!/usr/local/bin/perl

use strict;

use ArcturusDatabase;

my $instance;
my $organism;
my $verbose = 0;
my $progress = 0;
my $minbridges = 1;
my $minbacbridges = 1;
my $minlen = 0;
my $puclimit = 8000;
my $usesilow = 0;

###
### Parse arguments
###

while (my $nextword = shift @ARGV) {
    $instance = shift @ARGV if ($nextword eq '-instance');
    $organism = shift @ARGV if ($nextword eq '-organism');
    $minbridges = shift @ARGV if ($nextword eq '-minbridges');
    $minbacbridges = shift @ARGV if ($nextword eq '-minbacbridges');
    $minlen = shift @ARGV if ($nextword eq '-minlen');
    $puclimit = shift @ARGV if ($nextword eq '-puclimit');

    $usesilow = 1 if ($nextword eq '-usesilow');

    $verbose = 1 if ($nextword eq '-verbose');
    $progress = 1 if ($nextword eq '-progress');

    if ($nextword eq '-help') {
	&showUsage();
	exit(0);
    }
}

unless (defined($organism) && defined($instance)) {
    print STDERR "One or more mandatory parameters are missing.\n\n";
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

my $statements = &CreateStatements($dbh);

###
### Enumerate the list of active contigs, excluding singletons and
### ordering them by size, largest first.
###

my $contiglength = {};
my @contiglist;

my $sth = $statements->{'currentcontigs'};

$sth->execute($minlen);

while (my ($ctgid, $ctglen) = $sth->fetchrow_array()) {
    $contiglength->{$ctgid} = $ctglen;
    push @contiglist, $ctgid;
}

$sth->finish();

###
### Make a contig-to-project mapping
###

my $project = {};

$sth = $statements->{'projectforcontig'};

$sth->execute();

while (my ($ctgid, $projid) = $sth->fetchrow_array()) {
    $project->{$ctgid} = $projid if defined($contiglength->{$ctgid});
}

$sth->finish();

###
### Process each contig in turn
###

my $contigtoscaffold = {};
my @scaffoldlist;
my %contigref;
my %scaffoldtoid;
my %scaffoldfromid;
my $scaffoldid = 0;
my %scaffoldlength;
my %scaffoldcontigs;

my $alldone = scalar(@contiglist);
my $done = 0;

my $format = "%8d of %8d";
my $bs = "\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010\010";

if ($progress) {
    print STDERR "Building scaffolds ...\n"; 
    printf STDERR $format, $done, $alldone;
}

foreach my $contigid (@contiglist) {
    $done++;

    if ($progress && (($done % 10) == 0)) {
	print STDERR $bs;
	printf STDERR $format, $done, $alldone;
    }

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

    $scaffoldid++;

    $scaffoldtoid{$scaffold} = $scaffoldid;
    $scaffoldfromid{$scaffoldid} = $scaffold;

    ###
    ### Extend scaffold to the right
    ###

    my $lastcontigid = $seedcontigid;
    my $lastend = 'R';

    while (my $nextbridge = &FindNextBridge($lastcontigid, $lastend, $minbridges, $puclimit,
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

    while (my $nextbridge = &FindNextBridge($lastcontigid, $lastend, $minbridges, $puclimit,
					    $statements, $contiglength, $contigtoscaffold, $verbose)) {
	my ($nextcontig, $nextgap) = @{$nextbridge};

	my ($nextcontigid, $linkend) = @{$nextcontig};

	my $nextdir = ($linkend eq 'R') ? 'F' : 'R';

	$contigtoscaffold->{$nextcontigid} = $scaffold;

	unshift @{$scaffold}, [$nextcontigid, $nextdir], $nextgap;

	$lastcontigid = $nextcontigid;

	$lastend = ($linkend eq 'L') ? 'R' : 'L';
    }

    my $report = "";

    my $isContig = 1;
    my $totlen = 0;
    my $totgap = 0;
    my $totctg = 0;
    my $curpos = 0;

    foreach my $item (@{$scaffold}) {
	if ($isContig) {
	    my ($contigid, $contigdir) = @{$item};
	    my $contiglen = $contiglength->{$contigid};
	    my $projid = $project->{$contigid};
	    $report .= "  CONTIG $contigid/$projid ($contiglen) $contigdir\n";
	    push @{$item}, ($contigdir eq 'F') ? $curpos : $curpos + $contiglen;
	    $contigref{$contigid} = $item;
	    $totlen += $contiglen;
	    $totctg += 1;
	    $curpos += $contiglen;
	} else {
	    my ($gapsize, $bridges) = @{$item};
	    $report .= "     GAP $gapsize [" . join(",", @{$bridges}).  "]\n";
	    $totgap += $gapsize;
	    $curpos += $gapsize;
	}

	$isContig = !$isContig;
    }

    $scaffoldlength{$scaffold} = $totlen + $totgap;
    $scaffoldcontigs{$scaffold} = $totctg;

    ###
    ### Display the scaffold
    ###

    $totgap = '   *** DEGENERATE ***' unless (scalar(@{$scaffold}) > 1);

    print "SCAFFOLD $scaffoldid $totctg $totlen $totgap\n\n";

    print $report;

    print "\n";
}

my $maxscaffoldid = $scaffoldid;

if ($progress) {
    print STDERR $bs;
    printf STDERR $format, $done, $alldone;
    print STDERR "\nDone\n\n";
    print STDERR "Finding long-range bridges...\n";
}

print "\n\n----------------------------------------------------------------------\n\n";

my $sth_templates = $statements->{'bacendtemplate'};
my $sth_bacreads = $statements->{'readsfortemplate'};
my $sth_mappings = $statements->{'mappings'};

$sth_templates->execute($puclimit);

my $baclinks = {};

while (my ($template_id, $template_name, $silow, $sihigh) = $sth_templates->fetchrow_array()) {
    my $found = 0;

    my $baclen = $usesilow ? $silow : $sihigh;

    $sth_bacreads->execute($template_id);

    my @forwardlist = ();
    my @reverselist = ();

    while (my ($read_id, $readname, $strand, $seq_id) = $sth_bacreads->fetchrow_array()) {
	$sth_mappings->execute($seq_id);

	while (my ($contig_id, $cstart, $cfinish, $direction) = $sth_mappings->fetchrow_array()) {
	    next unless defined($contiglength->{$contig_id});
	    my $scaffold = $contigtoscaffold->{$contig_id};
	    next unless defined($scaffold);

	    my $projid = $project->{$contig_id};

	    $found++;

	    print "BAC_CLONE $template_id ($template_name) $silow $sihigh\n\n" if ($found == 1);

	    print "    READ $read_id ($readname) STRAND $strand SEQ $seq_id\n";
	    print "        IN CONTIG $contig_id/$projid $cstart..$cfinish $direction\n";

	    my $scaffoldid = $scaffoldtoid{$scaffold};

	    my $item = $contigref{$contig_id};

	    if (defined($item)) {
		my ($ctgid, $ctgdir, $ctgoffset) = @{$item};

		my $sense;

		if ($ctgdir eq 'F') {
		    $ctgoffset += ($direction eq 'Forward') ? $cstart : $cfinish;
		    $sense = $direction;
		} else {
		    $ctgoffset -= ($direction eq 'Forward') ? $cstart : $cfinish;
		    $sense = ($direction eq 'Forward') ? 'Reverse' : 'Forward';
		}

		my $overhang = -1;
		my $scaflen = $scaffoldlength{$scaffold};

		if ($sense eq 'Forward') {
		    $overhang = $baclen - ($scaflen - $ctgoffset);
		} else {
		    $overhang = $baclen - $ctgoffset;
		}

		my $ovh= ($overhang > 0) ? " OVERHANG $overhang" : "";

		print "            IN SCAFFOLD $scaffoldid ($scaflen bp) AT $ctgoffset $sense$ovh\n\n";

		if ($overhang > 0) {
		    my $entry = [$scaffoldid, $sense, $contig_id, $projid];
		    if ($strand eq 'Forward') {
			push @forwardlist, $entry;
		    } else {
			push @reverselist, $entry;
		    }
		}
	    } else {
		print "\n";
	    }
	}

	$sth_mappings->finish();
    }

    $sth_bacreads->finish();

    print "\n\n" if $found;

    if (scalar(@forwardlist) > 0 && scalar(@reverselist) > 0) {
	foreach my $fwditem (@forwardlist) {
	    my ($fwdscaffoldid, $fwdsense, $fwdcontigid, $fwdprojid) = @{$fwditem};

	    $fwdsense = ($fwdsense eq 'Forward') ? 'R' : 'L';

	    foreach my $revitem (@reverselist) {
		my ($revscaffoldid, $revsense, $revcontigid, $revprojid) = @{$revitem};
		next if ($fwdscaffoldid == $revscaffoldid);

		$revsense = ($revsense eq 'Forward') ? 'R' : 'L';

		my ($keya, $keyb, $entry);

		if ($fwdscaffoldid < $revscaffoldid) {
		    $keya = "$fwdscaffoldid.$fwdsense";
		    $keyb = "$revscaffoldid.$revsense";
		    $entry = [$fwditem, $revitem, $template_id];
		} else {
		    $keya = "$revscaffoldid.$revsense";
		    $keyb = "$fwdscaffoldid.$fwdsense";
		    $entry = [$revitem, $fwditem, $template_id];
		}

		$baclinks->{$keya} = {} unless defined($baclinks->{$keya});

		$baclinks->{$keya}->{$keyb} = [] unless defined($baclinks->{$keya}->{$keyb});

		$baclinks->{$keyb} = {} unless defined($baclinks->{$keyb});

		$baclinks->{$keyb}->{$keya} = [] unless defined($baclinks->{$keyb}->{$keya});

		push @{$baclinks->{$keya}->{$keyb}}, $entry;
		push @{$baclinks->{$keyb}->{$keya}}, $entry;
	    }
	}
    }
}

print "\n\n----------------------------------------------------------------------\n\n";
print "SUPER-BRIDGES\n\n";

foreach my $keya (sort keys %{$baclinks}) {
    my ($sida, $enda) = split(/\./, $keya);

    foreach my $keyb (sort keys %{$baclinks->{$keya}}) {
	my ($sidb, $endb) = split(/\./, $keyb);
	printf "%6d %1s    %6d %1s    %4d\n", $sida, $enda, $sidb, $endb, scalar(@{$baclinks->{$keya}->{$keyb}});
    }
}
	
print "\n\n----------------------------------------------------------------------\n\n";
print "SUPER-SCAFFOLDS\n\n";

my $scaffoldtosuperscaffold = {};

for (my $seedscaffoldid = 1; $seedscaffoldid <= $maxscaffoldid; $seedscaffoldid++) {
    next if defined($scaffoldtosuperscaffold->{$seedscaffoldid});

    my $scaffold = $scaffoldfromid{$seedscaffoldid};
    my $bp = $scaffoldlength{$scaffold};
    my $ctg = $scaffoldcontigs{$scaffold};

    my $totbp = $bp;
    my $totctg = $ctg;
    my $totscaff = 1;

    print "\n\n++++++++++          ++++++++++          ++++++++++          ++++++++++\n\n";
    print "Seeding from scaffold $seedscaffoldid [$bp, $ctg]\n";

    my $superscaffold = [[$seedscaffoldid, 'F']];

    $scaffoldtosuperscaffold->{$seedscaffoldid} = $superscaffold;

    ###
    ### Extend super-scaffold to the right
    ###

    my $lastscaffoldid = $seedscaffoldid;
    my $lastend = 'R';

    print "Extending to right ...\n";

    while (my $nextbridge = &FindNextSuperBridge($baclinks->{"$lastscaffoldid.$lastend"},
						 $minbacbridges,
						 $scaffoldtosuperscaffold)) {
	my ($nextscaffoldid, $nextend) = @{$nextbridge};

	$scaffold = $scaffoldfromid{$nextscaffoldid};

	$bp = $scaffoldlength{$scaffold};
	$ctg = $scaffoldcontigs{$scaffold};

	$totbp += $bp;
	$totctg += $ctg;
	$totscaff++;

	my $nextdir = ($nextend eq 'L') ? 'F' : 'R';

	$scaffoldtosuperscaffold->{$nextscaffoldid} = $superscaffold;

	push @{$superscaffold}, [$nextscaffoldid, $nextdir];

	print "  Scaffold $nextscaffoldid [$bp $ctg] $nextdir\n";

	$lastscaffoldid = $nextscaffoldid;

	$lastend = ($nextend eq 'L') ? 'R' : 'L';
    }
   
    ###
    ### Extend super-scaffold to the left
    ###

    my $lastscaffoldid = $seedscaffoldid;
    my $lastend = 'L';

    print "Extending to left ...\n";

    while (my $nextbridge = &FindNextSuperBridge($baclinks->{"$lastscaffoldid.$lastend"},
						 $minbacbridges,
						 $scaffoldtosuperscaffold)) {
	my ($nextscaffoldid, $nextend) = @{$nextbridge};

	$scaffold = $scaffoldfromid{$nextscaffoldid};

	$bp = $scaffoldlength{$scaffold};
	$ctg = $scaffoldcontigs{$scaffold};

	$totbp += $bp;
	$totctg += $ctg;
	$totscaff++;

	my $nextdir = ($nextend eq 'R') ? 'F' : 'R';

	$scaffoldtosuperscaffold->{$nextscaffoldid} = $superscaffold;

	unshift @{$superscaffold}, [$nextscaffoldid, $nextdir];

	print "  Scaffold $nextscaffoldid [$bp $ctg] $nextdir\n";

	$lastscaffoldid = $nextscaffoldid;

	$lastend = ($nextend eq 'L') ? 'R' : 'L';
    }

    if ($totscaff > 1) {
	print "\n\nSEED: $seedscaffoldid, $totscaff scaffolds, $totctg contigs, $totbp bp\n\n";
    }
}

$sth_templates->finish();

$dbh->disconnect();

exit(0);

sub FindNextSuperBridge {
    my ($bridges, $minscore, $usedscaffolds, $junk) = @_;

    my $bestid = -1;
    my $bestend;
    my $bestscore = 0;

    foreach my $keyb (keys %{$bridges}) {
	my ($scaffoldid, $end) = split(/\./, $keyb);

	next if defined($usedscaffolds->{$scaffoldid});

	my $score = scalar(@{$bridges->{$keyb}});

	next if ($score < $minscore);

	# Look for better score, or same score from a lower-numbered scaffold
	if (($score > $bestscore) || ($score == $bestscore && $scaffoldid < $bestid)) {
	    $bestid = $scaffoldid;
	    $bestend = $end;
	    $bestscore = $score;
	}
    }

    return ($bestscore == 0) ? 0 : [$bestid, $bestend];
}

sub db_die {
    my $msg = shift;
    return unless $DBI::err;
    print STDERR "MySQL error: $msg $DBI::err ($DBI::errstr)\n\n";
}

sub CreateStatements {
    my $dbh = shift;

    my %queries = ("currentcontigs",
		   "select CONTIG.contig_id,CONTIG.length" .
		   "  from CONTIG left join C2CMAPPING" .
		   "    on CONTIG.contig_id = C2CMAPPING.parent_id" .
		   " where C2CMAPPING.parent_id is null and CONTIG.nreads > 1 and CONTIG.length >= ?" .
		   " order by CONTIG.length desc",

		   "projectforcontig",
		   "select CONTIG.contig_id,project" .
		   "  from CONTIG left join CONTIG2PROJECT using(contig_id)",

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
		   "select contig_id,cstart,cfinish,direction from MAPPING where seq_id = ?",

		   "bacendtemplate",
		   "select template_id,TEMPLATE.name,silow,sihigh from TEMPLATE left join LIGATION using(ligation_id)" .
		   " where sihigh > ?",

		   "readsfortemplate",
		   "select READS.read_id,readname,strand,seq_id from READS left join SEQ2READ" .
		   " using(read_id) where template_id = ? order by strand asc, READS.read_id asc"
		   );

    my $statements = {};

    foreach my $query (keys %queries) {
	$statements->{$query} = $dbh->prepare($queries{$query});
	&db_die("Failed to create query \"$query\"");
    }

    return $statements;
}

sub FindNextBridge {
    my ($contigid, $contigend, $minbridges, $puclimit,
	$statements, $contiglength, $contigtoscaffold, $junk) = @_;

    my $contiglen = $contiglength->{$contigid};

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
    print STDERR "-instance\tName of instance\n";
    print STDERR "-organism\tName of organism\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-minbridges\tMinimum number of pUC bridges (default: 1)\n";
    print STDERR "-minbacbridges\tMinimum number of BAC bridges (default: 1)\n";
    print STDERR "-minlen\t\tMinimum contig length (default: all contigs)\n";
    print STDERR "-puclimit\tMaximum insert size for pUC subclones (default: 8000)\n";
    print STDERR "-verbose\tShow lots of detail (default: false)\n";
    print STDERR "-progress\tDisplay progress info on STDERR (default: false)\n";
    print STDERR "-usesilow\tUse the minimum insert size for long-range mapping (default: false)\n";
}
