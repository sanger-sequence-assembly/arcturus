#/* Last edited: Dec 05 09:32 1998 (as1) */
#
# OOP verison of Repository
# Author: Andrew Smith
#
#  $Id: OORepository.pm 36256 2013-07-09 08:55:12Z rmd $
#
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
package OORepository;

use 	strict;
use	Carp;
use 	WrapDBI;

($OORepository::VERSION) = '$Revision: 36256 $ ' =~ /\$Revision:\s+([^\s]+)/;

#
# The maximum number of projects allowed on a partition;
#
my $MAX_PROJECTS = 30;
my $INSERTSIZE_BYTESUSED_FACTOR;
my $DEFAULT_PROJECT_SIZE;
my $DEFAULT_CANCER_PROJECT_SIZE;
my $PMOVE_SVR_PORT;

BEGIN{
    $INSERTSIZE_BYTESUSED_FACTOR =      5000;
    $DEFAULT_PROJECT_SIZE        = 200000000;
    $DEFAULT_CANCER_PROJECT_SIZE = 128 * 1024 * 1024;
    $PMOVE_SVR_PORT = $ENV{TEST_PMOVE_SVR_PORT} || 9317;
}

=pod

=head1 NAME

	OORepository.pm - Object Orientated interface to Data Repository

=head1 SYNOPSIS

	use OORepository;

	eval {

		my $repos = new OORepository;
		$repos->some_method();
	};
	if ($@) {
		# Handle error
	}

=over 4

=back

=head1 METHODS

=head2 new:

	Create a new Repository Object
	Connect to the oracle database using WrapDBI.
	Create the object and reads the dictionary tables that
	are relevent to the repository

	archivestatusdict
	onlinestatusdict
	mediatypedict
	repositorytypedict
	projectstatusdict
	projectownerdict

	see method get_dict_values();

=cut

sub new {
	my ($type) = shift;
	my $self = {
	    mount_servers => {},
	};
	$self->{DB} = WrapDBI->connect('repos', {RaiseError => 1, AutoCommit => 0});
	bless  $self, $type;
	$self->get_dict_values();
	return $self;
}

=head2  DESTROY:

	Auto called when the object is destroyed. 
	Releases the database handle.

=cut

sub DESTROY {
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);
	$self->{DB}->disconnect();
	return;
}

=head2 commit

Commit changes to the database

=cut

sub commit {
    my ($self) = @_;

    $self->{DB}->commit();
}

=head2 find_ssh

Finds a suitable OpenSSH binary on this machine.

Returns a list of (path_to_ssh, '-q', '-X')

=cut

{
    my @SSH;
    sub find_ssh {
	if (@SSH) { return @SSH; }
	
	foreach my $path (qw(/usr/apps/bin/ssh /usr/bin/ssh)) {
	    if (-e $path) {
		# Make sure we have the right ssh
		
		my $output = `$path -V 2>&1`;
		if ($output =~ /^OpenSSH/) {
		    @SSH = ($path, '-q', '-X');
		    return @SSH;
		}
	    }
	}
	
	die "OORepository.pm: Couldn't find a suitable ssh on this platform.\n";
    }
}

=head2 update_requesting_account

	updates the archived_data record with the person requesting a restore.

	$self->update_requesting_account($id_archive, $account);

=cut


sub update_requesting_account {

	my ($self, $id_archive, $account) = @_;
	confess "Wrong object type\n" unless ref($self);
	$self->update_archived_data($id_archive, { requesting_account => $account } );
	return;
}

=head2 remove_partition:

	Removes a partition record from disk_partition table identified by id_partition;
	$self->remove_partition( $id_parititon );

=cut 

sub remove_partition {
	my ($self, $id) = @_;
	confess "Wrong object type\n" unless ref($self);
	return $self->{DB}->do("delete from disk_partition where id_partition = $id");
}

=head2 return_online_path_from_id:

	Returns the online_path when passed an id_online
	$self->return_online_path_from_id($id_online);

=cut

sub return_online_path_from_id {
    my ($self, $id) = @_;
    confess "Wrong object type\n" unless ref($self);
    my $sql = q[select online_path 
		from   online_data 
		where  id_online = ?];
    my ($online_path) = $self->{DB}->selectrow_array($sql, {}, $id);
    
    return $online_path;
}

=head2 return_projects_on_partition:

	Returns an array_ref of array_refs of all projects on a partition
	when passed an id_partition;

	$self->return_projects_on_partition( $id_partition );

=cut

sub return_projects_on_partition {
    my ($self, $id) = @_;
    confess "Wrong object type\n" unless ref($self);

    my $sql = qq[select projectname
		 from project p, disk_partition dp, online_data od
		 where p.id_online     = od.id_online
		 and   dp.id_partition = od.id_partition
		 and   dp.id_partition = ?];

    return $self->{DB}->selectall_arrayref($sql, {}, $id);
}

#
# when project is about to be restored, the stubb must be moved to a partition 
# where there is enough room for the project to be restored;
#

=head2 get_restorable_path:

	Returns a partition available for project restoration after archiving 
	moves the stubb directory to the newly assigned partition.

	Takes IO mode of new partition and repository type id available via dict
	repositorytypedict.

	repository types are: 

	General
	Worm 
	Human
	Pathogen

	$self->get_restorable_path( $rw, $id )

=cut

sub get_restorable_path {
	
	my($self, $rw, $id) = @_;


	

	#my $type = $self->return_repository_type_from_id($id);
	my $type = 4; #"General";

    if ($rw){
        $self->assign_partition({ 'mode' => 'rw',
                                'type' => $type,
                                'minsize' => $self->{archived_data}->{$id}->{size_bytes}
                            });
		if( ! defined $self->{assigned_partition}->[4] ) { return undef; }
		my $to = join("/",$self->{assigned_partition}->[4],$self->{archived_data}->{$id}->{projectname});
		my $from = $self->return_online_path_from_id( $self->return_id_online_from_id_archive($id));

		if( $to ne $from ){
			$self->move_stubb($from, $self->{assigned_partition}->[4] );
		}
        $self->update_online_data($self->return_id_online($self->{archived_data}->{$id}->{projectname}),
                                {
                                    'online_path' => $self->{assigned_partition}->[4] .
									"/$self->{archived_data}->{$id}->{projectname}",
                                    'id_partition' => $self->return_id_partition($self->{assigned_partition}->[4]),
                                    'size_est_bytes' => $self->{archived_data}->{$id}->{size_bytes}
                                });
        return $self->{assigned_partition}->[4];

    }else{ #ro
        $self->assign_partition({ 'mode' => 'ro',
                                'type' => $type,
                                'minsize' => $self->{archived_data}->{$id}->{size_bytes}
                            });
		if( ! defined $self->{assigned_partition}->[4] ) { 
			return undef; 
		}
		my $to = join("/",$self->{assigned_partition}->[4],$self->{archived_data}->{$id}->{projectname});
		my $from = $self->return_online_path_from_id( $self->return_id_online_from_id_archive($id));
		if( $to ne $from ){
			$self->move_stubb($from, $self->{assigned_partition}->[4]);
		}
        $self->update_online_data($self->return_id_online($self->{archived_data}->{$id}->{projectname}),
                                {
                                    'online_path' => $self->{assigned_partition}->[4] .
									"/$self->{archived_data}->{$id}->{projectname}",
                                    'id_partition' => $self->return_id_partition($self->{assigned_partition}->[4]),
                                    'size_est_bytes' => $self->{archived_data}->{$id}->{size_bytes}
                                }
                                );
        return $self->{assigned_partition}->[4];
    }
}


=head2 return_project_from_id_archive

	returns a projectname from when given an id_archive;

=cut

sub return_project_from_id_archive {
	
	my ($self, $id_archive ) = @_;

	my @projectname = $self->{DB}->fetch_row("select projectname from archived_data where id_archive = $id_archive");

	return $projectname[0];

}

=head2 return_id_online_from_id_archive 
	
	returns the id_online from the id_archive or undef if no id_online

=cut

