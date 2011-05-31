#!/usr/local/bin/perl
#check-last-import

use strict;

use ArcturusDatabase;
use DBI;
use DataSource;
use RepositoryManager;

my $testing = 0;
my $since;
my $hideidle = 0;
my $gap_version = 0;

my $instance;
my $organism;
my $projectname;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-instance') {
	$instance = shift @ARGV;
    } elsif ($nextword eq '-organism') {
	$organism = shift @ARGV;
    } elsif ($nextword eq '-since') {
	$since = shift;
    } elsif ($nextword eq '-gap4') {
	$gap_version = 4;
    } elsif ($nextword eq '-gap5') {
	$gap_version = 5;
    } elsif ($nextword eq '-project') {
	$projectname = shift @ARGV;
    } elsif ($nextword eq '-help') {
	&showUsage();
	exit(0);
    } else {
	die "Unknown option: $nextword";
    }
}

#------------------------------------------------------------------------------
# Check input parameters
#------------------------------------------------------------------------------

unless (defined($instance)) {
    &showUsage("No instance name specified");
    exit 1;
 }
 
unless (defined($organism)) {
     &showUsage("No organism name specified");
 exit 1;
 }
 
 unless (defined($projectname)) {
     &showUsage("No project name specified");
     exit 1;
	}
 
 unless ($gap_version > 0) {
     &showUsage("You must specify either -gap4 or -gap5");
     exit 1;
 }


$since = 5 unless (defined($since) && $since =~ /^\d+$/);

#------------------------------------------------------------------------------
# get a Project instance to check what has been given as the -project input
#------------------------------------------------------------------------------
 
my $adb = new ArcturusDatabase (-instance => $instance,
                     -organism => $organism);
 
if (!$adb || $adb->errorStatus()) {
      &showUsage("Invalid organism '$organism' on instance '$instance'");
      exit 2;
}
 
my ($projects,$msg);
 
if ($projectname =~ /\D/) {
    ($projects,$msg) = $adb->getProject(projectname=>$projectname);
}
else {
    ($projects,$msg) = $adb->getProject(project_id=>$projectname);
}
 
die "Failed to find project $projectname"
     unless (defined($projects) && ref($projects) eq 'ARRAY' && scalar(@{$projects}) > 0);
 
my $dbh = $adb->getConnection();

if ($testing) {
	printf "Looking for data for project $projectname for the last $since days...\n";
}

printf "%-10s %10s    %15s           %20s           %20s %18s\n", 'USERNAME', 'PROJECT', 'ACTION', 'FILE', 'STARTTIME', 'ENDTIME';

my $query = "select username, name, action, file, starttime, endtime 
	from IMPORTEXPORT, PROJECT 
	where IMPORTEXPORT.project_id = PROJECT.project_id 
	and name = '$projectname' 
	and starttime > date_sub(now(), interval $since day)
	order by starttime";

my $sth = $dbh->prepare($query);
$sth->execute();

if ($testing) {
print STDERR "\nRunning query $query\n";
}

while( my ($username, $project, $action, $file, $starttime, $endtime) = $sth->fetchrow_array()) {
	printf "%-10s %10s %15s %50s %20s %20s\n", $username, $project, $action, $file, $starttime, $endtime;
}

$sth->finish();
$dbh->disconnect();

exit(0);

sub showUsage {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\t-instance\t\tThe LDAP isntance which lists the MySQL instance name\n";
    print STDERR "\t-organism\t\tThe organism name that holds the project\n";
    print STDERR "\t-project\t\tThe project to check imports and exports for\n";
    print STDERR "\t-gap4 OR -gap5\t\tOne of 4 or 5\n";
    print STDERR "\n";

    print STDERR "OPTIONAL PARAMETERS:\n";

    print STDERR "\t-since\t\tNumber of days before present for import/export summary [default: 5]\n";

}
