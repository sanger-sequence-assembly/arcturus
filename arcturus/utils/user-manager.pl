#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

require Mail::Send;

#----------------------------------------------------------------

my $organism;
my $instance;

my $user;
my $privilege;

my $force;
my $verbose;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $validKeys = "organism|o|instance|i|"
              . "addprivilege|ap|removeprivilege|rp|deleteuser|du|force|"
              . "user|privilege|list|"
              . "verbose|help";
 
my $action = 0;

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
 

    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance  = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism  = shift @ARGV;
    }

    if ($nextword eq '-ap' || $nextword eq '-addprivilege') {
        $privilege = shift @ARGV;
        $action    = 1;
    }
    if ($nextword eq '-rp' || $nextword eq '-removeprivilege') {
        $privilege = shift @ARGV;
        $action    = 2;
    }

    if ($nextword eq '-du' || $nextword eq '-deleteuser') {
        $user      = shift @ARGV;
        $action    = 3;
    }

    $action        = 0            if ($nextword eq '-list');

    $user          = shift @ARGV  if ($nextword eq '-user');

    $privilege     = shift @ARGV  if ($nextword eq '-privilege');

    $force         = 1            if ($nextword eq '-force');

    $verbose       = 1            if ($nextword eq '-verbose');

    &showUsage(0) if ($nextword eq '-help'); # long write up
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# test input parameters
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing user specification") if ($action && !$user);

if (($action == 1 || $action == 2) && !$privilege) {
    &showUsage("Missing privilege specification");
}

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# translate possibly abbreviated privilege specification by full
#----------------------------------------------------------------

if ($privilege) {
# get the current set of valid privileges
    my $privileges = $adb->getValidPrivileges(); # returns a hash

    my %shortforms;
    foreach my $privilege (keys %$privileges) {
        my $shortform = $privilege;
        $shortform =~ s/(_[^_])[^_]+/$1/g;
        $shortform =~ s/([^_])[^_]+_/$1/g;
        $shortform =~ s/_//g;
        next unless $shortform;
        $shortform = $privilege if $shortforms{$shortform}; # duplicate
        $shortforms{$shortform} = $privilege;
    }

    $privilege = $shortforms{$privilege} || $privilege;

    if ($privilege && !$privileges->{$privilege}) {
        unless ($privilege =~ /help|\?/) {
            $logger->severe("Invalid privilege '$privilege' specified",preskip=>1);
	}
        $logger->warning("Valid privileges:",skip=>1,preskip=>1);
        foreach my $shortform (sort keys %shortforms) {
            my $privilege = $shortforms{$shortform};
            my $field = sprintf ("%-20s",$privilege)." ($shortform)";
            $logger->warning($field);
        }
        $logger->warning("end list",preskip=>1,skip=>2);     
    }
}

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my ($status,$msg);

my $success = 0;

if (!$action) {
# list current user privilege(s)
    my $list;
    if ($user =~ /[\%\_]/) {
        $list = $adb->getUserPrivileges($user);
        undef $user;
    }
    else {
        $list = $adb->getUserPrivileges();
    }

    if (ref($list) eq 'HASH') {
        my $header = "  user         privileges";
        my $head;
        foreach my $entry (sort keys %$list) {
            next if ($user && $entry !~ /$user/);           
            my $privileges = $list->{$entry};
            my %options = (nobreak=>1,preskip=>1);
            my $usertext = sprintf("%-8s",$entry)."     ";
            my $text;
            foreach my $userprivilege (sort keys %$privileges) {
                next if ($privilege && $userprivilege ne $privilege);
                $logger->warning($header,preskip=>1) unless $head;
                $logger->warning($usertext,%options) unless $text;
                $logger->warning(sprintf("%-24s",$userprivilege));
                $logger->warning("             ",nobreak=>1);
                $head = 1;
		$text = 1;
            }
            $success++;
        }
        $logger->warning("end list",preskip=>1) if $head;
    }

    unless ($success) {
        my $target = ($user ? "like '$user' " : "");
        $msg = "no users ${target}were found for database "
             . "'$organism' on instance '$instance'";
    }
}

# the other options require user to be defined

elsif ($action >= 1 && $action <= 3) {

    if ($action == 1 && $user && $privilege) {
# add new user privilege; requires both user and privilege to be defined
       ($status,$msg) = $adb->addUserPrivilege($user,$privilege);
        $success = 1 if $status;
    }

    elsif ($action == 2 && $user && $privilege) {
# delete a privilege for a user; requires both user and privilege to be defined
       ($status,$msg) = $adb->removeUserPrivilege($user,$privilege);
        $success = 1 if $status;
    }

    elsif ($action == 3 && $user) {
# delete a user; without force a record is left to keep user in database
       ($status,$msg) = $adb->deleteUser($user,force=>$force);
        $success = 1 if $status;
    }

    elsif ($privilege) {
# implies user undefined
        $msg = "Missing user name";
    }

    else {
# implies missing privilege specification
        $msg = "Missing privilege";
    }
}

if ($success) {
    $logger->severe($msg,preskip=>1,skip=>1);    
}
else {
    $msg .= " (".($adb->errorStatus(1) || "no database errors").")";
    $logger->severe($msg,preskip=>1,skip=>1);       
}

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n"  unless $organism;
        print STDERR "-instance\tMySQL database instance\n" unless $instance;
    }
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-list\t\t (no value) show the current user privileges\n";
    print STDERR "\n";
    print STDERR "-user\t\t username to be processed\n";
    print STDERR "\t\t adding or removing privilege require user to be defined\n";
    print STDERR "-addprivilege\t (ap)add the specified privilege\n";
    print STDERR "-removeprivilege (rp)remove the specified privilege\n";
    print STDERR "\n";
    print STDERR "-deleteuser\t (du) delete all privileges of the user specified\n";
    print STDERR "-force\t\t (with 'deleteuser') removes the user from database\n";
    print STDERR "\n";
    print STDERR "-verbose\t (no value)\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

