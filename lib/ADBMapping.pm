use strict;

use NewMapping;

use NewSegment;

#use ArcturusDatabase::ADBRead;

#our @ISA = qw(ArcturusDatabase::ADBRead);

use ArcturusDatabase;

our @ISA = qw(ArcturusDatabase);

use ArcturusDatabase::ADBRoot qw(queryFailed);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#-----------------------------------------------------------------------------
# insert using the canonical mapping 
#-----------------------------------------------------------------------------

sub putReadMappingsForContig {
    my $this = shift;
    my $contig = shift;
    my %options = @_;

    my $mappings = $contig->getMappings();

    return 0 unless ($mappings && @$mappings);

# get the template IDs for the normalised mappings

    my $dbh = $this->getConnection();

    &getIDsForCanonicalMappings($dbh,$mappings,%options); # puts new canonical mappings 

# write the mappings to database in blocks (one record per mapping)

    my $contig_id = $contig->getContigID();

    my $block = $options{block} || 100;

    my $insert = "insert into SEQ2CONTIG " # ORDER of pars?
      	       . "(contig_id,seq_id,mapping_id,coffset,roffset,direction)"
               . " values ";

    my $success = 1;
    my $accumulated = 0;
    my $accumulatedinsert = $insert;
    my $lastmapping = pop @$mappings;
    foreach my $mapping (@$mappings,$lastmapping) {
        my $seq_id = $mapping->getSequenceID();
        my $direction = $mapping->getDirection();
        my $coffset = $mapping->getTemplateOffsetX();
        my $roffset = $mapping->getTemplateOffsetY();
        my $mid = $mapping->getMappingID();
        $accumulatedinsert .= "," if $accumulated++;
        $accumulatedinsert .= "($contig_id,$seq_id,$mid,"
                            .  "$coffset,$roffset,'$direction')";
        next unless ($accumulated >= $block || $mapping eq $lastmapping);      
# the preset number of inserts has been reached: execute the query
        my $sth = $dbh->prepare($accumulatedinsert);
        my $rc = $sth->execute() || &queryFailed($accumulatedinsert);
        $success = 0 unless $rc;
        $sth->finish();
# prepare for new insert
        $accumulatedinsert = $insert;
        $accumulated = 0;
    }

}

sub putContigMappingsForContig {
    my $this = shift;
    my $contig = shift;
    my  %options = @_;

    my $mappings = $contig->getContigToContigMappings();

    return 0 unless ($mappings && @$mappings);

# get the template IDs for the normalised mappings

    my $dbh = $this->getConnection();

    &getIDsForCanonicalMappings($dbh,$mappings,%options);

#  write the mappings to database individually

    my $contig_id = $contig->getContigID();

    my $insert = "insert into C2CMAPPING " 
   	       . "(contig_id,parent_id,mapping_id,coffset,poffset,direction"
               . " values (?,?,?,?,?,?,?,?,?,?)";
#   	       . "(contig_id,parent_id,mapping_id,cstart,cfinish,pstart,pfinish,coffset,poffset,direction"

    my $sth = $dbh->prepare_cached($insert);

    foreach my $mapping (@$mappings) {

#        my ($cstart,$cfinish) = $mapping->getContigRange();
#        my ($pstart,$pfinish) = $mapping->getMappedRange();

        my @data = ($contig_id,
                    $mapping->getSequenceID(),
                    $mapping->getMappingID(),#
#                    $cstart, $cfinish,$pstart,$pfinish,
                    $mapping->getTemplateOffsetX(),
                    $mapping->getTemplateOffsetY(),
                    $mapping->getDirection() );
        my $rc = $sth->execute(@data) || &queryFailed($insert,@data);                
    }
    $sth->finish();
}

sub putTagMappingsForContig {
# adbcontig 2890 e.o. (+13)
    my $this = shift;
    my $contig = shift;
    my %options = @_;
}

#-----------------------------------------------------------------------------

sub getIDsForCanonicalMappings {
# private helper method: find template IDs using checksum; load new templates
    my $dbh = shift; # database handle
    my $mappings;
    my %options = @_;

# collect all checksums in a hash table (transform mappings as well)

    my $checksumhash = {};
    foreach my $mapping (@$mappings) {
        my $checksum = $mapping->getCheckSum(transform=>1); # transforms the mapping if needed
        $checksumhash->{$checksum} = 0;
    }

# identify existing mappings in the database; store in checksumhash

    my @checksumlist = keys %$checksumhash;
    my $nrofoldchecksums = &getCheckSumIDs($dbh,\@checksumlist,$checksumhash);

# identify new mappings (have the checksum hash entry still undefined); record first

    my @newtemplates = [];
    my $newchecksums = {};
    foreach my $mapping (@$mappings) {
	my $checksum = $mapping->getCheckSum();
	next if $checksumhash->{$checksum}; # it's already in the database
        next if $newchecksums->{$checksum}; # only keep the first one
        $newchecksums->{$checksum} = 1;
        push @newtemplates,$mapping;
    }

# insert the new data into the database

#    my $nrofinserts = &putCheckSum($dbh,[@newtemplates]);
    my @newchecksums = keys %$newchecksums;
    my $nrofinserts = &putCheckSum($dbh,[@newchecksums]);
#    unless ($nrofinserts == scalar(@newchecksums)) {
# what action ?
#    }

# and retrieve the checksum IDs and add to the checksumhash

    my $nrofnewchecksums = &getCheckSumIDs($dbh,[@newchecksums],$checksumhash);
# NOTE: all hash entries should now be > 0 and old+new should equal nr of hash keys
#    unless ($nrofnewchecksums+$nrofoldchecksums == scalar(keys %$checksumhash)) {
# what action ?
#    }

# complete the mappings: put the mapping ID in place

    foreach my $mapping (@$mappings) {
	my $checksum = $mapping->getCheckSum();
        if (my $mid = $checksumhash->{$checksum}) {
            $mapping->setMappingID($mid);
	}
	else {
# unexpectedly no mapping ID  
# WHAT ACTION
	}
    }

# now write the segments for the newly added checksums 

    &putCanonicalMappings($dbh,@newtemplates);
}

