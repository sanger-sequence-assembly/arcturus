#!/usr/local/bin/perl -w

use strict;
use TraceServer;

# Dumps out all pertinent information about a trace
sub seq_dump {
    my ($ts, $name) = @_;
    print "\n=== $name ===\n";

    my $read = $ts->get_read_by_name($name);
    if (!defined($read)) {
	print "ERR: Not found\n";
	return;
    }

    # Attributes
    my @attributes =
       qw(TSR_NAME
	  TSR_CENTRE_CODE
	  TSR_CENTRE_DESCRIPTION
	  TSR_SOURCE_CODE
	  TSR_SOURCE_DESCRIPTION
	  TSR_SPECIES_CODE
	  TSR_SPECIES_DESCRIPTION
	  TSR_STATUS_DESCRIPTION
	  TSR_AVAILABILITY_CODE
	  TSR_AVAILABILITY_DESCRIPTION
	  TSR_PROJECT
	  TSR_DIRECTION
	  TSR_CHEMISTRY
	  TSR_CHEMISTRY_DESCRIPTION
	  TSR_RUN_DATETIME
	  TSR_MACHINE_NAME
	  TSR_MACHINE_TYPE
	  TSR_MACHINE_DESCRIPTION
	  TSR_TRACE_TYPE
	  TSR_STRATEGY
	  TSR_STRATEGY_DESCRIPTION
	  TSR_PROGRAM
	  TSR_RUN
	  TSR_LANE
	  TSR_PRIMER_SEQUENCE
	  TSR_CHROMOSOME_CODE
	  TSR_CHROMOSOME_DESCRIPTION);

    foreach (@attributes) {
	my $val = $read->get_attribute($_);
	if ($_ eq "TSR_RUN_DATETIME") {
	    printf("%-30s = %s\n", $_, defined($val)
		   ? "" . localtime($val) : "(undef)");
	} else {
	    printf("%-30s = %s\n", $_, defined($val) ? $val : "(undef)");
	}
    }
    print "\n";

    # DNA Source
    my $src = $read->get_dnasource();
    my $s = "";
    while (defined($src)) {
	print "${s}DNASource: $src\n";
	print "$s    Name       = ", $src->get_name(), "\n";
	print "$s    Type       = ", $src->get_type(), "\n";
	my $parent = $src->get_parent();
	if (defined($parent)) {
	    print "$s    Parent     = $parent\n";
	} else {
	    print "$s    Parent     = (none)\n";
	}
	if ($src->get_type() eq "clone") {
	    print "$s    - l.name   = ", $src->get_library_name(), "\n";
	    print "$s    - size     = ", $src->get_library_size(), "\n";
	    print "$s    - stddev   = ", $src->get_library_stddev(), "\n";
	    print "$s    - vector   = ", $src->get_library_vector(), "\n";
	    print "$s    - is_trans = ", $src->get_library_is_transposon(), "\n";
	} else {
	    print "$s    - p.name   = ", $src->get_pcr_name(), "\n";
	    print "$s    - desc     = ", $src->get_pcr_description(), "\n";
	    print "$s    - est.size = ", $src->get_pcr_size(), "\n";
	    print "$s    - fwd      = ", $src->get_pcr_fwd_primer(), "\n";
	    print "$s    - rev      = ", $src->get_pcr_rev_primer(), "\n";
	}

	$src = $parent;
	$s .= "    ";
    }

    # Notes
    my $nnotes = $read->get_num_notes;
    for (my $i = 0; $i < $nnotes; $i++) {
	my $n = $read->get_note($i);
	print "\nNote \#$i\n";
	print "    type  = ", $n->get_type(), "\n";
	print "    time  = ". localtime($n->get_time()) . "\n";
	print "    text  = ", $n->get_text(), "\n";
    }
    
    # Sequence, confidence, positions
    my $nseqs = $read->get_num_sequences;
    for (my $i = 0; $i < $nseqs; $i++) {
	print "\nSequence \#$i\n";
	my $seq = $read->get_sequence_by_index($i);
	my $pos = $read->get_positions_by_index($i);
	my ($conf, $ttype, $stype) = $read->get_confidence_by_index($i);
	my $seqid = $seq->get_id();
	print "    Trace type = $ttype\n";
	print "    Seq.  type = $stype\n";
	print "    Seq. ID    = $seqid\n";
	print "    Seq.       = $seq\n";

	# Sequence tags
	my $ntags = $seq->get_num_tags;
	for (my $i = 0; $i < $ntags; $i++) {
	    my $t = $seq->get_tag($i);
	    print "    Tag \#$i\n";
	    print "        type  = ", $t->get_type(), "\n";
	    print "        start = ", $t->get_start(), "\n";
	    print "        end   = ", $t->get_end(), "\n";
	    print "        dir.  = ", $t->get_direction(), "\n";
	    print "        time  = ". localtime($t->get_time()) . "\n";
	    print "        text  = ", $t->get_text(), "\n";
	}
    
	# Sequence clips
	my $nclips = $seq->get_num_clips;
	for (my $i = 0; $i < $nclips; $i++) {
	    my $c = $seq->get_clip($i);
	    print "    Clip \#$i\n";
	    print "        type  = ", $c->get_type(), "\n";
	    print "        start = ", $c->get_start(), "\n";
	    print "        end   = ", $c->get_end(), "\n";
	}
    
	if (defined($seq)) {
	    print "    Sequence   = ", $seq->get_dna, "\n";
	} else {
	    print "    Sequence   = (undef)\n";
	}
	if (defined($conf)) {
	    my @pcon = unpack("C*", $conf->get_phred());
	    print "    Confidence = @pcon\n";
	} else {
	    print "    Confidence = (undef)\n";
	}
	if (defined($pos)) {
	    my $values = $pos->get_positions();
	    print "    Positions  = @$values\n";
	} else {
	    print "    Positions  = (undef)\n";
	}
    }
    
    # Trace
    my $ntraces = $read->get_num_traces();
    for (my $i = 0; $i < $ntraces; $i++) {
	print "\nTrace \#$i\n";
	my ($trace, $type) = $read->get_trace_by_index($i);
	print "    Trace obj  = $trace\n";
	print "    Trace type = $type\n";
	print "    Trace fmt  = ", $trace->get_format(), "\n";
	
	my $exp = $trace->get_data("EXP");
	if (defined($exp))  {
	    print "    Trace data = (defined)\n";
	    print "    EXP File   = \n$exp\n";
	} else {
	    print "    Trace data = (undef)\n";
	}
    }
    
    undef $read;
}

# -----------------------------------------------------------------------------

# Connect
my $ts;
eval {
    $ts = TraceServer->new(TS_DIRECT, TS_READ_ONLY, "");
};
die if ($@);

$| = 1; # autoflush

# Iterate through arguments
foreach (@ARGV) {
    seq_dump($ts, $_);
}

# Disconnect
undef $ts;