sub return_id_online_from_id_archive {

	my ($self, $id_archive ) = @_;

	my $id_online = $self->{DB}->fetch_scalar("select 
												project.id_online 
											from 
												archived_data, project 
											where 
												archived_data.id_archive = $id_archive
											and 
												archived_data.projectname = project.projectname
										");	

	defined $id_online ? return $id_online : return undef;
}	

=head2 create_online_path_entry

	Creates an entry in online_data table.

	Takes a hash_ref:

	$hash_ref->{user}
	$hash_ref->{path}
	$hash_ref->{project}

	$self->create_online_path_entry($hash_ref);

	NB. This methos autocommits;

=cut

sub create_online_path_entry {
	my ($self, $hash_ref) = @_;

	my @login = getpwnam($hash_ref->{user});	

	my $uid = $login[2];
	my $gid = $login[3];
	my $name = $login[0];
	my $id = $self->return_id_partition($hash_ref->{path});

	$self->{DB}->do("insert into
                            online_data (id_online, is_available, online_uid, online_gid,
                                         online_path, id_partition, online_date, requesting_account )
                        values
                            ( seq_online.nextval, 1, $uid, $gid, '$hash_ref->{path}/$hash_ref->{project}', $id, sysdate, '$name')
                ");
    $self->{DB}->do("insert into
                        online_status ( id_online, status, statusdate, iscurrent )
                    values
                        ( seq_online.currval, $self->{onlinestatusdict}->{'Online - physically on disk'}, sysdate, 1 )
                    ");

	$self->{DB}->do("update project set id_online = seq_online.currval where projectname = '$hash_ref->{project}'");
	my $id_online = $self->{DB}->fetch_scalar("select seq_online.currval from dual"); 
	$self->{DB}->commit();
	return $id_online if defined $id_online;
}

=head2 get_online_path_from_project:

	Fills $self->{online_path} with the 
	online_path of the projectname that was
	passed to this method.

	$self->get_online_path_from_project($projectname);
	print STDOUT $self->{online_path};

=cut

sub get_online_path_from_project {
    my ($self, $project) = @_;
    confess "Wrong object type\n" unless ref($self);

    my $db = $self->{DB};
    my ($path) = $db->selectrow_array(qq[select od.online_path
					 from   online_data od, project p
					 where  p.id_online = od.id_online
					 and    p.projectname = ?],
				      {}, $project);

    $self->{online_path} = $path;
    return $path;
}

#
# Return an array_ref of array_refs listing all online data in the system;
#
=head2 return_online_data:

	Returns an array_ref of array_refs containing the entire
	contents of the online_data table:

	my $entire_online_data_table = $self->return_online_data();

=cut

sub return_online_data {
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);
	return($self->{DB}->fetch_all("select * from online_data"));
}

=head2 update_online_data_size:

	Updates the size_est_bytes column of online_data
	when passwd a hash_ref:

	my $hash_ref->{$online_path} = $size;

	$self->update_online_data_size( $hash_ref );

=cut

sub update_online_data_size {
    my ($self, $hash_ref) = @_;
    confess "Wrong object type\n" unless ref($self);
    
    my $dbh = $self->{DB};
    my $update_size
	= $dbh->prepare(qq[update online_data 
			   set    size_est_bytes = ?, last_inspected = sysdate
			   where  online_path    = ?]);

    while(my ($path, $size) = each(%{$hash_ref})) {
	
	$update_size->execute($size, $path);
    }
    $update_size->finish();
    return;
}

#
# Returns the contents of the project table;
#
=head2 read_project_table:

	Fills the object with the contents of the project table.

	$self->read_project_table();

	if ( defined $self->{projects}->{$projectname} ){
		then do something;
	}

=cut

sub read_project_table {
	my ( $self) = shift;
	my ( $row, $rows);
	confess "Wrong object type\n" unless ref($self);

	$rows = $self->{DB}->fetch_all("select projectname from project");

	foreach $row (@{$rows} ){
		$self->{projects}->{$row->[0]} = 1;
	}
	return;
}

=head2 read_disk_partition_table:

	Fills the object with the contents of the disk_parition table.


	ID_PARTITION                    NOT NULL NUMBER(38)
	REPOSITORY_TYPE                 NOT NULL NUMBER(1)
	PARTITION_PATH                  NOT NULL VARCHAR2(240)
	MAX_SIZE_BYTES                  NOT NULL NUMBER(38)
	IS_READONLY                     NOT NULL NUMBER(1)
	IS_ACTIVE                       NOT NULL NUMBER(1)


	data can be accessed by:

	$self->{disk_partition}->{$id_partition}->{id};
	$self->{disk_partition}->{$id_partition}->{type};
	$self->{disk_partition}->{$id_partition}->{path};
	$self->{disk_partition}->{$id_partition}->{max_size};
	$self->{disk_partition}->{$id_partition}->{mode};
	$self->{disk_partition}->{$id_partition}->{active};

=cut

sub read_disk_partition_table {
    my ($self) = shift;
    confess "Wrong object type\n" unless ref($self);
    
    my $get_partitions
	= $self->{DB}->prepare(qq[select ID_PARTITION, REPOSITORY_TYPE,
				         PARTITION_PATH, MAX_SIZE_BYTES,
				         IS_READONLY, IS_ACTIVE, FREE_BYTES
				  from disk_partition]);

    $get_partitions->execute();

    while (my ($id, $type, $path, $maxsz, $ro, $active, $free)
	   = $get_partitions->fetchrow_array()) {
	
	my $mode = ($ro == 0 ? "rw" : "ro");
	
	push(@{$self->{partitions}}, {'ID'       => $id,
				      'TYPE'     => $type,
				      'PATH'     => $path,
				      'MAX_SIZE' => $maxsz,
				      'MODE'     => $mode,
				      'ACTIVE'   => $active,
				      'FREE'     => $free
				      });

	# should be like this really, left old stuff to support older code

	$self->{disk_partition}->{$id} = {
	    id       => $id,
	    type     => $type,
	    path     => $path,
	    max_size => $maxsz,
	    mode     => $mode,
	    active   => $active,
	    free     => $free
	};
    }

    $get_partitions->finish();

    return;
}

=head2 return_id_partion_from_path:

	Note the typo: I'll fix this someday!

	Returns the id_partition from a partition_path;

=cut

sub return_id_partion_from_path {
    my ($self, $path) = @_;

    my $sql = qq[select id_partition
		 from disk_partition
		 where partition_path like ?];

    my ($id_partition) = $self->{DB}->selectrow_array($sql, {}, $path);

    return $id_partition;
}

=head2 partition_exists:

	Returns true if a partition exists;

	$self->partition_exists( $type,$path,$size,$mode);

NB: This function is pretty useless.  You want partition_path_exists instead.

=cut

sub partition_exists {
	my ($self, $type, $path, $size, $mode) = @_;

	$self->read_disk_partition_table();

	foreach (@{$self->{partitions}}){
		if ( ( $_->{'TYPE'} eq $type )
		and  ( $_->{'PATH'} eq $path )
		and  ( $_->{'MAX_SIZE'} == $size )
		and  ( $_->{'MODE'} == $mode)) {
			return 1;
		}
	}
	return 0;
}

=head2 partition_path_exists:

Returns true if a partition exists with the path given.

$self->partition_path_exists($path);

=cut

sub partition_path_exists {
    my ($self, $path) = @_;

    my $sql = qq[select count(*) from disk_partition
		 where partition_path = ?];

    my ($count) = $self->{DB}->selectrow_array($sql, {}, $path);

    return $count;
}

=head2 project_exists:

	Returns true if a project exists.

	$self->project_exists($projectname);

=cut

sub project_exists {
	my ($self, $project) = @_;
	confess("Wrong type\n") unless ref($self);

	my $sql = qq[select projectname from project where projectname = ?];

	my @row = $self->{DB}->selectrow_array($sql, {}, $project);

	if( defined $row[0] ){
	    return 1;
	}else{
	    return 0;
	}
}

=head2 return_repos_id

	Returns the repository_type_id when given a general repository type description.

	$return_repos_id("General");

=cut

sub return_repos_id {
    my ($self, $type) = @_;
    
    my ($id) = $self->{DB}->selectrow_array(qq[select id_dict
					       from repositorytypedict
					       where description = ?],
					    {}, $type);
    return $id;
}

#
# Adds a partition to the database after checking to see if it exists;
#

=head2 add_partition

	Adds a partition to the database.
	Checks to see if it already exists and then inserts.
	The partition is not added in an active mode.
	This must be done using the make_id_partition_active method.

	$self->add_partition($type,$path,$size,$mode);

=cut

sub add_partition {
    # adding a partition to the database;
    my ($self,$type,$path,$size,$mode) = @_;
    confess "Wrong object type\n" unless ref($self);
    
    #my $repos_id = $self->return_repos_id($type);
    
    my $repos_id = $self->{repositorytypedict}->{$type};
    
    if($mode eq 'rw'){
	$mode = 0;
    }else{
	$mode = 1;
    }
    
    if ( $self->partition_path_exists($path)) {
	die "The partition you specified already exists in the database\n\n";
	return;
    }

    # N O T E: Paritions are added not active (padd) can activate via the
    # make active method);
    # Add the partition;
    $self->{DB}->do(qq[insert into 
		       disk_partition (id_partition, repository_type,
				       partition_path, max_size_bytes,
				       is_readonly, is_active, free_bytes) 
		       values 
		       (seq_partition.nextval, ?, ?, ?, ?, 0, ?)],
		    {}, $repos_id, $path, $size, $mode, $size);
    return;
}

#
# Alter partition
#

=head2 alter_partition

Changes settings for a partition in the disk_partition table.

    $repos->alter_partition($id_partition, $setting, $value);

Valid settings are:

=over 4

=item path

Set a new partition_path.

=item type

Change the repository type.

=item size

Change the recorded size of the partition

=back

returns number of rows altered

=cut

sub alter_partition {
    my ($self, $id_partition, $setting, $value) = @_;

    my $to_alter = {
	path => 'partition_path',
	type => 'repository_type',
	size => 'max_size_bytes',
    }->{$setting};

    unless (defined($to_alter)) {
	croak("OORepository::alter_partition: '$setting' is not a valid setting to change");
    }

    my $sql = qq[update disk_partition set $to_alter = ?
		 where  id_partition = ?];

    return $self->{DB}->do($sql, {}, $value, $id_partition);
}

=head2 get_repos_type_translations

Returns a hash reference which gives some abbreviations for certain repository
types.  This is useful for typing in some of the longer ones on the command
line.

    my $translate = $repos->get_repos_type_translations();

=cut

sub get_repos_type_translations {
    my ($self) = @_;

    return {
	'WGS-path'      => "Pathogen - whole genome shotgun",
	'Pathogen'      => "Pathogen - clone by clone",
	'WGS-mouse'     => "Mouse - whole genome shotgun",
	'WGS-zfish'     => "Zebrafish - whole genome shotgun",
	'WGS-gen'       => "General - whole genome shotgun",
	'path-analysis' => "Pathogen - analysis",
	'SNP'           => "SNP - whole genome shotgun",
    };
}

#
# Make active from id;
#

=head2 make_id_partition_active:

	Make a partition active!
	when passed the id_partition.

	$self->make_id_partition_active($id_partition);

=cut

sub make_id_partition_active {
	my ($self, $id ) = @_;

	$self->{DB}->do("
					update 
						disk_partition 
					set
						is_active = 1 
					where 
						id_partition = $id
					
					");
	return;
}

#
# Return team from a persons login;
#

=head2 return_team_from_person:

	Returns the team a person belongs to.

	$self->return_team_from_person("as1");

=cut

sub return_team_from_person {
    my ($self, $person) = @_;
    confess "Wrong object type\n" unless ref($self);

    if( $person =~ /^team(\d+\d+)$/ ){
	return $1;
    }
    my $dbh = $self->{DB};
    my ($team) = $dbh->selectrow_array(qq[select tp.teamname 
					  from   team_person tp, person p
					  where  p.email = ?
					  and    tp.id_person = p.id_person],
				       {}, $person);
    
    return $team;
}

#
# Create a new project;
#

=head2 new_project:

 Adds a complete project record to the database.
    
 online_data, project, project_owner, online_status.
    
 NB. Auto commits.
    
 $self->new_project($repository_type, $projectname, $size, $path);

 if size is undef a default of 3Gb is used.

 The Owner of the project is inferred from the effective user id.
 A online_status of library testing is created and the least loaded
 partition of that repository type is selected for the project to 
 live.
      
 if $repository_type is 0, new_project will try to choose one based on
 the project_type in the project table.  If that doesn't work, it will
 choose a 'General' partition instead.

=cut

sub new_project {
    # Add a new project to the repository;
    my ($self, $repository, $projectname, $size, $path) = @_;
    my( $id, $team_number);

    confess "Wrong object type\n" unless ref($self);
    confess "Project Name not defined\n" unless( $projectname );

   unless($size){
	$size = ($self->return_predicted_size($projectname)
		 || $DEFAULT_PROJECT_SIZE);
   }

    my $op = $self->return_online_path_from_project($projectname);
    if ($op) {
	print STDERR "Project $projectname is already in the repository at $op\nWhy are you running new_project on it?\n";
	return;
    }

    if( !defined $path) {

	my @repos_to_try;
	if ($repository) {
	    # We were passed a repository type to use, so use it.

	    @repos_to_try = ($repository);
	} else {
	    # We need to work out the repository type ourselves.
	    # If the project_type is defined in the project table, try it first
	    # else try for a general partition.

	    my $proj_type = $self->get_project_type($projectname);
	    my $general = $self->return_repos_id("General");
	    if ($proj_type) {
		push(@repos_to_try, $proj_type);
	    }
	    if ($general && $proj_type != $general) { 
		push(@repos_to_try, $general);
	    }
	}

	$self->{assigned_partition} = undef; # so we know if nothing was found

	$self->assign_partition2({'mode'    => 'rw',
				  'type'    => \@repos_to_try,
				  'minsize' => $size});
	
	# Check to see if it worked.
	if (defined($self->{assigned_partition})) {
	    $repository = $self->{assigned_partition}->[1];
	} else {
	    die "Couldn't find anywhere to put project $projectname in the repository\n";
	}

	$id = $self->{assigned_partition}->[5];
	$path = $self->{assigned_partition}->[4];
    }else{
	$id = $self->return_id_partition($path);
    }

    # die "id = $id path = $path repository = $repository\n";

    my ($name, $passwd, $uid, $gid) = getpwuid($<);
    
    #
    # root can restore projects but isn't in a team 
    # so give the project team43's number, they are 
    # the library testing group, projects always start
    # as them.
    #
    
    if( $name eq 'root' ){
	$team_number = 43;
    }else{
	$team_number = $self->return_team_from_person($name); 
    }

    my $directory = "$path/$projectname";
    my $dbh = $self->{DB};

    if( defined $size){
	
	$dbh->do(qq[insert into online_data (id_online, is_available,
					     online_uid, online_gid, 
					     online_path, id_partition,
					     online_date, requesting_account,
					     size_est_bytes)
		    values (seq_online.nextval, 1, ?, ?, ?, ?, sysdate, ?, ?)],
		 {}, $uid, $gid, $directory, $id, $name, $size);
    }else{
	# use the database default values currently (1Gb);
	$dbh->do(qq[insert into online_data (id_online, is_available,
					     online_uid, online_gid, 
					     online_path, id_partition,
					     online_date, requesting_account)
		    values (seq_online.nextval, 1, ?, ?, ?, ?, sysdate, ?)],
		 {}, $uid, $gid, $directory, $id, $name);
    }
    
    $dbh->do(qq[insert into online_status (id_online, status, statusdate,
					   iscurrent)
		values (seq_online.currval, ?, sysdate, 1)],
	     {}, $self->{onlinestatusdict}->{'Online - physically on disk'});

    if (!$self->project_exists($projectname)) {
	
	$dbh->do(qq[insert into project (projectname, id_online, project_type)
		    values (?, seq_online.currval, ?)],
		 {}, $projectname, $repository);

	$dbh->do(qq[insert into project_owner (projectname, teamname,
					       owned_from, owner_type)
		    values (?, ?, sysdate, ?)],
		 {}, $projectname, $team_number,
		 $self->{projectownerdict}->{'Test'});

    }else{
	$dbh->do(qq[update project
		    set id_online = seq_online.currval
		    where projectname = ?],
		 {}, $projectname);
    }
 
    if (! -d $directory ){
	require RPC::PlClient;
	my $client = RPC::PlClient->new(peeraddr    => 'repossrv',
					peerport    => $PMOVE_SVR_PORT,
					application => 'PMoveServer',
					version     => '1.0');
	eval {
	    $client->Call('make_dir', $directory, $0);
	};
	if ($@) {
	    my $msg = $@;
	    $self->{DB}->rollback();
	    die $msg;
	}
    }

    #update projects incase it has already been read from the db.
    $self->{projects}->{$projectname} = 1;
    # commit incase the db is re-read during processing
    #   - most likely in asp etc..
    $self->{DB}->commit; #new project in the repository;
    
    return;
}

#
# Get project_type for a project
#
=head2 get_project_type

    Gets the project_type for a given projectname from the project table

=cut


sub get_project_type {
    my ($self, $project) = @_;

    my ($type) = $self->{DB}->selectrow_array(qq[select project_type
						 from   project
						 where  projectname = ?],
					      {}, $project);
    return $type || 0;
}

#
# Read unix account table;
#
=head2 read_unix_account_table

	Fills the object with the contents of the unix_account table.
	ACCOUNTNAME                     NOT NULL VARCHAR2(20)
	data can be accessed by:
	$self->{logins}->{$some_login}  returns true if tested;
	foreach( values(%{$self->{logins}}) {
		something;
	}

=cut

sub read_unix_account_table {
	my ($self) = @_;
	confess "Wrong object type\n" unless ref($self);

	my $array_ref =	$self->{DB}->fetch_all("select * from unix_account");
	foreach ( @{$array_ref} ){
		$self->{logins}->{$_->[0]} = 1;	
	}
	return;
}

#
# Check to see if a user exists on the system before adding it to oracle;
#

=head2 is_valid_user:

	Checks to see if a user is present in the yellowpages.
	returns 1 if true.

=cut

sub is_valid_user {
	my ($self, $account) = @_;
	confess "Wrong object type\n" unless ref($self);
	my (%login, $name);

	while(($name) = getpwent()){
		$login{$name} = 1;
	}
	if (defined $login{$account} ){
		return 1; 
	}
    return 0;     
}

#
# Add unix account if not already in database;
#

=head2 add_unix_account:

	Adds a user to the database if the account doesn't
	already exist.

=cut	

sub add_unix_account {
	# Add a new user to the data base;
	my ($self, $account) = @_;

	confess "Wrong object type\n" unless ref($self);
	$self->read_unix_account_table();

	if( !defined $self->{logins}->{$account} ){
		$self->{DB}->do("insert into unix_account (accountname) values ('$account')");
		$self->{login}->{$account} = 1;
		return;
	}else{
		die "$account already exists in Oracle\n\n";
		return;
	}
}

#
# Get dict values;
#

=head2 get_dict_values:

	Reads dictionary tables that
	are relevent to the repository

	archivestatusdict
	onlinestatusdict
	mediatypedict
	repositorytypedict
	projectstatusdict
	projectownerdict

	eg.

	$self->{archivestatusdict}->{Restored}

	Returns 6;

=cut

sub get_dict_values {
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);
	my ($array);	
	my @dicts = ("archivestatusdict",
				 "onlinestatusdict",
				 "mediatypedict",
				 "repositorytypedict",
				 "projectstatusdict",
				 "projectownerdict"
				);
	foreach ( @dicts ){
		my $array_ref = $self->{DB}->fetch_all("select * from $_");	

		foreach $array ( @{$array_ref} ){
			$self->{$_}->{$array->[1]} = $array->[0];
			$self->{$_}->{$array->[0]} = $array->[1];

		}
	}
	return;
}

=head2 return_nearlining_requests:


	Fills $self->{nearlining_requests}
	With an array_ref of array_refs for everything
	online with a status of Nominated for nearlining

=cut

sub return_nearlining_requests {
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);

	$self->{nearlining_requests} = $self->{DB}->fetch_all("

		select 
			online_data.id_online
		from 
			online_data, online_status 
		where 
			online_status.status = $self->{onlinestatusdict}->{'Nominated for nearlining'}                             
		and 
			online_data.id_online = online_status.id_online 
		and
			online_status.iscurrent = 1
	");
	return;
} 

=head2 return_archiving_requests:

	Fills $self->{archiving_requests}
	with an array_ref of array_refs for everything 
	online with a status of Nominated for archiving

=cut

sub return_archiving_requests {
	my $self = shift;
	 confess "Wrong object type\n" unless ref($self);

	 $self->{archiving_requests} = $self->{DB}->fetch_all("

		select 
			online_data.id_online
        from
            online_data, online_status
        where
            online_status.status = $self->{onlinestatusdict}->{'Nominated for archiving'}
        and
            online_data.id_online = online_status.id_online
        and
            online_status.iscurrent = 1
	");
	return;
} 


#
# is_online_data_available;
#

=head2 is_online_data_available

	$self->is_online_data_available($id_online);

	Returns 1 if online_data is available;

=cut

sub is_online_data_available {
    my ($self, $id) = @_;

    my $sql = qq[select is_available from online_data where id_online = ?];

    my ($is_available) = $self->{DB}->selectrow_array($sql, {}, $id);
    return $is_available;
}

=head2 make_online_data_available

	$self->make_online_data_available($id_online);

	Makes online_data available;

=cut

sub make_online_data_available {
    my ($self, $id) = @_;

    $self->{DB}->do(qq[update online_data
		       set    is_available = 1
		       where id_online = ?],
		    {}, $id);

    return;
}

=head2 make_online_data_unavailable
	
	$self->make_online_data_unavailable($id_online);

	Makes online_data unavailable;

=cut

sub make_online_data_unavailable {
    my ($self, $id) = @_;
    
    $self->{DB}->do(qq[update online_data
		       set    is_available = 0
		       where id_online = ?],
		    {}, $id);

    return;
}

=head2 return_online_status_from_project

=cut

sub return_online_status_from_project {
    my ($self, $project) = @_;

    my $sql = qq[select os.status
		 from   online_status os, project p, online_data od
		 where  p.projectname = ?
		 and    p.id_online   = od.id_online
		 and    os.id_online  = od.id_online
		 and    os.iscurrent  = 1];

    my ($status) = $self->{DB}->selectrow_array($sql, {}, $project);
    return $status;
}

sub return_online_status_table_from_project {
	my ($self, $project) = @_;

	my $table = $self->{DB}->fetch_all("
                                select
                                    online_status.status, online_status.statusdate, online_status.iscurrent  
								from 
									online_status, project, online_data
                                where
                                    project.projectname = '$project'
                                and
                                    project.id_online = online_data.id_online
                                and
                                    online_status.id_online = online_data.id_online
								order by 
									online_status.statusdate
                                ");

	foreach my $table ( @{$table} ){
		defined $table->[0] ? push(@{$self->{online_status}->{$project}->{status}},$table->[0])
		: push(@{$self->{online_status}->{$project}->{status}}, "NULL" );
		defined $table->[1] ? push(@{$self->{online_status}->{$project}->{statusdate}},$table->[1])
		: push(@{$self->{online_status}->{$project}->{status}}, "NULL" );
		defined $table->[2] ? push(@{$self->{online_status}->{$project}->{iscurrent}},$table->[2])
		: push(@{$self->{online_status}->{$project}->{status}}, "NULL" );
	}
	return;
}


sub return_archive_status_table_from_project {
	my ($self, $project) = @_;

	my $table = $self->{DB}->fetch_all("
                                select
                                    archive_status.status, archive_status.statusdate, archive_status.iscurrent
								from 
									archived_data, archive_status
                                where
                                    (
									archived_data.projectname = '$project'
                                or
									archived_data.annotation like  '$project%'
									)
                                and
                                    archived_data.id_archive = archive_status.id_archive
								order by
									archive_status.statusdate
                                ");
	foreach my $table ( @{$table} ){
		defined $table->[0] ? push(@{$self->{archive_status}->{$project}->{status}},$table->[0])
		: push(@{$self->{archive_status}->{$project}->{status}}, "NULL" );
		defined $table->[1] ? push(@{$self->{archive_status}->{$project}->{statusdate}},$table->[1])
		: push(@{$self->{archive_status}->{$project}->{status}}, "NULL" );
		defined $table->[2] ? push(@{$self->{archive_status}->{$project}->{iscurrent}},$table->[2])
		: push(@{$self->{archive_status}->{$project}->{status}}, "NULL" );
	}
	return;

}	

=head2 return_archive_status_from_project

=cut

sub return_archive_status_from_project {
    my ($self, $project) = @_;

#	return $self->{DB}->fetch_scalar("
#          select
#             archive_status.status from archived_data, archive_status
#          where
#             (
#	          archived_data.projectname = '$project'
#              or
#                 archived_data.annotation like  '%$project%'
#	       )
#           and
#              archived_data.id_archive = archive_status.id_archive
#           and
#              archive_status.iscurrent = 1
#           ");

    my $lproject = "$project.\%";

    my $sql = qq[select /*+ INDEX(ast) */ ast.status
		 from archived_data ad, archive_status ast
		 where (ad.projectname      = ?
			or ad.annotation    = ?
			or ad.annotation like ?)
		 and ad.id_archive = ast.id_archive
		 and ast.iscurrent  = 1];

    my ($status) = $self->{DB}->selectrow_array($sql, {},
						$project, $project, $lproject);
    return $status;
}

=head2 is_project_nearlined 

=cut

sub is_project_nearlined {
	my ($self, $project) = @_;

	my $online_status = $self->return_online_status_from_project($project);
	my $archive_status = $self->return_archive_status_from_project($project);

	if( defined $online_status and $online_status ==  $self->{onlinestatusdict}->{"Nearlined"} ){
		if( defined $archive_status and $archive_status == $self->{archivestatusdict}->{"Archived"} ){
			return 0;	
		}elsif( defined $archive_status and $archive_status == $self->{archivestatusdict}->{"Restored"} ){
			return 1;	
		}else{
			return 0;
		}
	}
}

=head2 is_project_archived

=cut

sub is_project_archived {
	my ($self, $project) = @_;

	my $online_status = $self->return_online_status_from_project($project);
	my $archive_status = $self->return_archive_status_from_project($project);

	if( defined $online_status and $online_status ==  $self->{onlinestatusdict}->{"Nearlined"} ){
		if( defined $archive_status and $archive_status == $self->{archivestatusdict}->{"Archived"} ){
			return 1;	
		}elsif( defined $archive_status and $archive_status == $self->{archivestatusdict}->{"Restored"} ){
			return 0;	
		}else{
			return 0;
		}
	}
}

=head2 return_repository_type_from_id

	Returns the id_repository_type when passed an id_archive;

	$self->return_repository_type_from_id($archive_id);

=cut

sub return_repository_type_from_id {
	my ($self, $id) = @_;

	confess "Wrong object type\n" unless ref($self);
	return  $self->{DB}->fetch_scalar("
                                    select
                                        disk_partition.repository_type
                                    from
                                        disk_partition, archived_data
                                    where
                                        archived_data.id_archive = $id 
                                    and
                                        disk_partition.id_partition = archived_data.orig_partition
                                    ");
}

=head2 read_archive_table:

	Reads the archive table into this struct

	$self->{archived_data}->{$id_archive}->{annotation};
	$self->{archived_data}->{$id_archive}->{orig_gid};
	$self->{archived_data}->{$id_archive}->{size_bytes};
	$self->{archived_data}->{$id_archive}->{projectname};
	$self->{archived_data}->{$id_archive}->{requesting_account};
	$self->{archived_data}->{$id_archive}->{archive_text};
	$self->{archived_data}->{$id_archive}->{post_restore_script};

=cut

sub read_archive_table {
	my ($self) = shift;
	confess "Wrong object type\n" unless ref($self);
	my $archive_table = $self->{DB}->fetch_all("select * from archived_data ");

	foreach( @{$archive_table} ){
		$self->{archived_data}->{$_->[0]}->{annotation} = $_->[1];
		$self->{archived_data}->{$_->[0]}->{orig_gid} = $_->[2];
		$self->{archived_data}->{$_->[0]}->{size_bytes} = $_->[3];
		$self->{archived_data}->{$_->[0]}->{projectname} = $_->[4] if defined $_->[4]; 
		$self->{archived_data}->{$_->[0]}->{archive_text} = $_->[5] if defined $_->[5];
		$self->{archived_data}->{$_->[0]}->{requesting_account} = $_->[6] if defined $_->[6];
		$self->{archived_data}->{$_->[0]}->{post_restore_script} = $_->[7] if defined $_->[7];
	}
	return;
}


=head2 read_online_statuses:

	#
	Reads the online_status where iscurrent is set into this struct

	$self->{online_status}->{$id_online}->{status};
	$self->{online_status}->{$id_online}->{statusdate};
	$self->{online_status}->{$id_online}->{iscurrent};
	$self->{online_status}->{$id_online}->{sessionid};
	$self->{online_status}->{$id_online}->{program};
	$self->{online_status}->{$id_online}->{operator};

=cut

sub read_online_statuses {
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);
	
	my $online_statuses = $self->{DB}->fetch_all("select * from online_status where iscurrent = 1");

	foreach( @{$online_statuses} ){
		$self->{online_status}->{$_->[0]}->{status} = $_->[1];
		$self->{online_status}->{$_->[0]}->{statusdate} = $_->[2];
		if( defined $_->[3] ) {$self->{online_status}->{$_->[0]}->{iscurrent} = $_->[3];}
		if( defined $_->[4] ) {$self->{online_status}->{$_->[0]}->{sessionid} = $_->[4];}
		if( defined $_->[5] ) {$self->{online_status}->{$_->[0]}->{program} = $_->[5];}
		if( defined $_->[6] ) {$self->{online_status}->{$_->[0]}->{operator} = $_->[6];}
	}

	return;
}

=head2 read_archive_statuses

	Reads the archive_status table in this struct:

	$self->{archive_status}->{$id_archive}->{status};
	$self->{archive_status}->{$id_archive}->{statusdate};
	$self->{archive_status}->{$id_archive}->{iscurrent};
	$self->{archive_status}->{$id_archive}->{sessionid};
	$self->{archive_status}->{$id_archive}->{program};
	$self->{archive_status}->{$id_archive}->{operator};

=cut

sub read_archive_statuses {
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);
	
	my $archive_statuses = $self->{DB}->fetch_all("select * from archive_status");

	foreach( @{$archive_statuses} ){
		$self->{archive_status}->{$_->[0]}->{status} = $_->[1];
		$self->{archive_status}->{$_->[0]}->{statusdate} = $_->[2];
		if( defined $_->[3] ) {$self->{archive_status}->{$_->[0]}->{iscurrent} = $_->[3];}
		if( defined $_->[4] ) {$self->{archive_status}->{$_->[0]}->{sessionid} = $_->[4];}
		if( defined $_->[5] ) {$self->{archive_status}->{$_->[0]}->{program} = $_->[5];}
		if( defined $_->[6] ) {$self->{archive_status}->{$_->[0]}->{operator} = $_->[6];}
	}

	return;
}

=head2 move_stubb

	Moves a stubb directory
	$self->move_stubb( $from, $to );

=cut

sub move_stubb {
	my ($self, $from, $to) = @_;
	confess "Wrong object type\n" unless ref($self);
	print "Move_stubb called\n";
	if ( -d $from ){
		print "Moving stubb directory $from $to\n";
		system("/usr/bin/mv $from $to") and print STDERR "Couldn't move stubb directory: $! \n";		
	}else{
		print STDERR "No stubb directory to move\n";
	}
}

=head2 update_online_data

	Generally update online data from a hash_ref;

	my $hash_ref->{column} = $value;

	$self->update_online_data($id_online, $hash_ref);	

=cut

sub update_online_data {
	my ($self, $id, $hash_ref) = @_;
	my ($key, $value);
	while(($key,$value) = each(%{$hash_ref})){
		$self->{DB}->do("
							update 
								online_data
							set
								$key = '$value' 
							where
								online_data.id_online  = $id
						");

	}
	return;
}

=head2 return_orig_path_from_online_id 

	Returns the online_path given a id_online;

	 my $path = $self->return_orig_path_from_online_id( $id_online );

=cut

sub return_orig_path_from_online_id {
    my ($self, $id) = @_;
    confess "Wrong object type\n" unless ref($self);
    
    my $sql = qq[select online_path from online_data where id_online = ?];
    
    # my @row = $self->{DB}->fetch_row("select online_path from online_data where online_data.id_online = $id");

    my @row = $self->{DB}->selectrow_array($sql, {}, $id);
    return $row[0];
}

=head2 return_id_archive_from_id_online

	Returns the id_archive from id_online (strange that!)

	my $id_archive = $self->return_id_archive_from_id_online( $id_online );

=cut

sub return_id_archive_from_id_online {
	my($self, $id) =@_;
	confess "Wrong object type\n" unless ref($self);
	return $self->{DB}->fetch_scalar("select id_archive from online_data where id_online = $id");
}

=head2 add_archived_data

	Make an archived data record from a hash_ref and given an id_online

	my $hash_ref;

	$hash_ref->{ARCHIVE_TEXT}
	$hash_ref->{MEDIA_NAME}
	$hash_ref->{STACKER_ID}
	$hash_ref->{MEDIA_TYPE}
	$hash_ref->{ANNOTATION}
	$hash_ref->{ORIG_GID}
	$hash_ref->{SIZE_BYTES}
	$hash_ref->{ACCOUNT}


	$self->add_archived_data($id_online, $hash_ref);

=cut

#
# Archived data has table significantly changed
#

sub add_archived_data {
	
	my ($self, $id_online, $hash_ref) = @_;
	confess "Wrong object type\n" unless ref($self);
	my $archive_id;
	my $project;

	$self->add_storage_media($hash_ref);

	if( defined $id_online ){
		$archive_id = $self->return_id_archive_from_id_online($id_online);
		$project = $self->return_projectname_from_id_online($id_online);	
	}

	if( !defined $hash_ref->{ACCOUNT} ){
		$hash_ref->{ACCOUNT} = 'root';
	}

	if( !defined $hash_ref->{ARCHIVE_TEXT} ){
		$hash_ref->{ARCHIVE_TEXT} = '';
	}

	if( ! defined $archive_id ){

		if( defined $project ){
			$self->{DB}->do("
							insert into 
									archived_data (id_archive, annotation,  orig_gid,  
									size_bytes, projectname,  requesting_account, archive_text)
							values 
									(seq_archive.nextval, '$hash_ref->{ANNOTATION}', $hash_ref->{ORIG_GID}, 
									$hash_ref->{SIZE_BYTES}, '$project',  '$hash_ref->{ACCOUNT}', '$hash_ref->{ARCHIVE_TEXT}') 
							");


		}else{ # This isn't project data;
			$self->{DB}->do("
							insert into 
									archived_data (id_archive, annotation,  orig_gid,  
									size_bytes, archive_text,  requesting_account)
							values 
									(seq_archive.nextval, '$hash_ref->{ANNOTATION}', $hash_ref->{ORIG_GID}, 
									$hash_ref->{SIZE_BYTES}, '$hash_ref->{ARCHIVE_TEXT}',  '$hash_ref->{ACCOUNT}') 
							");
		}	

		$self->{DB}->do("insert into 
							archive_storage ( id_archive, media_name, media_type, side )
						values
							( seq_archive.currval, '$hash_ref->{MEDIA_NAME}',
							$hash_ref->{MEDIA_TYPE}, 0)
						");


#
# Create a archive status of Archived, status should be altered by any program modifying 
# Archive data records.
#

		$self->{DB}->do("insert into 
							archive_status ( id_archive, status, statusdate, iscurrent)
						values
							( seq_archive.currval, 7, sysdate, 1)
						");




		if( defined $id_online ){
			$self->{DB}->do("update 
								online_data 
							set 
								id_archive = seq_archive.currval 
							where 
								id_online = $id_online
							");
		}


	} else { # Do an update rather than an insert;

		if( defined $project ){

			$self->{DB}->do("update 
								archived_data 
							set 
								annotation = '$hash_ref->{ANNOTATION}',
								orig_gid = $hash_ref->{ORIG_GID},
								archive_text = '$hash_ref->{ARCHIVE_TEXT}',
								projectname = '$project',
								size_bytes =  $hash_ref->{SIZE_BYTES}
							where 
								id_archive = $archive_id");
		}else{
			$self->{DB}->do("update 
								archived_data 
							set 
								annotation = '$hash_ref->{ANNOTATION}',
								orig_gid = $hash_ref->{ORIG_GID},
								archive_text = '$hash_ref->{ARCHIVE_TEXT}',
								size_bytes =  $hash_ref->{SIZE_BYTES}
							where 
								id_archive = $archive_id");
		}	
			
		$self->{DB}->do("update 
							archive_storage 
						set  
							media_name = '$hash_ref->{MEDIA_NAME}', 
							media_type = $hash_ref->{MEDIA_TYPE}, 
							side = 0
						where
							id_archive = $archive_id");


        $self->{DB}->do("update
                           archive_status 
                        set
                            iscurrent = 0
                        where
                            iscurrent = 1
						and 
							id_archive = $archive_id
                        ");

#=begin comment
#
#		$self->{DB}->do("insert into
#                            archive_status ( id_archive, status, statusdate, iscurrent)
#                        values
#                            ( $archive_id, 7, sysdate, 1)
#                        ");
#
#=cut

		$self->{DB}->do("update 
							online_data 
						set 
							id_archive = $archive_id
						where 
							id_online = $id_online
						");


	}
}

=head2 add_storage_media

creates a storage_media record if it doesn't already exist.

$self->add_storage_media( { "MEDIA_NAME" => $media_name,
			    "MEDIA_TYPE" => $media_type,
			    "STACKER_ID" => $stacker_id } );

=cut



sub add_storage_media {
	my ($self, $hash_ref) = @_;
	confess "Wrong object type\n" unless ref($self);

	if( $self->{DB}->fetch_scalar("	select count(*) from storage_media
									where 
										media_name = '$hash_ref->{MEDIA_NAME}'
									and 
										media_type = $hash_ref->{MEDIA_TYPE} ") ){
		print STDERR "Storage media record exists\n";
		return;
	}

	$self->{DB}->do("insert into 
						storage_media (media_name, media_type, stacker_id)
					 values 
						('$hash_ref->{MEDIA_NAME}',$hash_ref->{MEDIA_TYPE},
						$hash_ref->{STACKER_ID})
					");
	return;
}



sub old_add_archived_data {
	my ($self, $id, $hash_ref, $id_partition) = @_;
	confess "Wrong object type\n" unless ref($self);
	my ($archive_id, $project, $orig_path);

	if( defined $id ){
		$archive_id = $self->return_id_archive_from_id_online($id);
		$project = $self->return_projectname_from_id_online($id);	
		$orig_path = $self->return_orig_path_from_online_id($id); 
	}else{
		if( !defined $project ){
			#try from orig_path
			if( !defined $hash_ref->{ORIG_PATH} ){
				print STDERR "ERROR: Cannot add archive data record\n"; 
				return;
			}
			$orig_path = $hash_ref->{ORIG_PATH};
			if ($hash_ref->{ORIG_PATH} =~ /^.*\/(.*)$/ ){
				$project = $1;
			}else{
				$project = "Unknown";
			}
		}
	}

	my @row = $self->{DB}->fetch_row("select 
						* 
					from 
						storage_media 
					where 
						media_name = '$hash_ref->{MEDIA_NAME}'
					and 
						media_type = $hash_ref->{MEDIA_TYPE}
					"); 

	if( ! defined $row[0] ){
		$self->{DB}->do("insert into 
							storage_media (media_name, media_type, stacker_id)
						 values 
							('$hash_ref->{MEDIA_NAME}',$hash_ref->{MEDIA_TYPE},
							$hash_ref->{STACKER_ID})
						");
	}

	#
	# If the record doesn't exist then insert rather than update;
	#
	if (! defined $archive_id){
		
		
		if( !defined $hash_ref->{ACCOUNT} ){
			$hash_ref->{ACCOUNT} = 'root';
		}

		if ( ! $id_partition ){
			if ( $orig_path =~ /(.*)\/.*$/ ){
				$id_partition = $self->return_id_partition($1);
			}else{
				die"Couldn't determine id_partition from $orig_path\n";
			}
		}

		$self->{DB}->do("
						insert into 
								archived_data (id_archive, annotation, orig_uid, orig_gid, orig_path, 
								orig_partition, size_bytes, projectname,  requesting_account)
						values 
								(seq_archive.nextval, '$hash_ref->{ANNOTATION}', $hash_ref->{ORIG_UID},
								$hash_ref->{ORIG_GID},  '$orig_path',
								$id_partition, $hash_ref->{SIZE_BYTES}, '$project',  '$hash_ref->{ACCOUNT}') 
						");

		$self->{DB}->do("insert into 
							archive_storage ( id_archive, media_name, media_type, side )
						values
							( seq_archive.currval, '$hash_ref->{MEDIA_NAME}',
							$hash_ref->{MEDIA_TYPE}, 0)
						");

		$self->{DB}->do("insert into 
							archive_status ( id_archive, status, statusdate, iscurrent)
						values
							( seq_archive.currval, 7, sysdate, 1)
						");
		$self->{DB}->do("update 
							online_data 
						set 
							id_archive = seq_archive.currval 
						where 
							id_online = $id
						");

		$self->{DB}->commit();
	}else{
		# update rather than insert;

#
# Need to update storage media and archive storage 
#


		my @online_data = $self->{DB}->fetch_row("select * from online_data where id_archive = $archive_id");

		$self->{DB}->do("update 
							archived_data 
						set 
							annotation = '$hash_ref->{ANNOTATION}',
							orig_uid = $hash_ref->{ORIG_UID},
							orig_gid = $hash_ref->{ORIG_GID},
							orig_path = '$online_data[4]',
							orig_partition = $online_data[5],
							projectname = '$project',
							size_bytes =  $hash_ref->{SIZE_BYTES}
						where 
							id_archive = $archive_id");
        $self->{DB}->do("update
                           archive_status 
                        set
                            iscurrent = 0
                        where
                            iscurrent = 1
                        ");
		$self->{DB}->do("insert into
                            archive_status ( id_archive, status, statusdate, iscurrent)
                        values
                            ( $archive_id, 7, sysdate, 1)
                        ");


	}
	return;
}

=head2 update_archived_data

	Update an archived data record from a hash given a id_archive.

	$hash_ref->{$column} = $key;

	$self->update_archive_data($id_archive, $hash_ref);

=cut

sub update_archived_data {
	my ($self, $id, $hash_ref) = @_;
	my ($key, $value);
	confess "Wrong object type\n" unless ref($self);

	while(($key, $value) = each(%{$hash_ref})){
		$self->{DB}->do("
							update
								archived_data
							set
								$key  = '$value' 
							where
								archived_data.id_archive = $id
						");
	}
	return;
}
#
# update_archive_status takes either $projectname or $archiveid or both!
#

=head2 update_archive_status

	Update the archive status record using a projectname or archive_id or both!

	$self->update_archive_status( $archive_id, $projectname, $status);

=cut


sub update_archive_status {

	my ($self, $id_archive, $project, $status) = @_;
	confess "Wrong object type\n" unless ref($self);

	if( ! defined $self->{archivestatusdict}->{$status} ){
		warn"$status is not a valid status\n";
		return 1;
	}

	if( ! defined $project && defined $id_archive){
		$project = $self->return_project_from_id_archive($id_archive);
	}elsif( !defined $id_archive && defined $project){
		$id_archive  = $self->return_id_archive($project);
	}else{
		warn"Your arguments to update_archive_status are not defined\n";
		return 1;
	}
	my $existing = $self->{DB}->fetch_scalar("select status from archive_status where id_archive = $id_archive and iscurrent = 1");

	if(defined $existing && $existing == $self->{archivestatusdict}->{$status}){
		# status is already set to this value
		return 0;
	}

	if( defined $existing ){

		$self->{DB}->do("
                            update
                                archive_status
                            set
                                iscurrent = 0
                            where
                                archive_status.id_archive = $id_archive
                            and
                                iscurrent = 1
						");
	}	


	$self->{DB}->do("
					insert into 
						archive_status ( id_archive, status, statusdate, iscurrent)
					values
						($id_archive, $self->{archivestatusdict}->{$status}, sysdate, 1)
					");

	return 0;

}

sub old_update_archive_status {
	my ($self, $id, $project, $status) = @_;
	confess "Wrong object type\n" unless ref($self);

	if( ! defined $self->{archivestatusdict}->{$status} ){
		die"$status is not a valid status\n";
	}

	if( !defined $self->{archive_status} ){	
		$self->read_archive_statuses(); 
	}

	if( !defined $project && defined $id ){
		
		#
	 	# Don't update with the same record.
		#
		if( exists $self->{archive_status}->{$id}->{status} ){
			if(  $self->{archive_status}->{$id}->{status} == $self->{archivestatusdict}->{$status} ){
				return;
			}

			$self->{DB}->do("
							update 
								archive_status 
							set 
								iscurrent = 0	
							where 
								archive_status.id_archive = $id
							and 
								iscurrent = 1
							"); 

		}
		$self->{DB}->do("
						insert into 
							archive_status ( id_archive, status, statusdate, iscurrent)
						values
							($id, $self->{archivestatusdict}->{$status}, sysdate, 1)
						");

		return;
	}
	if( !defined $id && defined $project){
		my $id = $self->return_id_archive($project);	
		if (!defined $id){
			$id = $self->{DB}->fetch_scalar("select id_archive from archived_data where annotation like '%$project%'");
			if (!defined $id){
				die "Couldn't return id_archive for $project\n";
			}
		}

		#
	 	# Don't update with the same record.
		#

		if(  exists $self->{archive_status}->{$id}->{status} ){

			if(  $self->{archive_status}->{$id}->{status} == $self->{archivestatusdict}->{$status} ){
				return;
			}


			$self->{DB}->do("
							update 
								archive_status 
							set 
								iscurrent = 0	
							where 
								archive_status.id_archive = $id
							and 
								iscurrent = 1
							"); 

		}
		$self->{DB}->do("
						insert into 
							archive_status ( id_archive, status, statusdate, iscurrent)
						values
							($id, $self->{archivestatusdict}->{$status}, sysdate, 1)
						");
		
		return;
	}
	if (defined $id && defined $project){

		$self->{DB}->do("
						update 
							archive_status 
						set 
							iscurrent = 0;	
						where 
							archive_status.id_archive = $id
						and 
							iscurrent = 1
						"); 

		$self->{DB}->do("
						insert into 
							archive_status ( id_archive, status, statusdate, iscurrent)
						values
							($id, $self->{archivestatusdict}->{$status}, sysdate, 1)
						");

		return;
	}
}

=head2 update_online_status

=cut

sub update_online_status {
	my ($self, $id, $status) = @_;

	if( ! defined $self->{onlinestatusdict}->{$status} ){
		die"$status is not a valid status\n";
	}
	if( !defined $self->{online_status} ){	
		$self->read_online_statuses(); 
	}


	#
	# We don't want to update statuses we already have that are current;
	#

	if( defined $self->{online_status}->{$id}->{status} ){

		if(  $self->{online_status}->{$id}->{status} == $self->{onlinestatusdict}->{$status} ){
			return;
		}

		$self->{DB}->do("
						update
							online_status
						set
							iscurrent = 0
						where
							online_status.id_online = $id
						and
							iscurrent = 1
						");

	}
	$self->{DB}->do("
					insert into 
						online_status (id_online, status, statusdate, iscurrent)
					values
						( $id, $self->{onlinestatusdict}->{$status}, sysdate, 1)
					");
	return;
}

#
#
#

=head2 update_project_status

	No Documentation as yet.

=cut


sub update_project_status {
    my ($self, $project, $status) = @_;
    confess "Wrong object type\n" unless ref($self);
    
    if( ! defined $self->{projectstatusdict}->{$status} ){
	die"$status is not a valid status\n";
    }
    
    $self->{DB}->do(q[update project_status
		      set    iscurrent = 0
		      where  projectname = ?
		      and    iscurrent = 1], {}, $project);
    
    
    $self->{DB}->do(q[insert into project_status (projectname, status,
						  statusdate, iscurrent)
		      values (?, ?, sysdate, 1)],
		    {}, $project, $self->{projectstatusdict}->{$status});
    return;
}

#
# Returns an array of hashes containing the restore requests;
#

=head2 get_restore_requests: 

	No Documentation as yet.

=cut

sub get_restore_requests{
	my $self = shift;
	confess "Wrong object type\n" unless ref($self);

	$self->{restore_requests_rw} = $self->{DB}->fetch_all("
		select 
			id_archive 
		from 
			archive_status 
		where 
			status = $self->{archivestatusdict}->{'Restore Requested (Read/Write)'} 
		and 
			iscurrent = 1
	");
			
	$self->{restore_requests_ro} = $self->{DB}->fetch_all(" select 
			id_archive
		from
			archive_status
		where
			status = $self->{archivestatusdict}->{'Restore Requested (Read Only)'}
		and 
			iscurrent = 1
	");
	return;
}


sub return_online_path_from_project {

    my ($self, $project) =  @_;

    my $dbh = $self->{DB};

    my ($path) = $dbh->selectrow_array(qq[select od.online_path
					  from   online_data od, project p
					  where  p.projectname = ?
					  and    od.id_online = p.id_online
					  and    od.is_available = 1],
				       {}, $project);
    
    return $path;
}

=head2 check_out

Check out a project.  This makes a link in the specified user's home directory
and records the fact that the link was made in the project_link table.
If $user is undef, the account of the user running the script is used instead.

NB: Will commit the database if the link is made correctly.

$repos->check_out($project, $user);

=cut

sub check_out {
    my ($self, $project, $user) = @_;

    if(!defined $user){
	$user = [getpwuid($>)]->[0];
    }
    my $link_path = [getpwnam($user)]->[7];

    my $id = $self->return_id_online($project);
    
    if(! $self->is_online_data_available($id)){
	die"The project $project is currently unavailable\n\n";	
    }
    
    my $partition_info = $self->find_project_partition($project);

    if ($partition_info->{mode} == 1) {

	# Project is on a read-only partition.  We need to move it.
	my $to_path = $self->select_destination($project, { mode => 'rw' });
	unless ($to_path) {
	    die "Couldn't find a suitable destination for $project.\n";
	}

	# This will check the project out for us, if it succeeds.
	if ($self->move_project_check_out($project, $to_path,
					  $user, $link_path)) {
	    die "Couldn't move $project to a writable partition.\n";
	}

	if (exists($self->{project_link})) {
	    $self->{project_link}->{$project} =
		$self->get_project_link_info($project);
	}
	return;
    }

    # No move needed, so just update the project_link table
    my $online_path = $self->return_online_path_from_id($id);
    
    if (!$online_path ){
	die "Nothing returned from the repository for $project\n\n";
    }
        
    # We don't actually make links any more as they were a pain
    # to keep up to date.  We still update the database though so we know
    # the project was checked out.

    $self->new_link($project, $user, $link_path);

    if (exists($self->{project_link})) {
	$self->{project_link}->{$project} =
	    $self->get_project_link_info($project);
    }
    $self->{DB}->commit();
    return;
}

=head2 check_out_to_location

Checks out a project for a user, creating the symbolic link in a specified
location.  This is a more general version of check_out.

Note that the link does not necessarily need to end in the project name.
To flag this, the location stored in link_path in the database has the
string '/.' added to the front.  This hack is needed as previously the
data stored in link_path was the directory where the link was created, and
not the full path to the link.  Code that looks in link_path needs to check
for this hack.

    $repos->check_out_to_location($project, $user, $link_path);

NB: This commits the database if the link was made.

=cut

sub check_out_to_location {
    my ($self, $project, $user, $link_path) = @_;

    unless ($link_path) { croak "\$link_path must be specified"; }
    unless ($link_path =~ /^\//) { croak "\$link_path must be absolute"; }

    my $id = $self->return_id_online($project);
    unless ($id) {
	die "The project $project does not exist\n";
    }

    unless ($self->is_online_data_available($id)) {
	die "The project $project is currently unavailable\n";
    }

    my $online_path = $self->return_online_path_from_project($project);

    unless ($online_path) {
	die "The project $project is not online\n";
    }

    unless (defined($user)) {
	$user = [getpwuid($>)]->[0];
    }

    my $co_user = $self->return_checked_out_user($project);
    if ($co_user && $co_user ne $user) {
	die "Project $project is already checked out by $co_user\n";
    }

    if (-l $link_path) {
	if (readlink($link_path) ne $link_path) {
	    unlink($link_path) || die "Couldn't remove $link_path $!\n";
	    symlink($online_path, $link_path)
		|| die "Couldn't link $online_path to $link_path $!\n";
	}
    } else {
	symlink($online_path, $link_path)
	    || die "Couldn't link $online_path to $link_path $!\n";
    }

    $self->new_link($project, $user, "/.$link_path");
    if ($self->{project_link}) {
	$self->{project_link}->{$project}->{link_path} = "/.$link_path";
    }

    $self->{DB}->commit();
}

=head2 check_in:

unlinks the link in the users account and sets the current project_link
iscurrent to 0 and fills in the expired date field.  If the project is
on a read-write partition then it will be moved to a read-only one.    

=cut

sub check_in {
    my ($self, $project) = @_;
    
    my $get_link = qq[select link_path
		      from   project_link
		      where  projectname = ?
		      and    is_current  = 1];

    my ($link_path) = $self->{DB}->selectrow_array($get_link, {}, $project);
    unless ($link_path) {
	warn "$project does not appear to be checked out.\n";
	return;
    }

    my $partition_info = $self->find_project_partition($project);
    if ($partition_info->{mode} == 0) {
	# Project is on a read-write partition.  Move it back to a
	# read-only one
	my $to_path = $self->select_destination($project,
						{ mode => 'force-ro' });
	unless ($to_path) {
	    die "Couldn't find a suitable destination for $project.\n";
	}
	
	# This will check the project in as well
	if ($self->move_project_check_in($project, $to_path)) {
	    die "Couldn't move $project to a read-only partition.\n";
	}

	if (exists($self->{project_link})) {
	    delete($self->{project_link}->{$project});
	}
	return 1;
    }

    # No need to move the project, so just expire the link
    $self->expire_link($project);

    if (exists($self->{project_link})) {
	delete($self->{project_link}->{$project});
    }
    $self->{DB}->commit();

    return 1;
}

=head2 expire_link

Expire a project link in the database.  Does NOT attempt to remove the symbolic
link.  Use check_in if you want to do this.

  $repos->expire_link($project);

=cut

sub expire_link {
    my ($self, $project) = @_;

    my $expire = qq[update project_link
		    set    is_current    = 0,
		           date_expired  = sys_extract_utc(systimestamp)
		    where  projectname   = ?
		    and    is_current    = 1];

    $self->{DB}->do($expire, {}, $project);    
}

=head2 new_link

Create a new entry in the project_link table

    $repos->new_link($project, $account, $link_path);

=cut

sub new_link {
    my ($self, $project, $account, $link_path) = @_;

    $self->expire_link($project);

    my $new_link_sql = qq[insert into project_link (projectname,
						    accountname,
						    link_path,
						    date_created,
						    is_current)
			  values (?, ?, ?, sys_extract_utc(systimestamp), 1)];

    $self->{DB}->do($new_link_sql, {}, $project, $account, $link_path);
}

=head2 count_projects_on_partition:

	#
	No Documentation as yet.

=cut

sub count_projects_on_partition {
	my ($self, $partition) = @_;
	confess "Wrong object type\n" unless ref($self);
	
	return $self->{DB}->fetch_scalar("
							select 
								count(project.projectname)
							from 
								project, online_data, disk_partition
							where
								project.id_online = online_data.id_online
							and 
								online_data.id_partition = disk_partition.id_partition
							and 
								disk_partition.partition_path = '$partition'");

}

sub update_free_bytes {
	my ( $self, $id_partition, $bytes ) = @_;

	$self->{DB}->do(qq[ update disk_partition set free_bytes = free_bytes - ? where id_partition = ? ], 
				{}, $bytes, $id_partition);

}

sub update_free_bytes_absolute {
    my ( $self, $id_partition, $bytes ) = @_;
    
    $self->{DB}->do(qq[update disk_partition
		       set    free_bytes   = ?
		       where  id_partition = ?],
		    {}, $bytes, $id_partition);
}

sub check_real_disk_size {
    my ( $self, $partition_path ) = @_;
    my $available = -1;
    for (my $tries = 0; $tries < 2 && $available < 0; $tries++) {
	my $DF;
	if(!open($DF, '-|', 'df', '-kP', $partition_path)) {
	    warn("Failed to stat $partition_path\n");
	    return -1;
	}
	
	while(<$DF>){
	    if( /^\S+\s+\d+\s+\d+\s+(\d+)\s+\d+\%/ ){
		$available = $1;
	    }
	}
	close($DF) or warn("Error running df\n");
    }
    return $available * 1024;
}


sub return_predicted_size {
    my ($self, $project_name ) = @_;

    my $dbh = $self->{DB};

    # First see what state the project is in

    my $get_status = $dbh->prepare_cached(qq[select status
					     from   project_status
					     where  projectname = ?
					     and    status in (20, 21, 22, 23,
							       24, 26, 32)
					     and    iscurrent = 1]);
    $get_status->execute($project_name);
    my ($status) = $get_status->fetchrow_array();
    $get_status->finish();

    my $project_type = $self->get_project_type($project_name);

    # If the project is in a finished- or on hold- type state, use its
    # estimated size on disk if available and up to date

    if ((defined($status) && $status) || ($project_type == 2)) {
	my $get_est_bytes
	    = $dbh->prepare_cached(qq[select od.size_est_bytes,
				             sysdate - od.last_inspected
				      from   online_data od, project p
				      where  p.projectname = ?
				      and    od.id_online = p.id_online]);
	$get_est_bytes->execute($project_name);
	my ($est_size, $age_days) = $get_est_bytes->fetchrow_array();
	$get_est_bytes->finish();

	if (defined($est_size) && $est_size && $age_days < 10) {
	    return $est_size;
	}
    }

    if ($project_type == 14) {      # ExoCan projects
	return $DEFAULT_CANCER_PROJECT_SIZE;
    }

    # Otherwise, try to guess the size from the average insert size
    # from the restriction digest data for this clone

    my ($get_size_digest)
	= $dbh->prepare_cached(qq[select avg(li.insert_size_bp) av_size
				  from  clone_project cp, rdrequest rdr,
				        rdgel_lane rdgl, rdgel_lane_image li
				  where cp.projectname   = ?
				  and   cp.clonename     = rdr.clonename
				  and   rdr.id_rdrequest = rdgl.id_rdrequest
				  and   rdgl.id_rdgel    = li.id_rdgel
				  and   rdgl.lane        = li.lane]);
    $get_size_digest->execute($project_name);
    my ($size) = $get_size_digest->fetchrow_array();
    $get_size_digest->finish();

    unless(defined $size ) { $size = 0 } ;
    return $size * $INSERTSIZE_BYTESUSED_FACTOR;
}

sub return_predicted_size_partition {
    my ($self, $id_partition) = @_;

    my $partition_size = 0;

    my $dbh = $self->{DB};
    my $get_projects = $dbh->prepare(qq[select p.projectname
					from   project p, online_data od
					where  p.id_online = od.id_online
					and    od.id_partition = ?]);

    $get_projects->execute($id_partition);
    while (my ($project) = $get_projects->fetchrow_array()) {
	my $proj_size = ($self->return_predicted_size($project)
			 || $DEFAULT_PROJECT_SIZE);
	$partition_size += $proj_size;
    }
    $get_projects->finish();

    return $partition_size;
}

=head2 assign_partition2

    $repos->assign_partition2(\%opts);

Chooses which partition to put a new project into.  %opts contains
parameters for choosing the partition.

The options are:

=over 4

=item mode

Mode can be 'ro' or 'rw'.  If 'ro' a read-only partition is used, otherwise
a read-write ont is chosen.

=item type

The type of partition to choose.  This can either be a scalar (in which
case only one type is considered) or an array reference which lists a
number of possible types in order of preference.  The values for type
should be the numerical IDs from repositorytypedict.

=item minsize

The minimum space required by the project.  Partitions with free_bytes less
than this value will not be considered.

=item no_update_free

Do not update free_bytes for the chosen partition.  If this option is false,
free_bytes for the chosen partition is reduced by the expected size of the
project.  Set this to true if you do not want this to happen.

=back

=cut

sub assign_partition2 {
    my ( $self, $opts ) = @_;
    confess "Wrong object type\n" unless ref($self);
    
    unless (defined($opts->{minsize}) && $opts->{minsize}) {
	# use the database default
	$opts->{minsize} = $DEFAULT_PROJECT_SIZE;
    }
    # Allow more than one partition type to be searched for.  The first
    # type in the array will always be chosen if available.
    
    my $types;
    if (ref($opts->{type}) eq 'ARRAY') {
	$types = $opts->{type};
    } else {
	$types = [$opts->{type}];
    }
    
    my @desired_ro = (0);
    if ( $opts->{mode} eq 'ro' ) {
	unshift(@desired_ro, 1);
    } elsif ($opts->{mode} eq 'force-ro') {
	@desired_ro = (1);
    }
    
    my $get_partitions
	= $self->{DB}->prepare(qq[select id_partition, 
				         repository_type, 
				         partition_path, 
				         max_size_bytes, 
				         is_readonly, 
				         is_active, 
				         free_bytes
				  from 	disk_partition 
				  where max_size_bytes >= ?
				  and   is_readonly = ?
				  and   repository_type = ?
				  and   is_active = 1
				  order by free_bytes desc]);

    my ($id, $ptype, $path, $max_size, $is_readonly, $is_active, $free);
    $free = 0;
    foreach my $ro (@desired_ro) {
	foreach my $type (@$types) {
	    $get_partitions->execute($opts->{minsize}, $ro, $type);
	    
	    while (my @row = $get_partitions->fetchrow_array()) {
		($id, $ptype, $path, $max_size,
		 $is_readonly, $is_active, $free) = @row;
		my $really_free = $self->check_real_disk_size($path);
		if ($really_free < 0) {
		    print STDERR "Couldn't determine free space left on $path\n";
		    next;
		}
		if ($really_free < $free) {
		    my $adjustment = $free - $really_free;
		    unless (exists($opts->{no_update_free})
			    && $opts->{no_update_free}) {
			$self->update_free_bytes($id, $adjustment);
		    }
		    $free = $really_free;
		}
		if ($free >= $opts->{minsize} ) {
		    last;
		}
	    }
	    $get_partitions->finish();

	    if ($free >= $opts->{minsize}) { last; }
	}
	if ($free >= $opts->{minsize}) { last; }
    }
    
    if( $free < $opts->{minsize} ){
	unless ($opts->{silent}) {
	    print STDERR "Couldn't determine a partition that meets the required specification\n";
	}
	return;
    }
    
    my $mode = $is_readonly ? "ro" : "rw";
    $self->{assigned_partition} = [$max_size, $ptype, $is_active, $mode,
				   $path, $id];

    unless (exists($opts->{no_update_free}) && $opts->{no_update_free}) {
	$self->update_free_bytes( $id, $opts->{minsize} );
    }
    return;    
}

=head2 assign_partition

	No Documentation as yet.

=cut

sub assign_partition {
    my ($self, $opts) = @_;
    confess "Wrong object type\n" unless ref($self);

    my %partition;

    $self->read_disk_partition_table();
        
    unless (defined($opts->{minsize}) && $opts->{minsize}) {
	# use the database default
	$opts->{minsize} = $DEFAULT_PROJECT_SIZE;
    }

    # Allow more than one partition type to be searched for.  The first
    # type in the array will always be chosen if available.

    my $types;
    if (ref($opts->{type}) eq 'ARRAY') {
	$types = $opts->{type};
    } else {
	$types = [$opts->{type}];
    }

    foreach my $type (@$types) {

	if( $opts->{mode} eq 'ro') {
	    #
	    # ro partition requested
	    #
	    foreach (@{$self->{partitions}}) {
		
		#select all ro active partitions;
		if (($_->{MODE} eq 'ro')
		    && ($_->{ACTIVE} == 1 )
		    && ($_->{TYPE} == $type)
		    && ($_->{FREE} > $opts->{minsize})) {
		    
		    $partition{$_->{FREE}} = $_;
		    # $partition{$self->get_free_bytes($_->{PATH})} = $_;
		    ## $partition{$self->get_available_space($_->{PATH})} = $_;
		}
	    }
	}
    
	unless (%partition) {
	    #
	    # no ro partitions available or rw partition requested;
	    #
	    foreach ( @{$self->{partitions}}) {
		
		if( $opts->{mode} eq 'rw') {
		    #select all rw non active partitions;
		    if (($_->{MODE} eq 'rw')
			&& ($_->{ACTIVE} == 1)
			&& ($_->{TYPE} == $type)
			&& ($_->{FREE} > $opts->{minsize})) {
			
			$partition{$_->{FREE}} = $_;
			# $partition{$self->get_free_bytes($_->{PATH})} = $_;
			## $partition{$self->get_available_space($_->{PATH})} = $_;	
		    }
		}
	    }
	}
	last if (%partition);
    }

    unless (%partition) {
	unless ($opts->{silent}) {
	    print STDERR "Couldn't determine a partition that meets the required specification\n";
	}
	return;
    }

    # Find the partition with the most free space

    my ($biggest) = sort num keys(%partition);

    #select this partition;
    my $p = $partition{$biggest};
    $self->{assigned_partition} = [$p->{MAX_SIZE}, $p->{TYPE}, $p->{ACTIVE}, $p->{MODE}, $p->{PATH}, $p->{ID}];
    $self->update_free_bytes( $p->{ID}, $opts->{minsize} );
    return;
}

=head2 get_available_space

	No Documentation as yet.

=cut

sub get_available_space {
    my ($self, $path) = @_;

    my $avail_sql1 = qq[select dp.max_size_bytes - sumcalc.sxum
			from disk_partition dp,
			     (select od.id_partition, sum(od.size_est_bytes) SXUM
			      from online_data od, disk_partition dp
			      where dp.partition_path = ?
			      and   od.id_partition   = dp.id_partition
			      group by od.id_partition) sumcalc
			where dp.id_partition = sumcalc.id_partition];
    
    my ($available) = $self->{DB}->selectrow_array($avail_sql1, {}, $path);

    if (!defined $available ){
	#partition doesn't have an online entry;
	#either old archived data or not used;
	
	my $avail_sql2 = qq[select max_size_bytes
			    from  disk_partition
			    where partition_path = ?];

	($available) = $self->{DB}->selectrow_array($avail_sql2, {}, $path);
    }

    return $available;	
}

sub get_free_bytes {
	
	my ($self, $path) = @_;
	confess("Wrong type\n") unless ref($self);
	my @free = $self->{DB}->fetch_row("select free_bytes from disk_partition where partition_path = '$path'");
	return( $free[0] );
}


=head2 make_disk_partition_active

	No Documentation as yet.

=cut 

sub make_disk_partition_active {
	my ($self, $hash_ref) = @_;
	confess "Wrong object type\n" unless ref($self);

	$self->{DB}->do("update disk_partition set is_active = 1 where disk_partition.id_partition = $hash_ref->{partition_id}");
	return;
}

=head2 make_disk_partition_inactive

	No Documentation as yet.

=cut

sub make_disk_partition_inactive {
	my ($self, $hash_ref) = @_;
	confess "Wrong object type\n" unless ref($self);

	$self->{DB}->do("update disk_partition set is_active = 0 where disk_partition.id_partition = $hash_ref->{partition_id}");
	return;
}

=head2 add_project

	No Documentation as yet.

=cut

sub add_project {
	my ($self, $project, $repository) = @_;
	confess "Wrong object type\n" unless ref($self);

	$self->assign_partition();
	return;
}

=head2 return_projectname_from_id_online

	return the projectname from id_online;

=cut

sub return_projectname_from_id_online {
	my ( $self, $id ) = @_;

	my @projectname = $self->{DB}->fetch_row("select projectname from project where id_online = $id");
	return $projectname[0];
}
=head2 return_project_size

	No Documentation as yet.

=cut

sub return_project_size {
	my ($self, $project) = @_;


	return $self->{DB}->fetch_scalar("
								select 
									online_data.size_est_bytes 
								from 
									online_data, project
								where 
									project.projectname = '$project'
								and 
									project.id_online = online_data.id_online
								");
}

=head2 select_destination

    my $to_path = $repos->select_destination($project, $hints);

Selects a new location for $project, given $hints.  The actual selection is
done by assign_partition2.

Hints are:

=over 4

=item mode

'ro' or 'rw'.  Default is the mode of the partition where the project currently
is.

=item type

Repository type to choose (e.g. General).  If not given, this will be either
the type of the project, or General.

=item size

Free size of the destination partition in bytes.

=back

=cut

sub select_destination {
    my ($self, $project, $hints) = @_;
    
    unless ($hints) { $hints = {}; }

    if (!defined $self->{partitions} ){
	$self->read_disk_partition_table();
    }

    my $id_online = $self->return_id_online($project);

    my $found_partition = $self->find_project_partition($project);
    unless ($found_partition) { die "Couldn't find partition for $project\n"; }
    
    my $mode = $found_partition->{mode} == 0 ? 'rw' : 'ro';
    
    my $size = $self->return_predicted_size($project);

    # Choose repos type.  Use:  project type, previous repos type, general
    my @repos_to_try;
    my $proj_type = $self->get_project_type($project);
    my $general   = $self->return_repos_id("General");
    if ($proj_type) {
	push(@repos_to_try, $proj_type);
    }

    if ($found_partition->{type}
	&& $found_partition->{type} != $proj_type
	&& $found_partition->{type} != $general) {
	
	push(@repos_to_try, $found_partition->{type});
    }
    if ($general && $proj_type != $general) { 
	push(@repos_to_try, $general);
    }

    $self->{assigned_partition} = undef; # So we can see if it worked
    $self->assign_partition2({
	'mode'    => $hints->{mode}    || $mode,
	'type'    => $hints->{type}    || \@repos_to_try,
	'minsize' => $hints->{minsize} || $size,
	'no_update_free' => 1,
    });

    unless (defined($self->{assigned_partition})) {
	# Didn't get a partition, so give up
	return;
    }
    my $to_path = $self->{assigned_partition}->[4];

    return $to_path;
}

=head2 move_project

    $repos->move_project($project);

Moves project $project to a new location.  assign_partition2 is used to work
out the best new location for the project.

Returns 1 if the move failed, 0 if it worked.

=cut

sub move_project {
    my ($self, $project, $hints) = @_;
    
    my $to_path = $self->select_destination($project, $hints);
    unless ($to_path) { return 1; }

    my $res = $self->move_project_to_partition_path($project, $to_path);

    if ($res != 0) {
	warn"Directory move failed: Oracle rolled back\n";
	return 1;
    }
    
    return 0;
}

=head2 move_project_to_partition_path

    $repos->move_project_to_partition_path($project, $to_path);

Moves project $project to the partition with path $to_path.  The files are
copied using copy_directory and the old copy is removed if successful.  The
database is also updated to reflect the new location of the project.

Returns 1 if the move failed, 0 if it worked.

=cut

sub move_project_to_partition_path {
    my ($self, $project, $to_path) = @_;

    my $res = 1;

    require RPC::PlClient;
    my $client = RPC::PlClient->new(peeraddr    => 'repossrv',
				    peerport    => $PMOVE_SVR_PORT,
				    application => 'PMoveServer',
				    version     => '1.0');
    eval {
	$client->Call('move_project', $project, $to_path, $0);
	$res = 0;
    };
    if ($@) {
	warn "Move failed: $@\n";
    }

    return $res;
}

=head2 move_project_check_out

    $repos->move_project_check_out($project, $to_path, $account, $link_path);

Moves $project to the partition with path $to_path.  The project will also
be checked out to $account, with link path $link_path.

Returns 0 on success, 1 on failure

=cut

sub move_project_check_out {
    my ($self, $project, $to_path, $account, $link_path) = @_;

    my $res = 1;

    require RPC::PlClient;
    my $client = RPC::PlClient->new(peeraddr    => 'repossrv',
				    peerport    => $PMOVE_SVR_PORT,
				    application => 'PMoveServer',
				    version     => '1.0');
    eval {
	$client->Call('check_out', $project, $to_path,
		      $account, $link_path, $0);
	$res = 0;
    };
    if ($@) {
	warn "Move and check-out failed: $@\n";
    }

    return $res;
}

=head2 move_project_check_in

    $repos->move_project_check_in($project, $to_path);

Moves $project to the partition with path $to_path.  The project will also
be checked in.

Returns 0 on success, 1 on failure

=cut

sub move_project_check_in {
    my ($self, $project, $to_path) = @_;

    my $res = 1;

    require RPC::PlClient;
    my $client = RPC::PlClient->new(peeraddr    => 'repossrv',
				    peerport    => $PMOVE_SVR_PORT,
				    application => 'PMoveServer',
				    version     => '1.0');
    eval {
	$client->Call('check_in', $project, $to_path, $0);
	$res = 0;
    };
    if ($@) {
	warn "Move and check-in failed: $@\n";
    }

    return $res;
}

=head2 pmove_server_test

    $repos->pmove_server_test();

Sends a ping to the PMoveServer, and checks that is gets the expected reply.
This is a quick check to see if the server is up and responding.

=cut

sub pmove_server_test {
    my ($self) = @_;

    require RPC::PlClient;
    my $client = RPC::PlClient->new(peeraddr    => 'repossrv',
				    peerport    => $PMOVE_SVR_PORT,
				    application => 'PMoveServer',
				    version     => '1.0');
    my ($res) = $client->Call('ping');
    unless ($res eq 'pong') {
	die "pmove_server_test : Call('ping') failed to return 'pong'\n";
    }
    return 1;
}

=head2 request_backup

    $repos->request_backup($project);

Request that a project is backed up.

=cut

sub request_backup {
    my ($self, $project) = @_;

    my $id_online = $self->return_id_online($project);
    unless ($id_online) { die "request_backup: $project is not online\n"; }

    my $dbh = $self->{DB};
    my $lookup_status = q[select rbs.status
			  from   repos_backup_status rbs
			  where  rbs.id_online = ?
			  and    rbs.iscurrent = 1];
    my $update_iscurrent = q[update repos_backup_status rbs
			     set    rbs.iscurrent = 0
			     where  rbs.iscurrent = 1
			     and    rbs.id_online = ?];
    my $ins_status
	= q[insert into repos_backup_status (id_online, status,
					     status_date, iscurrent)
	    values (?, 'R', sys_extract_utc(systimestamp), 1)];
    my ($status) = $dbh->selectrow_array($lookup_status, {}, $id_online);
    if ($status && $status eq 'B') { return; } # Backup already running
    if ($status && $status eq 'R') { return; } # Backup already requested
    $dbh->do($update_iscurrent, {}, $id_online);
    $dbh->do($ins_status, {}, $id_online);
}

=head2 move_directory 

    $repos->move_directory($project, $from, $to);

Moves directory $project from partition $from to partition $to.  The files
are copied between the two locations.  If the copy worked, the original
is removed, otherwise the broken new copy is cleaned up.  NB: Only files
are moved, the database is not updated!

Returns 0 on success, 1 on failure.

=cut

sub move_directory {
    my ($self, $project, $from, $to) = @_;

    if ($self->copy_directory($project, $from, $to)) {
	$self->remove_directory($project, $to);
	return 1;
    } else {
	$self->remove_directory($project, $from);
    }

    return 0;
}

=head2 copy_directory

    $repos->copy_directory($project, $from, $to);


Copies project directory $project from partition $from to partition $to.
After the directory has been copied, checksums are compared to make sure that
the copy worked correctly.

Returns 1 if an error occurred, 0 if the copy worked.

If an error does occur, is it up to the caller to remove the broken new copy.

=cut

sub copy_directory {

    my ($self, $project, $from, $to) = @_;

    if( -d "$to/$project" ){
	print STDERR "Directory of same name already exists in that location\n";	return 1;
    }

    if (system('rsync', '-aWv', "$from/$project", "$to/")) {
	warn "Error copying directory\n";
	return 1;
    }

    print STDERR "\nVerifying...\n";

    if (system('diff', '-qr', "$from/$project", "$to/$project")) {
	warn "Verify failed\n";
	return 1;
    }
	
    return 0;
}

=head2 get_checksums

    my $checksums = get_checksums($cluster, $dir, $entry);

Remotely get MD5 checksums for file/dir $entry in directory $dir, running the
checksum process on machine $cluster.

NB: Not a member function!

=cut


sub get_checksums {
    my ($cluster, $dir, $entry) = @_;

    local *SUMS;

    my %chksums;
    my @SSH = find_ssh();

    my $csum = q[/usr/bin/perl -e 'use File::Find; use Digest::MD5;  my $md5 = Digest::MD5->new(); chdir($ARGV[0]); find(\&wanted, $ARGV[1]); sub wanted { if (-f $_) { open(F, "<", $_); $md5->addfile(\*F); print $md5->hexdigest(), " $File::Find::name\n"; close(F); } }'];

    open(SUMS, "-|")
	or exec(@SSH, $cluster, $csum, $dir, $entry)
	or die "Couldn't open MD5 pipeline $!\n";
    while (<SUMS>) {
	chomp;
	my ($digest, $file) = split(" ", $_, 2);
	$chksums{$file} = $digest;
    }
    close(SUMS) || die "Error reading from MD5 pipeline $!\n";

    return \%chksums;
}

=head2 cmp_checksums

    $res = cmp_checksums($chksums1, $chksums2);

NB: Not a class method!

Compares two sets of checksums from get_checksums.  Returns 0 if they are
the same, 1 if they differ.

=cut

sub cmp_checksums {
    my ($chksums1, $chksums2) = @_;

    my $keys1 = scalar(keys %$chksums1);
    my $keys2 = scalar(keys %$chksums2);

    if ($keys1 != $keys2) { return 1; }

    while (my ($key, $digest) = each %$chksums1) {
	if (!exists($chksums2->{$key}))   { return 1; }
	if ($digest ne $chksums2->{$key}) { return 1; }
    }

    return 0;
}

sub verify {
	my ( $self, $path ) = @_;
    open(SIZE, "/usr/local/badger/bin/verify $path |") or print STDERR "Couldn't open verify program\n";
    my $size = <SIZE>;
    close(SIZE);
    chop($size);
    return $size;
}

=head2 remove_directory

    $repos->remove_directory($project, $path);

Removes directory $project from partition $path

=cut

sub remove_directory {
    my ($self, $project, $path) = @_;

    print STDERR "Removing $path/$project\n";

    system('/bin/rm', '-rf', "$path/$project")
	&& die "Error running /bin/rm -rf $path/$project\n";
}

=head2 read_project_link_table

	No Documentation as yet.

=cut

sub read_project_link_table {
	my ($self, $project) = @_;
	my ($row, $rows);

	$rows = $self->{DB}->fetch_all("select projectname, accountname, link_path, is_current, date_created, date_expired from project_link where is_current = 1");

	foreach $row ( @{$rows} ){
		$self->{project_link}->{$row->[0]}->{account}    = $row->[1];
		$self->{project_link}->{$row->[0]}->{link_path}  = $row->[2];
		$self->{project_link}->{$row->[0]}->{is_current} = $row->[3];
		$self->{project_link}->{$row->[0]}->{created}    = $row->[4];
		$self->{project_link}->{$row->[0]}->{expired}    = $row->[5] unless !defined $row->[4];
	}
}

=head2 get_project_link_info

Return information about a single entry in the project_link table.

my $res = $repos->get_project_link_info($project);

If the project has a current link, a hash ref will be returned containing the
following information:

 {
     account   => The account name that has the project checked out,
     link_path => The entry in the link_path column
     link      => The full path to the link, including project name if needed
     created   => When the link was created
 }

=cut

sub get_project_link_info {
    my ($self, $project) = @_;

    my $sql = qq[select accountname, link_path, date_created
		 from   project_link
		 where  is_current  = 1
		 and    projectname = ?];

    my ($account, $link_path, $date_created)
	= $self->{DB}->selectrow_array($sql, {}, $project);

    unless (defined($link_path)) { return; }

    my $link = ($link_path =~ m!^/\.(/.*)!) ? $1 : "$link_path/$project";
    
    return {
	account   => $account,
	link_path => $link_path,
	"link"    => $link,
	created   => $date_created,
	is_current => 1,
    };
}

=head2 find_project_partition

	No Documentation as yet.

=cut

sub find_project_partition {
    my ($self, $project) = @_;
    my ($path, $id_online);
    
    $id_online = $self->return_id_online($project);
    
    if (defined $id_online ){
	my $dbh = $self->{DB};
	my ($id_partition)
	    = $dbh->selectrow_array(qq[select id_partition
				       from   online_data
				       where  id_online =  ?],
				    {}, $id_online);
	return $self->get_partition_from_id($id_partition);
    }	
    die"Project $project doesn't have an entry in online_data and disk_partition\n";
    return;
}

=head2 return_id_online

	Returns the id_online when passed projectname as an argument

=cut

sub return_id_online {
    my ($self, $project) = @_;
    confess(" Wrong type\n") unless ref($self);

    my $sql = qq[select id_online from project where projectname = ?];
    my ($id_online) = $self->{DB}->selectrow_array($sql, {}, $project);

    return $id_online;

#     return($self->{DB}->fetch_scalar("select id_online from project where projectname = '$project'"));
}

=head2 get_partition_from_id

Gets information about a partition given its id.  For some reason, this is
put into $self->{found_partition}.

    $repos->get_partition_from_id($id_partition);
    print $repos->{found_partition}->{type};

The keys that are returned are:

=over 4

=item id

The partition id (which you supplied)

=item type

The partition type (from repositorytypedict)

=item path

The partition_path

=item size

The recorded size (in bytes)

=item mode

0 = read-write, 1 = read-only

=item active

1 = the partition can accept new projects

=item free

The number of free bytes the database thinks is available.

=back

=cut

sub get_partition_from_id {
	my ($self, $id) = @_;

	my @row = $self->{DB}->selectrow_array(qq[select repository_type,
							 partition_path,
							 max_size_bytes,
							 is_readonly,
							 is_active,
							 free_bytes
						 from disk_partition where id_partition = ? ],
						 {}, $id );

	my %data;
	$data{id}     = $id;
	$data{type}   = $row[0];
	$data{path}   = $row[1];
	$data{size}   = $row[2];
	$data{mode}   = $row[3];
	$data{active} = $row[4];
	$data{free}   = $row[5];
	
	$self->{found_partition} = \%data;

	return \%data;
}


=head2 return_id_partition

Returns the id_partition for a partition_path.  Note that this does almost the
same thing as return_id_partion_from_path.

    my $id_partiton = $repos->return_id_partition($partition_path);

=cut

sub return_id_partition {
    my ($self, $partition) = @_;
    confess "wrong type\n" unless ref($self);
    my ($id) = $self->{DB}->selectrow_array(qq[select id_partition
					       from disk_partition
					       where partition_path = ?],
					    {}, $partition);
    return $id;
}

=head2 return_id_archive

	# Return id_archive from from archived_data from project;
	No Documentation as yet.

=cut

sub return_id_archive {
	my ($self, $project) = @_;
	return $self->{DB}->fetch_scalar("select id_archive from archived_data where projectname = '$project'");
}

=head2 get_project_from_project_table

	# Returns the whole object of a specified project;
	No Documentation as yet.

=cut

sub get_project_from_project_table {
	my ($self, $project) = @_;
	$self->{found_project} = $self->{DB}->fetch_all("select * from project where projectname = '$project'");
	return;
}	


=head2 get_online_status_from_project

	Returns the iscurrent status of project;

=cut
sub get_online_status_from_project {
    my ($self, $project) = @_;
    confess("Wrong type\n") unless ref($self);

    my $sql = q[select os.status
		from   online_status os, project p
		where  p.projectname = ?
		and    p.id_online = os.id_online
		and    os.iscurrent = 1];
    my ($status) = $self->{DB}->selectrow_array($sql, {}, $project);
    return $status;
}

=head2 get_archive_status_from_project 

	Returns the iscurrent status of project from archive_status

=cut

sub get_archive_status_from_project {
    
    my ($self, $project) = @_;
    confess("Wrong type\n") unless ref($self);
    
    my $sql = q[select as.status
		from   archive_status as, project p, online_data od
		where  p.projectname = ?
		and    p.id_online = od.id_online
		and    od.id_archive = as.id_archive
		and    as.iscurrent = 1];
    my ($status) = $self->{DB}->selectrow_array($sql, {}, $project);
    return $status;
}

=head2 update_post_restore_script

	Updates the restore script that is run during a restore.
	eg.

	$self->update_post_restore_script($id_archive,'/usr/local/badger-bin/merlin');

=cut 

sub update_post_restore_script {

	my ($self,$id_archive, $script) = @_;

	$self->{DB}->do("update archived_data set post_restore_script = '$script' where id_archive = $id_archive"); 
	return;

}


=head2 return_checked_out_user

	Returns the accountname of the user who currently has the project checked out
	or undef if something has gone wrong!

=cut


sub return_checked_out_user {

    my ($self, $project ) = @_;

    my $sql = qq[select accountname
		 from   project_link
		 where  projectname = ?
		 and    is_current  = 1];

    my ($user) = $self->{DB}->selectrow_array($sql, {}, $project);

    return $user;
}

=head2 return_checked_out_projects

Returns the projects currently checked out by a user account (as an array ref)

=cut

sub return_checked_out_projects {
    my ($self, $user) = @_;

    my $sql = qq[select projectname
		 from   project_link
		 where  accountname = ?
		 and    is_current  = 1];

    my $projects = $self->{DB}->selectall_arrayref($sql, {}, $user);

    if ($projects) {
	my @p = map { $_->[0] } @$projects;
	return \@p;
    }

    return;
}

=head2 lookup_dest_dir_in_repos

=cut

sub lookup_dest_dir_in_repos {
    my ($self, $project, $opts) = @_;

    unless ($project) { croak "\$project undefined"; }
    unless (ref($opts)) { $opts = {}; }

    my $dest_dir = "";

    unless ($self->project_exists($project)) {
	return ("PROJECT MUST EXIST IN ORACLE", $dest_dir);
    }

#    Archiving is currently turned off.
#    
#    if ($self->is_project_archived($project)) {
#	return ("PROJECT IS CURRENTLY ARCHIVED", $dest_dir);
#    }

    my $id_online = $self->return_id_online($project);

    if ($id_online) {
	$dest_dir = $self->return_orig_path_from_online_id($id_online);

	unless ($self->is_online_data_available($id_online)) {
	    return ("PROJECT CURRENTLY UNAVAILBLE", $dest_dir);
	}
    } else {
	# Need to make a new directory

	unless ($opts->{create}) {
	    return ("PROJECT HAS NO ONLINE DIRECTORY", $dest_dir);
	}
	
	print STDERR "\n*** Creating new project in repository***\n\n";

	$self->new_project(0, $project);

	$id_online = $self->return_id_online($project);
	$dest_dir = $self->return_orig_path_from_online_id($id_online);

	unless ($dest_dir) {
	    return ("COULD NOT CREATE PROJECT IN REPOSITORY", $dest_dir);
	}
    }

    if ($opts->{"check_out"}) {
	my $project_user = $self->return_checked_out_user($project);

	unless ($project_user) {

	    print STDERR "Checking out project\n";
	    $self->check_out($project);

	}
    }

    return ("OK", $dest_dir);
}

=head2 find_server

When passed the path to a mount point (i.e. a repository partition) it returns
the server for that disk in an array reference.  Note that it is possible
for the disk to be served from more than one interface on that machine.  If
this is the case, the array will contain one entry for each interface.

    e.g.
    my $servers = $repos->find_server("/nfs/remotedisk");

    $servers will contain a list of all the interfaces serving /nfs/remotedisk

=cut

sub find_server {
    my ($self, $mount_point) = @_;

    my $mount_servers = $self->{mount_servers};
    if (exists($mount_servers->{$mount_point})) {
	return $mount_servers->{$mount_point};
    }

    # The entire find_server code is now defunct as we no longer have any
    # NFS servers doubling up as LSF compute servers. Furthermore on precise
    # machines such as seq3 YP has not been configured, leading to timeouts
    # in the ypmatch command.

    $mount_servers->{$mount_point} = undef;
    return $mount_servers->{$mount_point};
}

=head2 served_by

served_by takes a path and a hash where the keys are machine names.  It looks
up the servers of the path using find_server and then checks to see if
any are keys to %$machines.  It returns the first match it finds.  If no
match is found, it returns undef.

The return value of served_by can be used, for example, to choose which batch
queue jobs are run on - preferably one where the partition is locally
mounted on the machine in question.

    e.g.

    my %machines = (alpha => 1, beta => 1, gamma => 1);
    my $server = $repos->served_by($path, \%machines);
    
    $server will be 'alpha', 'beta' or 'gamma' if one of these machines
    serves $path, otherwise undef.

=cut

sub served_by {
    my ($self, $path, $machines) = @_;

    my $servers = $self->find_server($path);
    unless ($servers) { return; }

    foreach my $server (@$servers) {
	if (exists($machines->{$server})) {
	    return $server;
	}
    }

    return;
}

=head2 choose_cluster

Choose a cluster to work on based on the directory passed in (or the
value of $ENV{PWD} if the directory parameter was undefined).
Will return undef if it can't work out which cluster to use.

=cut

sub choose_cluster {
    my ($self, $dir) = @_;

    unless (defined($dir)) { $dir = $ENV{PWD}; }

    my $try;
    if ($dir =~ m[(/nfs/repository/[psd]\d+)/]) {
	$try = $1;
    } elsif ($dir =~ m[(/nfs/repository/snp\d+)/]) {
	$try = $1;
    } else {
	$try = $dir;
    }
    $try =~ s#/+$##;

    while ($try) {
	my $cluster = $self->served_by($try, {
	    babel => 1,
	    pcs3 => 1,
	    genesis => 1,
	    nemesis => 1,
	    seq1    => 1,
	});
	if (defined($cluster)) { return $cluster; }

	$try =~ s#/+[^/]+$##;
    }

    return undef;
}

=head2 choose_machine

As for choose_cluster, but if possible it will also try to work out the
specific machine serving the partition in a TruCluster environment.
Will return undef if it can't work out which cluster to use.

=cut

sub choose_machine {
    my ($self, $dir) = @_;

    local *C;
    my $cluster = $self->choose_cluster($dir);
    unless ($cluster) { return $cluster; }

    unless ($cluster =~ /^(?:nemesis|genesis|pcs[23]|babel|hcs[23])/) {
	return $cluster;
    }

    my @SSH = find_ssh();

    my $server_name;

    if (my ($mpoint) = $dir =~ m#^(/nfs/repository/[^/]+)#) {
	open(C, "-|") or exec(@SSH, $cluster, "/usr/sbin/cfsmgr", $mpoint)
	or die "Couldn't open pipe to cfsmgr $!\n";
	while (<C>) {
	    if (/Server\s+Name\s+=\s+(\S+)/) {
		$server_name = $1;
		last;
	    }
	}
	close(C);

	if ($server_name) { return $server_name; }
    }


    return $cluster;
}


=head2 num

	# Numerical sort func

=cut

sub num {
	$b <=> $a;
}
1;

__END__
=head1 BUGS

None that I know of, let me know!

=head1 AUTHOR

Andrew Smith (as1@sanger.ac.uk)

=head1 HISTORY

 # $Log$
 # Revision 1.98  2005/07/25 12:36:37  rmd
 # Changed default size of a cancer project to be 7Gb.
 #
 # Revision 1.97  2004/11/11  15:06:21  rmd
 # Tidied up return_projects_on_partition, make_online_data_available and
 # make_online_data_unavailable.
 #
 # Fixed documentation for make_online_data_unavailable.
 #
 # Added no_update_free option for assign_partition2.  This stops it from
 # altering the free_bytes value for the chosen partition.
 #
 # Complete rewrite of move_project.  Added move_project_to_partition_path
 # which allows the move destination to be specified.  Changed move_directory
 # to copy projects over a socket, and added a better verification routine.
 # Added remove_directory to get rid of old copies of directories.
 #
 # choose_cluster properly returns undef if it doesn't work.
 #
 # Added choose_machine to choose the machine in a Tru64 cluster that is
 # serving a particular disk.
 #
 # Added more documentation.
 #
 # Revision 1.96  2004/05/27  08:46:27  rmd
 # Quoted "link" to remove warning.
 #
 # Revision 1.95  2004/05/26  13:21:07  rmd
 # Added changes to support pathogen annotation directories in the repository.
 # The main addition is the check_out_to_location method.  Also added new_link,
 # expire_link and get_project_link_info.
 #
 # Revision 1.94  2004/02/11  09:44:33  rmd
 # Added new methods alter_partition and commit.
 # Added more POD.
 # Changed return_id_partition and get_available_space to use bind variables.
 #
 # Revision 1.93  2002/08/19  14:03:08  rmd
 # Added new partition_path_exists function.
 # Changed add_partition to use partition_path_exists.
 #
 # Revision 1.92  2002/07/17  10:18:10  rmd
 # Fixed return_id_partion_from_path
 # Added return_checked_out_projects
 #
 # Revision 1.91  2002/05/15  11:24:47  rmd
 # Altered move_project so it doesn't lock rows on the disk_partition table for
 # hours.
 #
 # Revision 1.90  2002/03/27  12:15:03  rmd
 # Added choose_cluster method.
 #
 # Revision 1.89  2002/01/22  10:08:55  rmd
 # Changed add_partition to use bind variables and set free_bytes equal to
 # max_size_bytes so the new partition can be used immediately.
 #
 # Revision 1.88  2001/10/08  15:12:07  rmd
 # Changed move_project so that it tries to move projects to the repos type they
 # belong in rather than to the same type as they moved from.
 #
 # Revision 1.87  2001/09/12  14:14:09  rmd
 # Changed several functions to use bind variables.
 # Tidied up some SQL.
 # Added new lookup_dest_dir_in_repos function.
 #
 # Revision 1.86  2001/05/15  15:55:33  rmd
 # Added functions read_fstab find_server and served_by to allow the machine
 # serving a remote disk to be determined.
 #
 # Revision 1.85  2001/04/18  12:43:56  rmd
 # Changed calculation of project size to make it more accurate.
 # Reduced default project size.
 # Upgraded update_online_data_size.
 # Fixed permissions problem in mkdir.
 # Added update_free_bytes_absolute and return_predicted_size_partition.
 #
 # Revision 1.84  2001/04/09  10:38:06  rmd
 # Fixed read_project_link_table so it now makes a has of projectnames like
 # it is supposed to.
 #
 # Revision 1.83  2001/04/05  08:31:08  as1
 # Recoded assign_partition to use an alternative method of
 # assigning partition based on a relationship between
 # the insert size of a clone and the amount of disk space
 # it requires
 #
 # Revision 1.82  2001/04/03  08:49:38  rmd
 # Changed some SQL to use bind variables.
 # Changed new_project so that if 0 is passed as repository_type it will
 # choose the repository to use based on the project_type in the Oracle project
 # table.  If no repository partition with the specified type is available,
 # a General one will be used instead.
 #
 # Revision 1.81  2000/12/14  11:46:24  rmd
 # Made get_online_path_from_project faster
 #
 # Revision 1.80  2000/08/23  11:05:41  as1
 # removed a table from return_online_status_from_project where it wasn't needed
 # should improve performance
 #
 # Revision 1.79  2000/04/07  09:24:37  jjn
 # Made move_project commit set_unavailable
 #
 # Revision 1.78  2000/01/13  09:08:06  as1
 # moved verify to badger bin
 #
 # Revision 1.77  2000/01/05 09:12:20  as1
 # check for undefined values and reset to 0
 # 
 # Revision 1.76  2000/01/04 14:49:07  as1
 # Now updates the free bytes available on a partition when a project is moved
 # to the new partition.
 # 
 # Revision 1.75  1999/07/30 13:48:15  as1
 # Added return_checked_out_user method
 # 
 # Revision 1.74  1999/06/22 09:40:38  as1
 # removed a wild card from annotation like project
 # 
 # Revision 1.73  1999/03/26 12:12:04  as1
 # Added an update on id_online into project if project exists but
 # doesnot have an online_path
 # 
 # Revision 1.72  1999/03/26 11:27:28  as1
 # If project exists just create the online path entry.
 # 
 # Revision 1.71  1999/02/22 14:03:34  bt1
 # Added return value to check_in, so no link deletion can be detected.
 # 
 # Revision 1.70  1999/02/08 11:45:53  as1
 # If root tries to create a project give the project team43
 # number.
 # 
 # Revision 1.69  1999/01/22 18:06:00  as1
 # Added an update of archive_storage if record already exists
 # 
 # Revision 1.68  1999/01/20 16:27:08  as1
 # Added move_directory function.
 # 
 # Revision 1.67  1999/01/19 08:57:19  as1
 # slight bug
 # 
 # Revision 1.66  1999/01/18 18:36:11  as1
 # Bug fixes and rewrites during nearline testing
 # 
 # Revision 1.65  1999/01/18 11:58:13  as1
 # Added post restore script method.
 # 
 # Revision 1.64  1999/01/18 10:29:47  as1
 # Status code more robust
 # 
 # Revision 1.63  1999/01/14  14:59:40  as1
 # fixed bug in return_archive_status_from_project
 #
 # Revision 1.62  1999/01/11  11:15:22  as1
 # Added methods to comply with schema changes and
 # a method to update the requesting account.
 #
 # Revision 1.61  1999/01/08  10:53:23  as1
 # More status handling routines
 #
 # Revision 1.60  1999/01/07  17:40:20  as1
 # Added some status handling methods
 #
 # Revision 1.59  1999/01/07  11:26:05  as1
 # Removed a information message from check out
 #
 # Revision 1.58  1999/01/07  09:51:31  as1
 # Made changes to archive_data sub
 #
 # Revision 1.57  1999/01/06  19:43:04  as1
 # Made check out more robust
 #
 # Revision 1.56  1998/12/17  17:04:05  as1
 # Removed more old schema code
 #
 # Revision 1.55  1998/12/17  11:27:07  as1
 # Changed restore method to reflect the new schema,
 # partition is no longer stored;
 #
 # Revision 1.54  1998/12/14  15:17:45  as1
 # removed an offending semi colon and commented out some code
 #
 # Revision 1.53  1998/12/14  09:40:08  as1
 # Fixed bug in get_archive_status_from_project
 #
 # Revision 1.52  1998/12/11  16:41:19  as1
 # *** empty log message ***
 #
 # Revision 1.51  1998/12/11  13:03:24  as1
 # Fixed bug in update_archive_status
 #
 # Revision 1.50  1998/12/11  12:32:56  as1
 # Added method make_online_data_unavailable
 #
 # Revision 1.49  1998/12/10  17:54:14  as1
 # Added an update to online_data when archived_data record created
 #
 # Revision 1.48  1998/12/10  16:18:10  as1
 # Changed read_archived_data_table to reflect changes to schema
 #
 # Revision 1.47  1998/12/10  15:32:28  as1
 # Noticed a missing $ in new archived_data method
 #
 # Revision 1.46  1998/12/09  18:07:57  as1
 # Rewrote the add_archived_data method to reflect changes in
 # the schema
 #
 # Revision 1.45  1998/12/07  11:28:09  as1
 # *** empty log message ***
 #
 # Revision 1.44  1998/12/07  10:55:12  as1
 # fixed a bug in update_archive_status and made get_online_path
 # return the online_path as well as set it in the object;
 #
 # Revision 1.43  1998/12/05  18:49:00  as1
 # Added check so that duplicate statuses are not generated
 # everytime a project is inspected.
 #
 # Revision 1.42  1998/12/05  17:22:47  as1
 # Fixed a call to a nonexistant method/
 # added some documentation
 #
 # Revision 1.41  1998/12/05  12:43:33  as1
 # Fixed a bug in update_archive_status
 #
 # Revision 1.40  1998/12/05  09:28:23  as1
 # Added a method to return the projectname from an id_online
 # and changed a die to a warn in the check_in method
 #
 # Revision 1.39  1998/12/04  17:28:16  as1
 # Added changes to is_available in move_project
 #
 # Revision 1.38  1998/12/04  14:41:46  as1
 # added return_archiving_requests routine
 #
 # Revision 1.37  1998/12/03  10:54:54  as1
 # more iscurrent trouble!
 #
 # Revision 1.36  1998/12/03  10:52:17  as1
 # Added a check for current links in read_project_link_table
 #
 # Revision 1.35  1998/12/03  10:43:46  as1
 # Added temporary fix to is_current in check_in
 # should be iscurrent
 #
 # Revision 1.34  1998/12/02  17:55:38  as1
 # Fixed bug in check_in
 #
 # Revision 1.33  1998/12/02  17:18:05  as1
 # Changed the method for allocating partitions.
 # Now uses free bytes column which populated via a df
 #
 # Revision 1.32  1998/12/02  13:32:25  as1
 # Added more methods for archiving.
 #
 # Revision 1.31  1998/12/01  17:29:36  as1
 # Added get_free_bytes method and bug fixes for nearlining and archiving
 #
 # Revision 1.30  1998/11/25  12:39:45  as1
 # Fixed bug in move_project code
 #
 # Revision 1.29  1998/11/19  18:07:13  dn1
 # added stuff
 #
 # Revision 1.28  1998/11/19  12:53:22  as1
 # Project table changed no longer has project_directory
 #
 # Revision 1.27  1998/11/10  07:27:35  as1
 # Added some documentation - not quite finished yet!
 #