sub getCheckSumIDs {
# private helper method : retrieve checksum and ID for an input list of checksums
    my $dbh = shift; # database handle
    my $csa = shift; # array ref to list of checksum values to be retrieved
    my $csh = shift; # hash ref for values which are retrieved
    my %options = @_;

    my $blocksize = $options{blocksize} || 1000;

    my $bquery = "select mapping_id,checksum from MAPPING where checksum in ";
#    my $bquery = "select mapping_id,checksum from CANONICALMAPPING where checksum in ";

    my $retrieved = 0;

    while (my $checksumsleft = @$csa) {
        $blocksize = $checksumsleft if ($blocksize > $checksumsleft);
        my @block = splice @$csa, 0, $blocksize;
        my $select = $bquery."('". join("'),('", @block) ."')";
        my $sth = $dbh->prepare($select);
        my $rc = $sth->execute() || &queryFailed($select) && next;
	while (my ($id, $csum) = $sth->fetchrow_array()) {
	    $csh->{$csum} = $id;
            $retrieved++;
	}
    }
    return $retrieved;
}

sub putCheckSums { # REWRITE to insert crange and rrange as derived parameters
# private helper method : insert new checksums into the database in bulk
    my $dbh = shift; # database handle
    my $csa = shift; # array ref to list of checksum values to be inserted
    my %options = @_;

    my $blocksize = $options{blocksize} || 1000;

    my $iquery = "insert into MAPPING (checksum) values ";

    my $inserted = 0;
    while (my $checksumsleft = @$csa) {
        $blocksize = $checksumsleft if ($blocksize > $checksumsleft);
        my @block = splice @$csa, 0, $blocksize;
        my $insert = $iquery."('". join("'),('", @block) ."')";
        my $sth = $dbh->prepare($insert);
        my $rc = $sth->execute() || &queryFailed($insert) && next;
        $inserted += $rc;
    }
# the number of inserts should equal the number of input checksum values
    return $inserted;
}

sub newputCheckSums { # REWRITE to insert xrange and yrange as derived parameters
# private helper method : insert new checksums into the database in bulk
    my $dbh = shift; # database handle
    my $maps = shift; # array ref to list of checksum values to be inserted
    my %options = @_;

    my $blocksize = $options{blocksize} || 1000;

    my $iquery = "insert into MAPPING (checksum,xrange,yrange) values ";

    my $inserted = 0;
    while (my $checksumsleft = scalar(@$maps)) {
        $blocksize = $checksumsleft if ($blocksize > $checksumsleft);
        my @block = splice @$csa, 0, $blocksize;
        my $insert = $iquery."('". join("'),('", @block) ."')";

        my $sth = $dbh->prepare($insert);
        my $rc = $sth->execute() || &queryFailed($insert) && next;
        $inserted += $rc;
    }
# the number of inserts should equal the number of input checksum values
    return $inserted;
}

sub putCanonicalMappings {
# private helper method: insert new canonical mappings into the database
    my $dbh = shift; # database handle
    my $canonicalmappings = shift; 
    
    my $insert = "insert into SEGMENT (mapping_id,xstart,ystart,length) values ";
#    my $insert = "insert into CANONICALSEGMENT (mapping_id,cstart,pstart,length) values ";

    my $block = 100;
    my $success = 1;
    my $accumulated = 0;
    my $accumulatedinsert = $insert;

    foreach my $mapping (@$canonicalmappings) {
        my $mid = $mapping->getMappingID();
        next unless $mid; # mapping ID test is to be done in calling routine
        my $segments = $mapping->orderSegmentsInXdomain();
        foreach my $segment (@$segments) {
            my $length = $segment->getSegmentLength();
            my $xstart = $segment->getXstart();
            my $ystart = $segment->getYstart();
            $accumulatedinsert .= "," if $accumulated++;
            $accumulatedinsert .= "($mid,$xstart,$ystart,$length)";
            next unless ($accumulated >= $block);
# the preset number of inserts has been reached: execute the query
            my $sth = $dbh->prepare($accumulatedinsert);
            my $rc = $sth->execute() || &queryFailed($accumulatedinsert);
            $success = 0 unless $rc;
            $sth->finish();
# prepare for new insert
            $accumulatedinsert = $insert;
            $accumulated = 0;
	}
    }

# if there is anything left ...
   
    if ($accumulated) {
        my $sth = $dbh->prepare($accumulatedinsert);
        my $rc = $sth->execute() || &queryFailed($accumulatedinsert);
        $success = 0 unless $rc;
        $sth->finish();
    }
}

#-----------------------------------------------------------------------------
# retrieval of mappings
#-----------------------------------------------------------------------------

sub getReadMappingsForContig {
}

sub getContigMappingsForContig {
}

sub getTagMappingsForContig {
}

#-----------------------------------------------------------------------------

1;
