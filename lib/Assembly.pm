package Assembly;

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
 
#-------------------------------------------------------------------
# Constructor new
#------------------------------------------------------------------- 
 
sub new {
    my $class = shift;
    my $identifier = shift; # optional
 
    my $this = {};
 
    bless $this, $class;
 
    $this->setAssemblyName($identifier) if $identifier;
 
    return $this;
}

#-------------------------------------------------------------------
# database handle (export from Arcturus) and delayed loading
#-------------------------------------------------------------------

sub setArcturusDatabase {
    my $this = shift;
    my $ADB  = shift;

    if (ref($ADB) eq 'ArcturusDatabase') {
        $this->{ADB} = $ADB;
    }
    else {
        die "Invalid object passed: $ADB";
    }
}

#-------------------------------------------------------------------    
# importing & exporting meta data
#-------------------------------------------------------------------    
  
sub setAssemblyID {
    my $this = shift;
    $this->{assembly_id} = shift;
}
  
sub getAssemblyID {
    my $this = shift;
    return $this->{assembly_id};
}
  
sub setAssemblyName {
    my $this = shift;
    $this->{data}->{assemblyname} = shift;
}
  
sub getAssemblyName {
    my $this = shift;
    return $this->{data}->{assemblyname} || '';
}
  
sub setChromosome {
    my $this = shift;
    $this->{data}->{chromosome} = shift;
}
  
sub getChromosome {
    my $this = shift;
    return $this->{data}->{chromosome};
}
 
sub setComment {
    my $this = shift;
    $this->{data}->{comment} = shift;
}
  
sub getComment {
    my $this = shift;
    return $this->{data}->{comment};
}
  
sub setCreated {
    my $this = shift;
    $this->{data}->{created} = shift;
}
  
sub getCreated {
    my $this = shift;
    return $this->{data}->{created};
}
  
sub setCreator {
    my $this = shift;
    $this->{data}->{creator} = shift;
}
  
sub getCreator {
    my $this = shift;
    return $this->{data}->{creator};
}

sub setProgressStatus {
    my $this = shift;
    $this->{data}->{progress} = shift;
}
  
sub getProgressStatus {
    my $this = shift;
    return $this->{data}->{progress};
}
  
sub setUpdated {
    my $this = shift;
    $this->{data}->{updated} = shift;
}
  
sub getUpdated {
    my $this = shift;
    return $this->{data}->{updated};
}

#-------------------------------------------------------------------    
# projects of this assembly
#-------------------------------------------------------------------    

sub addProjectID {
# import a project ID
    my $this = shift;
    my $projectid = shift; # specify undef to reset

    undef $this->{projectIDs} unless defined $projectid;

    $this->{projectIDs} = [] unless defined $this->{projectIDs};

    push @{$this->{projectIDs}}, $projectid if defined $projectid;
}

sub getProjectIDs {
# export reference to the project IDs array as is
    my $this = shift;

    $this->{projectIDs} = [] unless defined $this->{projectIDs};

    return $this->{projectIDs}; # always return array reference
}

sub getNumberOfProjects {
    my $this = shift;

    $this->fetchProjectIDs() unless shift; 

    return scalar($this->getProjectIDs());
}

sub fetchProjectIDs {
# get IDs from database, export reference to the project IDs array
    my $this = shift;
    my $nolockcheck = shift || 0; # set true to return only unlocked data

# get the project IDs for this assembly always by reference to the database

    my $ADB = $this->{ADB} || return (0,"Missing database connection");

    my $aid = $this->getAssemblyID();

    my $pids = $ADB->getProjectIDsForAssembyID($aid,lock=>$nolockcheck);

    $this->addProjectID(); # reset list

    while ($pids && @$pids) {
        $this->addProjectID(shift @$pids);
    }

    return $pids;
}
 
#-------------------------------------------------------------------

sub getProjects {
# returns a list of Project instances for this assembly
    my $this = shift;

    my $projectids = $this->fetchProjectIDs();

    my @projects;
    foreach my $projectid (@$projectids) {

        my ($project,$message) = $this->getProject(project_id => $projectid); 
 
        push @projects,@$project if ($project && @$project);
    }

    return [@projects];
}
 
#-------------------------------------------------------------------
 
1;




