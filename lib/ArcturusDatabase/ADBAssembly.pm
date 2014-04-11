package ArcturusDatabase::ADBAssembly;

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


use strict;

use Assembly;

use ArcturusDatabase::ADBProject;

our @ISA = qw(ArcturusDatabase::ADBProject);

use ArcturusDatabase::ADBRoot qw(queryFailed);

use constant RETRY_IN_SECS => 0.0001 * 60;

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    return $this;
}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

sub putAssembly {
# create a new assembly
    my $this = shift;
    my $assembly = shift;

    die "putAssembly expects an Assembly instance as parameter"
	unless (ref($assembly) eq 'Assembly');

    return undef unless $this->userCanCreateProject(); # check privilege

    my $items = "name,chromosome,progress,created,creator,comment";

    my @idata = ($assembly->getAssemblyName(),
                 $assembly->getChromosome(),
                 $assembly->getProgressStatus(),
                 $assembly->getCreator(),
                 $assembly->getComment()      );

    my $query = "insert into ASSEMBLY ($items) values (?,?,?,now(),?,?)";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute(@idata) || &queryFailed($query,@idata);

    $sth->finish();

    return 0 unless ($rc && $rc == 1);
    
    my $assemblyid = $dbh->{'mysql_insertid'};

    $assembly->setProjectID($assemblyid);

    return $assemblyid;
}

#-----------------------------------------------------------------------------
# 
#-----------------------------------------------------------------------------

sub getAssembly {
# return an array of assembly objects, or undef
    my $this = shift;
    my %options = @_; # no options returns all

    my $items = "ASSEMBLY.assembly_id,ASSEMBLY.name,"
              . "chromosome,progress,ASSEMBLY.updated,"
              . "ASSEMBLY.creator,ASSEMBLY.comment";
    my $query = "select $items from ASSEMBLY";

    my @data;
    foreach my $key (sort {$b cmp $a} keys %options) { # p before a !
        push @data, $options{$key};
        if ($key eq 'project_id' || $key eq 'projectname') {
            unless ($query =~ /join/) {
                $query .= " join PROJECT using (assembly_id)";
	    }
            $query .= ($query =~ /where/ ? ' and' : ' where');
            $query .= " PROJECT.project_id = ?" if ($key eq 'project_id');
            $query .= " PROJECT.name like ?"    if ($key eq 'projectname');
        }
        elsif ($key eq 'assembly_id' || $key eq 'assemblyname') {
            $query .= ($query =~ /where/ ? ' and' : ' where');
            $query .= " ASSEMBLY.assembly_id = ?" if ($key eq 'assembly_id');
            $query .= " ASSEMBLY.name like ?"     if ($key eq 'assemblyname');
        }
	else {
            my $log = $this->verifyLogger("getAssembly");
            $log->error("Invalid option $key");
	}
    }

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $nr = $sth->execute(@data) || &queryFailed($query,@data);

# return an array of assembly objects

    my @assemblys;
    undef my %assemblys;
    while (my @ary = $sth->fetchrow_array()) {
# prevent multiple copies of the same assembly
        my $assembly = $assemblys{$ary[0]};
        unless ($assembly) {
            $assembly = new Assembly();
	    $assemblys{$ary[0]} = $assembly;
            push @assemblys,$assembly;
            $assembly->setAssemblyID(shift @ary);
            $assembly->setAssemblyName(shift @ary);
            $assembly->setChromosome(shift @ary);
            $assembly->setProgressStatus(shift @ary);
            $assembly->setUpdated(shift @ary);
            $assembly->setCreator(shift @ary);
            $assembly->setComment(shift @ary);
# assign ADB reference
            $assembly->setArcturusDatabase($this);
        }
    }

    $sth->finish();

    return [@assemblys],$assemblys[0]; # array ref
}


#------------------------------------------------------------------------------
# miscellaneous methods
#------------------------------------------------------------------------------

sub getProjectIDsForAssemblyID {
# return list of project IDs for given assembly ID
    my $this = shift;
    my $assembly_id = shift;

# the query implicitly tests the existence of the assembly

    my $query = "select project_id from PROJECT join ASSEMBLY"
              . " using (assembly_id)"
	      . " where assembly_id = ?";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($assembly_id) || &queryFailed($query,$assembly_id);

    my @pids;
    while (my ($pid) = $sth->fetchrow_array()) {
        push @pids, $pid;
    }

    $sth->finish();

    return [@pids]; # array ref
}

