#!/usr/local/bin/perl

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


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

           
    $log->setPrefix("putMappingsForContig $option{type}");

 		my $contig_savepoint = "BeforeMapping".$contig;

	  $dbh->{RaiseError} = 1;
	  eval {
    	&verifyPrivate($dbh,"putMappingsForContig");
    };
		if ($@) {
      $log->severe("Unable to verify mappings: ".$dbh->errstr);
		}
# this is a dual-purpose method writing mappings to the MAPPING and SEGMENT
# tables (read-to-contig mappings) or the C2CMAPPING and CSCSEGMENT tables 
# (contig-to-contig mapping) depending on the parameters option specified

# this method inserts mapping segments in blocks of 100
# define the queries and the mapping source

    my $mquery; # for insert on the (C2C)MAPPING table 
    my $squery; # for insert on the (C2C)SEGMENT table
    my $mappings; # for the array of Mapping instances
		my $sth; # the statement handle, re-used for several queries
		my @data; # for the data array

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

    eval {
      $sth = $dbh->prepare_cached($mquery);
    };
		if ($@) {
      $log->severe("Unable to prepare the query $mquery: ".$dbh->errstr);
      return 0; 
		}

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

    @data = ($contigid,
                    $mapping->getSequenceID(),
                    $cstart,
                    $cfinish,
                    $mapping->getAlignmentDirection());
		}

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

	eval {
    $sth->execute(@data);
	};
	if ($@) {
    &queryFailed($mquery,@data);
		$dbh->release($contig_savepoint);
	  $dbh->{RaiseError} = 0;
    return 0;
	}

  eval {
    $mapping->setMappingID($dbh->{'mysql_insertid'});
    $sth->finish();
	};
	if ($@) {
	  $log->severe("Failed to insert one or more sequence-to-contig mappings: ".$dbh->errstr);
		$dbh->rollback_to($contig_savepoint);
		$dbh->release($contig_savepoint);
	  $dbh->{RaiseError} = 0;
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
								    eval {
                    	$sth = $dbh->prepare($accumulatedQuery); 
                    	my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
                    	$sth->finish();
                    	$accumulatedQuery = $squery;
                    	$accumulated = 0;
										};
										if ($@) {
            					$log->severe("Error occurred preparing or executing $accumulatedQuery: ".$dbh->errstr);
											$dbh->rollback_to($contig_savepoint);
	  									$dbh->{RaiseError} = 0;
    									return 0;
										}
								}
            } # end foreach segment
        }
        else {
            $log->severe("Mapping ".$mapping->getMappingName().
		        " unexpectedly has no mapping_id");
            $success = 0;
        }
    } # end foreach mapping
# dump any remaining accumulated query after the last mapping has been processed
    if ($accumulated) {
# $log->debug("Insert mapping block (mapping loop) $accumulated\n($block)");
      eval {
        $sth = $dbh->prepare($accumulatedQuery); 
        my $rc = $sth->execute() || &queryFailed($accumulatedQuery);
        $sth->finish();
			};
			if ($@) {
       	$log->severe("Error occurred preparing or executing $accumulatedQuery: ".$dbh->errstr);
				$dbh->rollback_to($contig_savepoint);
	  		$dbh->{RaiseError} = 0;
    		return 0;
			}
    }

# we now update the contig-to-contig mappings by adding the parent range
# this is kept separate from the basic inserts because this is derived data
# which may or may not be transparently defined, hence may be missing (undef)

    eval {
    	&updateMappingsForContig ($dbh,$mappings) if ($option{type} eq "contig");
		};
		if ($@) {
      $log->severe("Error occurred in updateMappingsForContig: ".$dbh->errstr);
			$dbh->rollback_to($contig_savepoint);
	  	$dbh->{RaiseError} = 0;
    	return 0;
		}
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
#####################################
# the savepoint can be released here 
# once the commit is successful
#####################################
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
		$dbh->release($contig_savepoint);
	  $dbh->{RaiseError} = 0;
	};
	if ($@) {
  	$log->error("Failed to revert to savepoint $contig_savepoint: ".$dbh->errstr);
	}
 	$dbh->{RaiseError} = 0;
	return 0;
		
} # end 
