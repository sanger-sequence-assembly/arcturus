package ArcturusDatabase;

use strict;

use DBI;
use DataSource;
use ArcturusDatabase::ADBAssembly;
use Logging;

our @ISA = qw(ArcturusDatabase::ADBAssembly);

use ArcturusDatabase::ADBRoot qw(queryFailed);

# ----------------------------------------------------------------------------
# constructor and initialisation
#-----------------------------------------------------------------------------

sub new {
    my $class = shift;

    my $this = $class->SUPER::new(@_);

    $this->open(@_); # get the data source

    print STDERR "ArcturusDatabase::open failed to create a DataSource\n" unless $this->{DataSource};

    return undef unless $this->{DataSource}; # test it

    $this->init(); # get the database connection

    print STDERR "ArcturusDatabase::init failed to obtain a database connection\n" unless $this->{Connection};

    return undef unless $this->{Connection}; # test it

    $this->populateDictionaries();

    $this->putArcturusUser(); # establish the username

    return $this;
}

sub open {
# open the data source
    my $this = shift;

    my $ds = $_[0];

    if (defined($ds) && ref($ds) && ref($ds) eq 'DataSource') {
	$this->{DataSource} = $ds;
    }
    else {
        my @properties = &loadProperties(@_); # pick up info if not already defined
	$this->{DataSource} = new DataSource(@properties);
# pick up specific info
        my %properties = @properties;
#        $this->setAdministrator($properties{administrator});
    }

    return undef unless $this->{DataSource};

    $this->init();

    return $this;
}

sub init {
    my $this = shift;

    return if defined($this->{inited});

    my $ds = $this->{DataSource} || return; 

    $this->{Connection} = $ds->getConnection();

    return unless $this->{Connection};

    $this->{inited} = 1;
}

sub getConnection {
    my $this = shift;

    if (!defined($this->{Connection})) {
	my $ds = $this->{DataSource};
	$this->{Connection} = $ds->getConnection(@_) if defined($ds);
    }

    return $this->{Connection};
}

sub getInstance {
    my $this = shift;

    my $ds = $this->{DataSource} || return '';

    return $ds->getInstance();
}

sub getOrganism {
    my $this = shift;

    my $ds = $this->{DataSource} || return '';

    return $ds->getOrganism();
}

sub getURL {
    my $this = shift;

    my $ds = $this->{DataSource};

    if (defined($ds)) {
	return $ds->getURL();
    }
    else {
	return undef;
    }
}

sub errorStatus {
# returns DBI error code or message, if any
    my $this = shift;

    return "Can't get a database handle" unless $this->getConnection();

    return ($DBI::err || 0) unless shift;

    return ($DBI::errstr || '');  
}

sub disconnect {
# disconnect from the database
    my $this = shift;

    my $dbh = $this->{Connection};

    if (defined($dbh)) {
        $dbh->disconnect;
        undef $this->{Connection};
    }
}

