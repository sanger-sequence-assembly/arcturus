#!/usr/local/bin/perl

use strict;

use TraceServer;

my $proj = shift || die "No project name specified";
my $last_seqid = shift || die "No min trace id specified";

my $ts = TraceServer->new(TS_DIRECT, TS_READ_ONLY, "");

my $group = $ts->get_group($proj, 'PASS')
    || die "Group '$proj / PASS' not found";

my $grit = $group->get_iterator(1);
$grit->set($last_seqid);

my $count = 0;

while (my $seq_id = $grit->next()) {
   my ($read, $index) = $ts->get_read_by_seq_id($seq_id);

   &processRead($seq_id, $read);


   print "\n";

   $count++;

   $last_seqid = $seq_id;
}

print STDERR "Got $count reads.\n";

exit(0);

sub processRead {
    my $seq_id = shift;
    my $read = shift;

    print "Readname = ",$read->get_name(),"\n";

    my $direction = $read->get_direction();

    if ($direction == TSR_FORWARD) {
	$direction = 'Forward'
	} elsif ($direction == TSR_REVERSE) {
	    $direction = 'Reverse';
	} else {
	    $direction = 'Unknown';
	}

    print "\tDirection = $direction\n";
    print "\tChemistry = ",$read->get_chemistry(),"\n";

    foreach my $attr ('TSR_PRIMER_NAME',
		      'TSR_PRIMER_SEQUENCE',
		      'TSR_UNIVERSAL_PRIMER',
		      'TSR_CHEMISTRY',
		      'TSR_CHEMISTRY_DESCRIPTION',
		      'TSR_RUN_DATETIME',
		      'TSR_STRATEGY',
		      'TSR_STRATEGY_DESCRIPTION',
		      'TSR_PROGRAM') {
	my $value = $read->get_attribute($attr);
	print "\t$attr = $value\n" if defined($value);
    }

    print "\tTraceArchiveID = $seq_id\n";

    my $seq = $read->get_sequence();

    my $dna = $seq->get_dna();

    my $qual = $read->get_confidence()->get_phred();

    print "\tLength = ", length($dna), " " , length($qual), "\n";

    my $numclips = $seq->get_num_clips();

    print "\n\tCLIPPING\n" if ($numclips > 0);

    for (my $jclip = 0; $jclip < $numclips; $jclip++) {
	my $clip = $seq->get_clip($jclip);
	print "\t\t",$clip->get_type()," ",$clip->get_start()," ",$clip->get_end(),"\n";
    }

    my $numtags = $seq->get_num_tags();

    print "\n\tTAGS\n" if ($numtags > 0);

    for (my $jtag = 0; $jtag < $numtags; $jtag++) {
	my $tag = $seq->get_tag($jtag);
	print "\t\t",$tag->get_type()," ",$tag->get_direction()," ",$tag->get_start()," ",
	$tag->get_end()," \"",$tag->get_text(),"\"\n";
    }

    my $indent = "\t";

    for (my $dnasrc = $read->get_dnasource();
	 defined($dnasrc);
	 $dnasrc = $dnasrc->get_parent()) {
	my ($srcclass,$srcname) = split(/::/, $dnasrc->get_name());

	print "\n";

	print $indent,"DNA source name = $srcname\n";
	print $indent,"DNA source class = $srcclass\n";

	my $srctype = $dnasrc->get_type(); 

	print $indent,"DNA source type = $srctype\n";

	if ($srctype eq 'clone') {
	    my ($srclibclass,$srclibname) = split(/::/, $dnasrc->get_library_name());

	    print $indent,"DNA source library name = $srclibname\n";
	    print $indent,"DNA source library class = $srclibclass\n";
	
	    print $indent,"DNA source library vector = ", $dnasrc->get_library_vector(), "\n";
	    print $indent,"DNA source library size = ", $dnasrc->get_library_size(), "\n";
	    print $indent,"DNA source library stddev = ", $dnasrc->get_library_stddev(), "\n";
	}

	$indent .= "\t";
    }
}
