#!/usr/local/bin/perl

# test to establish where to put savepoints within putMappingsForContig
use strict;

use DBI;

sub putMappingsForContig {
# if $option = "read" there can be several million rows spread across a number of mappings
# if option is "contig" then there are tens of inserts instead.
# the savepoint is created and released within putMappingsForContig
# until a way can be found to share it with the calling program that creates 
# the larger transaction.
# the savepoint is within an eval tried four times, with a 1,4,16 minute backoff
# If all four tries fail, then an RT ticket is raised.

# private method, write mapping contents to (C2C)MAPPING & (C2C)SEGMENT tables
    my $dbh = shift; # database handle
    my $contig = shift;
    my $log = shift;
    my %option = @_;

 		my $contig_savepoint = "BeforeMapping".$contig;

    &verifyPrivate($dbh,"putMappingsForContig");

# this is a dual-purpose method writing mappings to the MAPPING and SEGMENT
# tables (read-to-contig mappings) or the C2CMAPPING and CSCSEGMENT tables 
# (contig-to-contig mapping) depending on the parameters option specified

# this method inserts mapping segments in blocks of 100
           
    $log->setPrefix("putMappingsForContig $option{type}");

# define the queries and the mapping source

    my $mquery; # for insert on the (C2C)MAPPING table 
    my $squery; # for insert on the (C2C)SEGMENT table
    my $mappings; # for the array of Mapping instances

    if ($option{type} eq "read") {
# for read-to-contig mappings
        $mappings = $contig->getMappings();
        return 0 unless $mappings; # MUST have read-to-contig mappings
        $mquery = "insert into MAPPING " .
                  "(contig_id,seq_id,cstart,cfinish,direction) ";
        $squery = "insert into SEGMENT " .
                  "(mapping_id,cstart,rstart,length) values ";
    }
    elsif ($option{type} eq "contig") {
# for contig-to-contig mappings
        $mappings = $contig->getContigToContigMappings();
        return 1 unless $mappings; # MAY have contig-to-contig mappings
        $mquery = "insert into C2CMAPPING " .
	          "(contig_id,parent_id,cstart,cfinish,direction) ";
        $squery = "insert into C2CSEGMENT " .
                  " (mapping_id,cstart,pstart,length) values ";
    }
    else {
        $option{type} = 'missing' unless $option{type};
        $log->severe("Missing or invalid 'type' parameter $option{type}");
        return 0; 
    }

    $mquery .= "values (?,?,?,?,?)";

    my $sth = $dbh->prepare_cached($mquery);

    my $contigid = $contig->getContigID();

# 1) the overall mapping

    my $mapping;
    my $success = 1;
    foreach $mapping (@$mappings) {

# optionally scan against empty mappings

        unless ($mapping->hasSegments()) {
	    next if $option{notallowemptymapping};
	}

        my ($cstart, $cfinish) = $mapping->getContigRange();

        my @data = ($contigid,
                    $mapping->getSequenceID(),
                    $cstart,
                    $cfinish,
                    $mapping->getAlignmentDirection());

##############################
# make the savepoint 
##############################

 	$log->debug("Creating savepoint $contig_savepoint");

	eval {
		$dbh->savepoint($contig_savepoint);
  };
	if ($@) {
	 	$log->warning("Failed to create savepoint $contig_savepoint: ".$dbh->errstr);
	}
##############################
# turn off commits 
##############################

  $log->debug("Beginning work so no commits from now on");
	eval {
     $dbh->begin_work;
	};
	if ($@) {
	 	$log->warning("Failed to turn off commits to work on $contig: ".$dbh->errstr);
		# But carry on anyway? KATE die here and put all other DBI statements in evals
	}

        my $rc = $sth->execute(@data) || &queryFailed($mquery,@data);

        if ($rc == 1) {
            $mapping->setMappingID($dbh->{'mysql_insertid'});
	}
        else {
	    $success = 0;
	}
        
    }
    $sth->finish();

    unless ($success) {
	$log->severe("Failed to insert one or more sequence-to-contig mappings");
        return 0;
    }

# 2) the individual segments (in block mode)

    my $block = 100;
    my $accumulated = 0;
    my $accumulatedQuery = $squery;
    foreach my $mapping (@$mappings) {
# test existence of segments
        next unless $mapping->hasSegments();
# test existence of mappingID
        my $mappingid = $mapping->getMappingID();
        if ($mappingid) {
            my $segments = $mapping->normaliseOnX(); # order contig range
#          my $segments = $mapping->getSegments();
            foreach my $segment (@$segments) {
#              my $length = $segment->normaliseOnX(); # order contig range
                my $length = $segment->getSegmentLength();
                my $cstart = $segment->getXstart();
                my $rstart = $segment->getYstart();
                $accumulatedQuery .= "," if $accumulated++;
                $accumulatedQuery .= "($mappingid,$cstart,$rstart,$length)";
# dump the accumulated query if a number of inserts has been reached
# $log->debug("Insert mapping block (mapping loop) $accumulated\n($block)");
                if ($accumulated >= $block) {
                    $sth = $dbh->prepare($accumulatedQuery); 
                    my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
                    $sth->finish();
                    $success = 0 unless $rc;
                    $accumulatedQuery = $squery;
                    $accumulated = 0;
		}
            }
        }
        else {
            $log->severe("Mapping ".$mapping->getMappingName().
		        " unexpectedly has no mapping_id");
            $success = 0;
        }
    }
# dump any remaining accumulated query after the last mapping has been processed
    if ($accumulated) {
# $log->debug("Insert mapping block (mapping loop) $accumulated\n($block)");
        $sth = $dbh->prepare($accumulatedQuery); 
        my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
        $sth->finish();
        $success = 0 unless $rc;
    }

# we now update the contig-to-contig mappings by adding the parent range
# this is kept separate from the basic inserts because this is derived data
# which may or may not be transparently defined, hence may be missing (undef)

    &updateMappingsForContig ($dbh,$mappings) if ($option{type} eq "contig");

#####################################
# the savepoint can be released here 
# once the commit is successful
#####################################

	my $retry_in_secs = 0.01 * 60;
	my $retry_counter = 0.25;
	my $counter = 1;
	my $max_retries = 4;
 
  until ($counter > ($max_retries + 1)) {
		eval {
	  	$dbh->commit();
		};
		if ($@) {
  		$retry_counter = $retry_counter * 4;
   		$log->warning("\tAttempt $counter for the insert statement for $option{type} mapping for contig $contig\n");
	 		$retry_in_secs = $retry_in_secs * $retry_counter;
	 		if ($counter < $max_retries) {
	   		$log->warning("\tStatement has failed so wait for $retry_in_secs seconds\n");
	   		sleep($retry_in_secs);
	 		}
	 		$counter++;
		}
		else {
			# the commit has succeeded so the savepoint can be released
    	$log->debug("Commit is successful so releasing savepoint for contig $contig");
			eval {
				$dbh->release($contig_savepoint);
			};
			if ($@) {
				$log->error ("Failed to release savepoint $contig_savepoint: ".$dbh->errstr);
			}
    	return $success;
		}
	} # end until finished re-trying

	$log->error("\tStatement has failed $counter times so give up:  some other process has locked $contig or database error $dbh->errstr\n");
  $log->error("Reverting to savepoint $contig_savepoint");
	eval {
		$dbh->rollback_to($contig_savepoint);
	};
	if ($@) {
  	$log->error("Failed to revert to savepoint $contig_savepoint: ".$dbh->errstr);
	}
	return 0;
		
} # end 