sub loadProperties {
# private
    my %properties = @_; # input properties already defined

# (try to) retrieve data from .arcturus.props in this directory branch

    my $file = ".arcturus.props";
    for my $i (0,1,2) {
        last if (-f $file);
        return @_ if ($i == 2); # file not found
        $file = "../".$file;   # go one level up
    }

# parse the file

    my $FILE = new FileHandle($file,"r");
    while (my $record = <$FILE>) {
        $record =~ s/^\s+|\s+$//g;
        next unless ($record =~ s/^arcturus\.//);
        my @info = split /\W+/,$record;
        next unless (scalar(@info) == 2); # invalid info
# add the new value to info, unless the property is already defined
        next if defined($properties{ "$info[0]"});
        next if defined($properties{"-$info[0]"});
        push @_,@info;
    }

    return @_; # return input properties and any added from props file 
}

#-----------------------------------------------------------------------------
# version
#-----------------------------------------------------------------------------

sub dbVersion {
    my $this = shift;

    my $dbh = $this->getConnection();
 
    my $sth = $dbh->prepare("select version()");

    $sth->execute();

    my $version = $sth->fetchrow_array();

    $sth->finish();

    return $version;
}

#-----------------------------------------------------------------------------
# arcturus user information
#-----------------------------------------------------------------------------

my $ARCTURUSUSER;

sub putArcturusUser {
# determine the username from the system data
    my $this = shift;

    my $user = getpwuid($<);

# test against prohibited names (force login with own unix username)

    my %forbidden = (pathdb => 1, pathsoft => 1, yeasties => 1,
                     othernames => 1);

    if ($forbidden{$user}) {

        $this->disconnect();

	die "You cannot access Arcturus under username $user";
    }

# valid user

$this->{ArcturusUser} = $user; # temp
    $ARCTURUSUSER = $user;

# initialise the privileges hash

    $this->{privilege} = {} unless $this->{privilege};
}

sub getArcturusUser {
# return the username (as is)
    my $this = shift;

return $this->{ArcturusUser} || ''; # temp
    return $ARCTURUSUSER || '';
}

sub verifyArcturusUser {
# test if the user exists in the USER table; print a warning if not
    my $this = shift;
    my %options = @_; # user=>, list=>

    my $user = $options{user} || $this->getArcturusUser() || return undef;

    my $userdatahash = &fetchUserPrivileges($this->getConnection(),user=>$user);

    unless ($userdatahash && keys %$userdatahash) {
        return 0 unless $options{list}; # no error message
        my $logger = &verifyLogger('verifyArcturusUser');
        $logger->error("user $user is unknown to Arcturus database " 
	              . ($this->getURL() || "VOID"));
        return 0;
    }

    return $user;
}

sub setAdminstrator {
    my $this = shift;
    my $user = shift || 'ejz';

    return 0 unless $this->verifyArcturusUser(user=>$user,list=>1); # failed

    $this->{DBA} = $user;

    return 1;
}

sub getAdministrator {
    my $this = shift;
 
   return $this->{DBA};
}

#-------------------------------------------------------------------------
# user privileges
#-------------------------------------------------------------------------

sub userCanLockProject {
    my $this = shift;

    my $privilege = &getPrivilegesForUser($this,shift); # port username, if any

    return ($privilege && $privilege->{lock_project})? 1 : 0;
}

sub userCanCreateProject {
    my $this = shift;

    my $privilege = &getPrivilegesForUser($this,shift); # port username, if any

    return ($privilege && $privilege->{create_project}) ? 1 : 0;
}

sub userCanAssignProject {
    my $this = shift;

    my $privilege = &getPrivilegesForUser($this,shift); # port username, if any

    return ($privilege && $privilege->{assign_project})? 1 : 0;
}

sub userCanGrantPrivilege {
    my $this = shift;

    my $privilege = &getPrivilegesForUser($this,shift); # port username, if any

    return ($privilege && $privilege->{grant_privileges}) ? 1 : 0;
}

sub userCanMoveAnyContig {
    my $this = shift;

    my $privilege = &getPrivilegesForUser($this,shift); # port username, if any

    return ($privilege && $privilege->{move_any_contig}) ? 1 : 0;
}

sub getPrivilegesForUser {
# return the privileges hash for the specified user or the default user
    my $this = shift;
    my $user = shift;
    my %options = @_;

    $user = $this->getArcturusUser() unless $user;

    my $privilege = $this->{privilege}->{$user};

    unless ($privilege && !$options{refresh}) {
        $privilege = &fetchUserPrivileges($this->getConnection(),user=>$user);
        $this->{privilege}->{$user} = $privilege;
    }

    return $privilege; # undef or a hash
}

sub getUserPrivileges {
# public; refreshes and returns a hash with all users and privileges
    my $this = shift;
    my $user = shift; # optional, may contain wild card symbol

    $this->{privilege} = &fetchUserPrivileges($this->getConnection,like=>$user);

    return $this->{privilege};
}

sub fetchUserPrivileges {
# private; returns a list of hashes with user privilege data keyed on user
    my $dbh = shift;
    my %option = @_; # either 'like' or 'user' or none

# first get all userdata from PRIVILEGE (also when user not in USER) 

    my $query = "select PRIVILEGE.username,privilege,role"
              . "  from PRIVILEGE left join USER using (username)";

# then add user data in USER with user not in PRIVILEGE

    my $union = "select USER.username,'NONE',role"
              . "  from USER left join PRIVILEGE using (username)"
	      . " where PRIVILEGE.username is null";
 
    my @bind;    
    if ($option{like}) { # allowing wild card
        $query .= " where PRIVILEGE.username like ?";
        $union .= "   and USER.username like ?";
	push @bind, $option{like},$option{like};
    }
    elsif ($option{user}) { # exact match
        $query .= " where PRIVILEGE.username = ?";
        $union .= "   and USER.username = ?";
        push @bind, $option{user},$option{user};
    }

    $query .= " union ".$union;

    my $sth = $dbh->prepare_cached($query);

    $sth->execute(@bind) || &queryFailed($query,@bind) && return undef;

    my $privilege_hash = {};
    while (my ($username,$privilege,$role) = $sth->fetchrow_array()) {
        $privilege = 'none' unless $privilege; # or null?
        $role      = 'none' unless $role; # 
        $privilege_hash->{$username} = {} unless $privilege_hash->{$username};
        $privilege_hash->{$username}->{$privilege} = $role;
    }

    $sth->finish();

    return $privilege_hash unless ($option{user}); # hash for all users

    return $privilege_hash->{ $option{user} } || {}; # sub hash for user
}

sub getRoleForUser {
# return the role for the specified user or the default user
    my $this = shift;
    my $user = shift;
    my %options = @_;

    my $privilege = $this->getPrivilegesForUser($user,%options);

    my ($dummy,$role) = each %$privilege; # the first pair

    return $role || 'none';
}

#-----------------------------------------------------------------------------
# user administration
#-----------------------------------------------------------------------------

sub addNewUser {
# add a new user to the USER table
    my $this = shift;
    my $user = shift;
    my $role = shift || 'finisher';

    return 0, "invalid role '$role' specified" unless defined &verifyUserRole($role);

# test privilege of the current arcturus user (both grant_privilege and seniority)

    my $privilege = $this->getPrivilegesForUser(); # of current Arcturus user
    my $userrole  = $privilege->{grant_privileges} || 0;
    my $seniority = &verifyUserRole($userrole);
# the current user can only allocate a role lower than or equal its own seniority 
    unless ($seniority && $seniority >= &verifyUserRole($role)) {
print STDERR "addNewUser seniority $seniority  role $role ". &verifyUserRole($role)."\n";
        return 0, "you do not have privilege for this operation";
    }

# test that the user does not exist by testing the current privileges 

    my $dbh = $this->getConnection();

    my $userprivilege = &fetchUserPrivileges($dbh,user=>$user);
    if (my @privileges = keys %$userprivilege) {
        my $currentrole = $userprivilege->{$privileges[0]};  
        return 0, "user '$user' already exists" if &verifyUserRole($currentrole);   
    }

# ok, $user is new and current Arcturus user can add to user administration

    my $query = "insert into USER (username,role) values (?,?)";

    my $sth = $dbh->prepare_cached($query);
    my $nrw = $sth->execute($user,$role) || &queryFailed($query,$user,$role);
    $sth->finish();

    return 1,"new user $user ($role) added" if ($nrw+0);    

    return 0,"failed to add user $user";        
}

sub updateUser {
# change role of user in the USER table
    my $this = shift;
    my $user = shift;
    my $role = shift || 'finisher';

    return 0, "invalid role '$role' specified" unless defined &verifyUserRole($role);

# test privilege of the current arcturus user (both grant_privilege and seniority)

    my $privilege = $this->getPrivilegesForUser(); # of current Arcturus user
    my $userrole  = $privilege->{grant_privileges} || 0;
    my $seniority = &verifyUserRole($userrole);
# the current user can only change a role lower than or equal its own seniority 
    unless ($seniority && $seniority >= &verifyUserRole($role)) {
print STDERR "updateUser seniority $seniority  role $role ". &verifyUserRole($role)."\n";
        return 0, "you do not have privilege for this operation";
    }

# test that the user does exist by testing the current privileges 

    my $dbh = $this->getConnection();

    my $userprivilege = &fetchUserPrivileges($dbh,user=>$user);
    if (my @privileges = keys %$userprivilege) {  
        my $currentrole = $userprivilege->{$privileges[0]};  
        unless (defined &verifyUserRole($currentrole)) {
# occurs when 'user' is absent from both USER and PRIVILEGE tables
            return 0, "user '$user' does not exist (1)";
        } 
        return 0, "user '$user' already has role $role" if ($currentrole eq $role);   
    }
    else {
        return 0, "user '$user' does not exist";
    }

# test the seniority of the current arcturus user 

    unless ($this->testUserRole($user,role=>$role,seniority=>1)) {
        return 0, "you do not have privilege for this operation";
    }

# ok, $user is new and current Arcturus user can make the change

    my $query = "update USER set role = ? where username = ?";

    my $sth = $dbh->prepare_cached($query);
    my $nrw = $sth->execute($role,$user) || &queryFailed($query,$role,$user);
    $sth->finish();

    return 1,"new role '$role' assigned to user $user" if ($nrw+0);    

    return 0,"failed to change role of user $user";        

}

sub addUserPrivilege {
# add the given privilege for the user
    my $this = shift;
    my ($user,$privilege) = @_;

    return 0, "missing parameters" unless ($user && $privilege);

    return 0, "invalid username provided" if ($user !~ /[\w\%\_]/); # if ($user =~ /\W/)

    unless (&verifyPrivilege($privilege)) {
        return 0, "Invalid privilege '$privilege' specified";
    }

# check if user privilege is already there

    my $dbh = $this->getConnection();

    my $currentprivilege = &fetchUserPrivileges($dbh,user=>$user);

    if ($currentprivilege->{$privilege}) {   
        return 0, "user '$user' already has privilege '$privilege'";   
    }

# test if the current user can do this operation

    unless ($this->userCanGrantPrivilege()) {
        return 0, "you do not have privilege for this operation";
    }

    unless ($this->testUserRole($user,privilege=>$privilege)) {
        return 0, "you do not have privilege for this operation";
    }

# either update an existing empty privilege, or insert a new row

    my ($query,$sth,$nrw);

    if ($currentprivilege->{none}) {
# there is 
        $query = "update PRIVILEGE set privilege = ?"
	       . " where privilege = '' and username in "
               . "(select username from USER where username = ?)";
        $sth = $dbh->prepare_cached($query);
        $nrw = $sth->execute($privilege,$user) || &queryFailed($query,$privilege,$user);
        $sth->finish();
    }

# insert a new row

    else {
        $query = "insert into PRIVILEGE (username,privilege) "
               . "select username, '$privilege' as privilege "
               . "  from USER where username = ?";
        $sth = $dbh->prepare_cached($query);
        $nrw = $sth->execute($user) || &queryFailed($query,$user);
        $sth->finish();
    }

    return 1, "privilege '$privilege' added for user '$user'" if ($nrw+0);

    return 0, "failed to add privilege '$privilege' for user '$user'";
}

sub removeUserPrivilege {
# remove the given privilege for the user
    my $this = shift;
    my $user = shift;
    my $privilege = shift;
    my %options = @_;

    return 0, "missing parameters" unless ($user && $privilege);

    return 0, "invalid username provided" if ($user !~ /[\w\%\_]/);

    unless ($privilege eq 'none' || &verifyPrivilege($privilege)) {
        return 0, "Invalid privilege '$privilege' specified";
    }

# get current privileges; check if user has privilege

    my $dbh = $this->getConnection();

    my $currentprivilege = &fetchUserPrivileges($dbh,user=>$user);

    unless ($currentprivilege->{$privilege}) {
        return 0, "user '$user' does not exist" unless keys %$currentprivilege;
        return 0, "user '$user' does not have privilege '$privilege'";
    }

# test if the current user can do this operation

    unless ($this->userCanGrantPrivilege()) {
        return 0, "you do not have privilege for this operation";
    }

    unless ($this->testUserRole($user,privilege=>$privilege,seniority=>1)) {
        return 0, "you do not have privilege for this operation";
    }

# check number of privileges left; can user be removed?

    my $remainder = scalar(keys %$currentprivilege) - 1;

    my $query;
    unless ($remainder && $options{force}) {
# update the record in order to keep the user name in the PRIVILEGE list, as it
# may occur elsewhere in the database; also no join with USER here required
        $query = "update PRIVILEGE set privilege = null"
               . " where username = ? and privilege = ?";
    }

    if ($remainder || $options{force}) {
# the privilege can be removed (at least one record for user will remain)
        $query = "delete from PRIVILEGE where username = ? and privilege = ?";
        $privilege = '' if ($privilege eq 'none');
    }

    my $sth = $dbh->prepare_cached($query);
    my $nrw = $sth->execute($user,$privilege) || &queryFailed($query,@_);
    $sth->finish();

    unless ($nrw+0) {
        return 0, "failed to (force) remove user '$user'" unless $privilege;
        return 0, "failed to remove user '$user'" if ($privilege eq 'none');
        return 0, "failed to remove privilege '$privilege' for user '$user'";
    }

    return 1, "privilege '$privilege' removed for user '$user'" if $privilege;
    return 1, "user '$user' removed" unless $privilege;
}

#---------------------------------------------------------------------------------

sub deleteUser {
# remove all privileges of user from USER table
    my $this = shift;
    my $user = shift;
    my %options = @_;

# get list of privileges

    my $dbh = $this->getConnection();

    my $userprivileges = &fetchUserPrivileges($dbh,user=>$user);

    return 0, "user '$user' does not exist" unless keys %$userprivileges;

    my $f = $options{force};

    my ($status,$msg);
    foreach my $privilege (keys %$userprivileges) {
       ($status,$msg) = $this->removeUserPrivilege($user,$privilege,force => $f);
        last unless $status;
    }

    return $status,$msg;
}

# testUserRole makes a decision about precedence of privilege when 
# two users are involved

sub testUserRole {
# test privileges of current arcturus user against input test user
# returns a 1 if the current user's privilege weighs stronger than 
# those of test user; e.g. a user with grant privilege can't count 
# less than a user who does not; the relative weight of users is 
# based on their role and highest level privilege
    my $this = shift;
    my $testuser = shift;
    my %options = @_;

# determine the "grade" or "role" of the current user

    my $thisusergrade = &getHighestPrivilege($this->getPrivilegesForUser($options{user}));

# (1) if privilege is specified, the current user should have at least that same privilege 

    if (my $privilege = $options{privilege}) {
# test the privilege specified against the privilege of the current user
        my $requiredgrade = &verifyPrivilege($privilege) || 0;

        if ($options{seniority}) {
# specifies that the grade of the current user should be larger than required grade
            return 0 unless ($thisusergrade > $requiredgrade);
        }
	else {
# specifies that the grade of the current user should at least equal required grade
            return 0 if ($thisusergrade < $requiredgrade);
	}
    }

# now test the current user's grade against the test user

    my $testusergrade = &getHighestPrivilege($this->getPrivilegesForUser($testuser));

    return 0 if ($thisusergrade < $testusergrade); # require at least equality


# (2) if role is specified, the current user should have at least that same role 


    my $thisuserrole = &verifyUserRole($this->getRoleForUser($options{user}));

    if (my $role = $options{role}) {
# test the role specified against the role of the current user
        my $requiredrole = &verifyUserRole($role) || 0;

        if ($options{seniority}) {
# specifies that the role of the current user should supersede the one of testuser
            return 0 unless ($thisuserrole > $requiredrole);
        }
        else {
# specifies that the role of the current user should at least equal the one of testuser
            return 0 if ($thisuserrole < $requiredrole);
        }
    }

# now test the current user's role against the one of the test user

    my $testuserrole = &verifyUserRole($this->getRoleForUser($testuser));

    return 0 if ($thisuserrole < $testuserrole); # require at least equality

    return 1;
}

sub getHighestPrivilege {
# private, helper method for testUserRole
    my $userhash = shift;

    my $privhash = &verifyPrivilege(); # get all valid privileges

    my $level = 0;
    foreach my $privilege (keys %$userhash) {
        next unless $privhash->{$privilege};
        $level = $privhash->{$privilege} if ($privhash->{$privilege} > $level);
    }

    return $level;    
}

#--------------------------------------------------------------------------------
# current privileges and user roles
#--------------------------------------------------------------------------------

sub getValidPrivileges {
    return &verifyPrivilege();
}

sub verifyPrivilege {
    my $privilege = shift;

    my %privileges = ('create_project'   => 2,'assign_project'  => 3,
                      'grant_privileges' => 4,'move_any_contig' => 1,
                      'lock_project'     => 1);

    return $privileges{$privilege} if defined($privilege); # return true or false

    return \%privileges; # return hash reference
}

sub getValidUserRoles {
    return &verifyUserRole();
}

sub verifyUserRole {
    my $userrole = shift;

    my %userroles = ('annotator'   => 0, 'finisher'      => 1,
                     'team leader' => 3, 'administrator' => 4,
                     'superuser'   => 5, 'none'          => 0); # space for more

    return $userroles{lc($userrole)} if defined($userrole); # return seniority

    return \%userroles; # return hash reference
}

#-----------------------------------------------------------------------------
# a rudimentary messaging system
#-----------------------------------------------------------------------------

my $MAIL = []; # class variable

sub logMessage {
    my $this = shift;
    my $user = shift;    # addressee
    my $project = shift; # project name
    my $text = shift;    # the message

my $logger = &verifyLogger('logMessage');
$logger->debug("message for user $user: $text");

    push @$MAIL, [($user,$project,$text)]; # array of arrays
}

sub getMessageAddresses {
# returns a list of addressees
    my $this = shift;

    @$MAIL = sort {$a->[1] cmp $b->[1]} @$MAIL if shift; # order by project

    my %users;
    
    foreach my $entry (@$MAIL) {
        $users{$entry->[0]}++;
    }

    my @users = keys %users;

    return \@users;
}

sub getMessageForUser {
# collates all messages for the given user
    my $this = shift;
    my $user = shift || return undef;

    @$MAIL = sort {$a->[1] cmp $b->[1]} @$MAIL if shift; # order by project

    my $message = '';

    foreach my $entry (@$MAIL) {
	next unless ($entry->[0] eq $user);
        $message .= $entry->[2] . "\n";
    }

    return $message;
}

sub getMessage {
# returns the next message (to be processed by calling script)
    my $this = shift;

    return 0 unless @$MAIL;

    return shift @$MAIL; # array ref (user, project, text)
}
    
#-----------------------------------------------------------------------------

sub logQuery {
# keep a query log for debugging purposes
    my $this = shift;
    my @entry = @_;

# each entry consists of: subroutine of origin, query and possibly @data

    $this->{querylog} = [] unless $this->{querylog};

    my $log = $this->{querylog};

    unless (@entry >= 2) { # retrieval mode
        my $logentry = $entry[0] || scalar(@$log) || 1; # default most recent
        $logentry = $log->[$logentry-1]; # the query data
        return undef unless $logentry;
        @entry = @$logentry;
#        $entry[1] =~ s/(\s*(where|from|and|order|group))/\n         $1/gi;
        my $output = "method : $entry[0]\nquery  : $entry[1]\n";
        splice @entry,0,2;
# if any data given, substitute wildcards
        my $length = length(@entry); 
        while ($length-- > 0) {
            my $datum = shift @entry || 'null';
            $datum = "'$datum'" if ($datum =~ /\D/);
            $output =~ s/\?/$datum/;
        }
 	return $output;
    }

    push @$log, [@entry]; # build array of arrays
}

#-----------------------------------------------------------------------------
# log file
#-----------------------------------------------------------------------------

my $LOGGER; # class variable

sub verifyLogger {
# test the logging unit; if not found, build a default logging module
    my $this = shift;
    my $prefix = shift;

    if ($LOGGER && ref($LOGGER) eq 'Logging') {

        $LOGGER->setPrefix($prefix) if defined($prefix);

        return $LOGGER; 
    }

# no (valid) logging unit is defined, create a default object

    $LOGGER = new Logging();

    $prefix = 'ArcturusDatabase' unless defined($prefix);

    $LOGGER->setPrefix($prefix);

    return $LOGGER;
}

sub setLogger {
# assign a Logging object 
    my $this = shift;
    my $logger = shift;

    return if ($logger && ref($logger) ne 'Logging'); # protection

    $LOGGER = $logger;

    &verifyLogger(); # creates a default if $logger undefined
}

#-----------------------------------------------------------------------------

1;