sub getAssemblyDataforReadName {
# return project data keyed on contig_id for input readname
    my $this = shift;
    my %options = @_;

    my ($readitem,$value) = each %options;

    my $contig_items = "CONTIG.contig_id,gap4name,CONTIG.created";
    my $projectitems = "PROJECT.name,PROJECT.owner,assembly_id";

    my $query = "select distinct $contig_items,$projectitems,CONTIG.nreads"
              . "  from READINFO,SEQ2READ,MAPPING,CONTIG,PROJECT"
              . " where CONTIG.project_id = PROJECT.project_id"
              . "   and CONTIG.contig_id = MAPPING.contig_id"
	      . "   and MAPPING.seq_id = SEQ2READ.seq_id"
	      . "   and SEQ2READ.read_id = READINFO.read_id"
	      . "   and READINFO.$readitem = ?"
              . " order by contig_id DESC";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    $sth->execute($value) || &queryFailed($query,$value);

    my $resultlist = {};
    while (my ($contig_id,@items) = $sth->fetchrow_array()) {
        $resultlist->{$contig_id} = [@items];
    }

    $sth->finish();

    return $resultlist;
}

#------------------------------------------------------------------------------
# scaffolds
#------------------------------------------------------------------------------

sub putScaffoldForImportID {
    my $this = shift;
    my $import_id = shift;
# NOTE : these parameters could be replaced by passing a Scaffold instance instead 
    my $scaffold = shift;
    my %options = @_; # type,source,comment

		my $logger = $this->verifyLogger('putScaffoldForImportID');

    unless (ref($scaffold) eq 'ARRAY') { # or later Scaffold ?
      $logger->error("invalid parameter scaffold $scaffold");  
			return undef;
    }

    return unless @$scaffold;

    my $dbh = $this->getConnection();

# tables SCAFFOLD & SCAFFOLDTYPE & CONTIGORDER

    my $type_id = 0;

    my $type  = $options{type} || "undefined";    

    my $query = "select type_id from SCAFFOLDTYPE where type = ?";

    my $sth = $dbh->prepare_cached($query);

    my $irc = $sth->execute($type) || &queryFailed($query,$type);

    $type_id = $sth->fetchrow_array() if ($irc && $irc+0);

    $sth->finish();

    unless ($type_id) {
# insert a new entry into the table and return the last insert id
        $type = $dbh->quote($type);
	my $rc = $dbh->do("insert into SCAFFOLDTYPE (type) values ($type)") || 0;
        $type_id = $dbh->{'mysql_insertid'} if ($rc+0);
    }

# now enter a SCAFFOLD entry

    my $scaffold_id = 0;

    my @binddata = ($this->getArcturusUser(),
                    $import_id,
                    $type_id,
                    $options{source}  || "unknown",
		    $options{comment} || '');

    $dbh->{RaiseError} = 1;

    my $status = 0;
		     
		my $retry_in_secs = RETRY_IN_SECS;
		my $retry_counter = 0.25;
		my $counter = 1;
		my $max_retries = 4;
		 
		my $scaffold_savepoint = "ScaffoldEntry";
		 
		##############################
		# make the savepoint 
		##############################
		 
		$logger->debug("Creating savepoint $scaffold_savepoint");
		 
		eval {
		    my $savepoint_handle = $dbh->prepare("SAVEPOINT ".$scaffold_savepoint);
		    $savepoint_handle->execute();
		    #$dbh->savepoint($scaffold_savepoint);
		};
		if ($@) {
		   $logger->warning("Failed to create savepoint $scaffold_savepoint: ".$DBI::errstr);
		}
		 
		############################
		# start the retry 
		############################
    until ($counter > ($max_retries )) {
		   #####################################
		   # start the eval block
		   #####################################

    	eval {
				$dbh->begin_work;

				my $sinsert = "insert into SCAFFOLD (creator,created,import_id,type_id,source,comment) "
	    . "values (?,now(),?,?,?,?)";
    
				my $isth = $dbh->prepare_cached($sinsert);

				my $rc = $isth->execute(@binddata) || &queryFailed($sinsert,@binddata);

				$scaffold_id = $dbh->{'mysql_insertid'} if ($rc+0);

				$isth->finish();
    
# insert the CONTIGORDER data

				my $cinsert = "insert into CONTIGORDER (scaffold_id,contig_id,position,direction,following_gap_size) "
	    . "values (?,?,?,?,?)";

				my $csth = $dbh->prepare_cached($cinsert);

				foreach my $member (@$scaffold) {
	    		next unless ($member->[1] > 0); # protection against undefined contig_id
	    		my @idata = @$member; # length 3
	    		push @idata,'forward' unless (scalar(@idata) >= 3); # should be caught by Scaffold class
	    		push @idata,undef unless (scalar(@idata) >= 4); # should be caught by Scaffold class
	    		my $crc = $csth->execute($scaffold_id,@idata) || &queryFailed($cinsert,$scaffold_id,@idata);
	    $status++ if ($crc+0);
				}
	
			$dbh->commit;

			$csth->finish();
    	};
			if ($@) {
				if ($DBI::err == 1205) {
					print STDERR "putScaffoldForImportID: Failed to store scaffold in database: " . $@ . "\n";
					$logger->severe("Some other process has locked CONTIG table so failed to store scaffold in database");
					$logger->special("Some other process has locked CONTIG table so failed to store scaffold in database");
					$retry_counter = $retry_counter * 4;
					$retry_in_secs = $retry_in_secs * $retry_counter;
					if ($counter < $max_retries) {
						$logger->warning("\tCONTIG table is locked by another process so wait for $retry_in_secs seconds");
						sleep($retry_in_secs);
						$counter++;
					}
					else { #retry has ended so report the timeout
						$logger->severe("\tStatement(s) failed $counter times as some other process has locked CONTIG table");
						$logger->error("\tRolling back to savepoint $scaffold_savepoint");
						eval {
					     my $savepoint_handle = $dbh->do("ROLLBACK TO SAVEPOINT ".$scaffold_savepoint);
							$savepoint_handle = $dbh->do("RELEASE SAVEPOINT ".$scaffold_savepoint);
					   };
					   if ($@) {
					     	$logger->severe("Failed to rollback to savepoint $scaffold_savepoint: ".$DBI::errstr);
	    					print STDERR "putScaffoldForImportID: ***** ROLLBACK FAILED: " . $@ . " *****\n";
					    }
					    return 0;
						}
					} # end 1205 error
					else { # some other database error has occurred
						$logger->severe("Error occurred preparing or executing the insert: \n".$DBI::errstr);
						$logger->special("\tRolling back to savepoint $scaffold_savepoint because $DBI::errstr");
						eval {
							my $savepoint_handle = $dbh->do("ROLLBACK TO SAVEPOINT ".$scaffold_savepoint);
							$savepoint_handle = $dbh->do("RELEASE SAVEPOINT ".$scaffold_savepoint);
						};
						if ($@) {
							$logger->severe("Failed to rollback to savepoint $scaffold_savepoint: ".$DBI::errstr);
		         }
			       return 0;
		      }
		   } # end if errors
		  else {
    		$dbh->{RaiseError} = 0;
    		return $status;
			}
		} # end retry
}

