#!/usr/local/bin/perl

#######################################################################
# This software has been created by Genome Research Limited (GRL).    # 
# GRL hereby grants permission to use, copy, modify and distribute    # 
# this software and its documentation for non-commercial purposes     # 
# without fee at the user's own risk on the basis set out below.      #
# GRL neither undertakes nor accepts any duty whether contractual or  # 
# otherwise in connection with the software, its use or the use of    # 
# any derivative, and makes no representations or warranties, express #
# or implied, concerning the software, its suitability, fitness for   #
# a particular purpose or non-infringement.                           #
# In no event shall the authors of the software or GRL be responsible # 
# or liable for any loss or damage whatsoever arising in any way      # 
# directly or indirectly out of the use of this software or its       # 
# derivatives, even if advised of the possibility of such damage.     #
# Our software can be freely distributed under the conditions set out # 
# above, and must contain this copyright notice.                      #
#######################################################################

#----------------------------------------------------------------------
# Author:   David Harper
# Email:    adh@sanger.ac.uk
# WWW:      http://www.sanger.ac.uk/Users/adh/
# Modified: Ed Zuiderwijk - added method getDefaultAssemblyCafFile
#                         - added undefined protection in dirs hash
#----------------------------------------------------------------------

package PathogenRepository;

use WrapDBI;
use Carp;
use strict;

sub new {
    my $type = shift;
    my $this = {};

    my %dirs;

    my $root = "/nfs/disk222";

    if (opendir(DIR, $root)) {
	while (my $dir = readdir(DIR)) {
	    next unless (-d "$root/$dir");
	    next unless (-e "$root/$dir/.wgs_project_info");
	    $dirs{uc($dir)} = "$root/$dir";
	}
    }

    closedir(DIR);

    my $dbh = WrapDBI->connect('reports', {RaiseError => 1, AutoCommit => 0});

    my $sth = $dbh->prepare('select projectname, online_path from project p, online_data od
			     where  p.project_type = 5
			     and    od.id_online = p.id_online');

    $sth->execute();

    while (my $row = $sth->fetchrow_arrayref()) {
	my ($name, $path, $junk) = @{$row};
	next unless (-d "$path/assembly");
	my $d = $path;
	my $p = $d;
	$d =~ s#(.*)/[^/]*$#$1#;
	$p =~ s#.*/##;
	$dirs{uc($name)} = $path;
    }

    $sth->finish();

    $dbh->disconnect;

    my $name;

    foreach $name (keys %dirs) {
	$root = $dirs{$name} . "/assembly";
	next if (-e "$root/Analysis");
    
	if (opendir(DIR, $root)) {
	    while (my $dir = readdir(DIR)) {
		next unless (-e "$root/$dir/Analysis");
		$dirs{uc($dir)} = "$root/$dir" unless defined($dirs{uc($dir)});
	    }
	    undef $dirs{$name};
	}
    }

    my %asmdir;
    my %splitdir;

    foreach $name (keys %dirs) {

	$root = $dirs{$name} || ''; # protect against undefined

	next unless length($root) > 0;

	if ($root =~ /assembly/) {
	    $asmdir{$name} = $root;
	    $root =~ s/assembly/split/;
	    $splitdir{$name} = $root;
	} else {
	    $asmdir{$name} = $root . '/assembly';
	    $splitdir{$name} = $root . '/split';
	}
    }

    # Nasty explicit hack for PYO/PYR
    $asmdir{'PYO'} = $asmdir{'PYR'};
    $splitdir{'PYO'} = $splitdir{'PYR'};

    # Nasty explicit hack for MAL[678]
    $asmdir{'MAL6'} = $asmdir{'BLOB'};
    $splitdir{'MAL6'} = $splitdir{'BLOB'};
    $asmdir{'MAL7'} = $asmdir{'BLOB'};
    $splitdir{'MAL7'} = $splitdir{'BLOB'};
    $asmdir{'MAL8'} = $asmdir{'BLOB'};
    $splitdir{'MAL8'} = $splitdir{'BLOB'};

    $this->{AssemblyMap} = \%asmdir;
    $this->{SplitMap} = \%splitdir;

    return bless $this, $type;
}

sub getAssemblyDirectory {
    my $this = shift;

    confess "Invalid PathogenRepository object"
	unless ref($this) && ref($this) eq 'PathogenRepository';

    my $name = shift;

    confess "getAssemblyDirectory requires an argument" unless defined($name);

    my $asmdir = $this->{AssemblyMap};
    return $asmdir->{uc($name)};
}

sub getDefaultAssemblyCafFile {
    my $this = shift;
    my $name = shift;

    $name = &nameMap($name);

    my $AD = $this->getAssemblyDirectory($name);

    return $AD."/$name.0.caf";
}

sub getSplitDirectory {
    my $this = shift;

    confess "Invalid PathogenRepository object"
	unless ref($this) && ref($this) eq 'PathogenRepository';

    my $name = shift;

    confess "getSplitDirectory requires an argument" unless defined($name);

    my $asmdir = $this->{SplitMap};
    return $asmdir->{uc($name)};
}

sub getOrganismList {
    my $this = shift;

    confess "Invalid PathogenRepository object"
	unless ref($this) && ref($this) eq 'PathogenRepository';

    keys %{$this->{SplitMap}};
}

sub nameMap {
# translate Arturus name to Oracle name
    my $name = shift;

    $name =~ s /SCH/SH/; # fix for SCHISTO

    return $name;
}

1;