sub getScaffoldForProject {
# returns an ordered list of contig IDs last imported for the project
    my $this = shift;
    my $project = shift; # project instance

    my $project_id = $project->getProjectID();

    my $subquery = "select max(id) from IMPORTEXPORT where project_id = ? "; # get the last one

    my $query = "select contig_id,position,direction"
              . "  from CONTIGORDER join SCAFFOLD using (scaffold_id)"
              . " where SCAFFOLD.import_id in ($subquery)"
#             . "   and SCAFFOLD.source = 'Arcturus contig-loader'"
#              . "   and contig_id in (select contig_id from CURRENTCONTIGS)"
              . " order by position";
# either build a scaffold object or put an ordered list of contig_ids in Project

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($project_id) || &queryFailed($query,$project_id);
    $project->addContigID(undef,scaffold=>1); # clear any
    while (my @ary = $sth->fetchrow_array()) {
        $ary[0] = -$ary[0] if ($ary[2] eq 'reverse');
        $project->addContigID($ary[0],scaffold=>1);
    }
    $sth->finish();
# on exit the project instance contains the list of ordered contig_ids
    return $rc;
}

sub getScaffoldByIDforProject {
# returns an ordered list of contig IDs last imported for the project
    my $this = shift;
    my $project = shift; # project instance
    my $identifier = shift;

    my $query = "select contig_id,position,direction"
              . "  from CONTIGORDER join SCAFFOLD using (scaffold_id)"
              . " where SCAFFOLD.scaffold_id = ?"
#             . "   and SCAFFOLD.source = 'Arcturus contig-loader'"
              . " order by position";

    my $dbh = $this->getConnection();

    my $sth = $dbh->prepare_cached($query);

    my $rc = $sth->execute($identifier) || &queryFailed($query,$identifier);

    while (my @ary = $sth->fetchrow_array()) {
        $ary[0] = -$ary[0] if ($ary[2] eq 'reverse');
        $project->addContigID($ary[0],scaffold=>1);
    }
# on exit the project instance contains the list of ordered contig_ids
    return $rc;
}

#------------------------------------------------------------------------------

1;
