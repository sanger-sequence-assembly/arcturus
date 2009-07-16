#!/usr/local/bin/perl

use strict;

use DBI;

my $host;
my $port;
my $dbname;
my $username;
my $password;

my $constraints =
    [
     [0, "READINFO", "template_id", "TEMPLATE", "template_id"],
     [0, "TEMPLATE", "ligation_id", "LIGATION", "ligation_id"],
     [0, "LIGATION", "clone_id", "CLONE", "clone_id"],

     [0, "CLONE", "assembly_id", "ASSEMBLY", "assembly_id"],

     [0, "LIGATION", "svector_id", "SEQUENCEVECTOR", "svector_id"],

     [0, "READINFO", "status", "STATUS", "status_id"],
     [0, "READINFO", "basecaller", "BASECALLER", "basecaller_id"],

     [0, "CONTIGTAG", "tag_seq_id", "TAGSEQUENCE", "tag_seq_id"],
     [0, "READTAG", "tag_seq_id", "TAGSEQUENCE", "tag_seq_id"],

     [0, "ASSEMBLY", "creator", "USER", "username"],

     [0, "PROJECT", "creator", "USER", "username"],
     [0, "PROJECT", "owner", "USER", "username"],
     [0, "PROJECT", "lockowner", "USER", "username"],

     [0, "CONTIGTRANSFERREQUEST", "requester", "USER", "username"],
     [0, "CONTIGTRANSFERREQUEST", "reviewer", "USER", "username"],

     [0, "SCAFFOLD", "creator", "USER", "username"],
     ];

my $opts;

while (my $nextword = shift @ARGV) {
    if ($nextword eq '-host') {
	$host = shift @ARGV;
    } elsif ($nextword eq '-port') {
	$port = shift @ARGV;
    } elsif ($nextword eq '-db') {
	$dbname = shift @ARGV;
    } elsif ($nextword eq '-username') {
	$username = shift @ARGV;
    } elsif ($nextword eq '-password') {
	$password = shift @ARGV;
    } elsif ($nextword eq '-verbose') {
	$opts->{Verbose} = 1;
    } elsif ($nextword eq '-deleteorphans') {
	$opts->{DeleteOrphans} = 1;
    } elsif ($nextword eq '-createfk') {
	$opts->{CreateFK} = 1;
    } elsif ($nextword eq '-help') {
	&showHelp();
	exit(0);
    } else {
	die "Unknown option: $nextword";
    }
}

$username = $ENV{'MYSQL_USERNAME'} unless defined($username);
$password = $ENV{'MYSQL_PASSWORD'} unless defined($password);

unless (defined($host) && defined($port) && defined($dbname) &&
	defined($username) && defined($password)) {
    &showHelp("One or more mandatory options were missing");
    exit(1);
}

my $url = "DBI:mysql:$dbname;host=$host;port=$port";

my $dbh = DBI->connect($url, $username, $password, { RaiseError => 1 , PrintError => 0});

&addForeignKeyConstraints($dbh, $opts, $constraints);

$dbh->disconnect();

exit(0);

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tHost\n";
    print STDERR "\t-port\t\tPort\n";
    print STDERR "\t-db\t\tDatabase\n";
    print STDERR "\t-username\tUsername to connect to server (or setenv MYSQL_USERNAME)\n";
    print STDERR "\t-password\tPassword to connect to server (or setenv MYSQL_PASSWORD)\n";

    print STDERR "\n";

    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\t-verbose\tRun in verbose mode\n";
    print STDERR "\t-deleteorphans\tDelete orphan rows where possible\n";
    print STDERR "\t-createfk\tCreate the foreign key constraints\n";
}

sub addForeignKeyConstraints {
    my $dbh = shift;

    my $opts = shift;

    my $constraints = shift;

    my $verbose = defined($opts) && $opts->{Verbose};

    my $createfk = defined($opts) && $opts->{CreateFK};

    my $deleteorphans = defined($opts) && $opts->{DeleteOrphans};

    my $with_orphans = 0;

    foreach my $constraint (@{$constraints}) {
	my ($autofix,$table,$column,$fk_table,$fk_column,$delete_op,$update_op) = @{$constraint};

	$delete_op = "RESTRICT" unless defined($delete_op);
	$update_op = "RESTRICT" unless defined($update_op);

	print STDERR "\n$table.$column --> $fk_table.$fk_column";

	my $query = "select count(*) from $table left join $fk_table " .
	    " on ($table.$column = $fk_table.$fk_column)" .
	    " where $fk_table.$fk_column is null and $table.$column is not null";

	my $sth = $dbh->prepare($query);

	$sth->execute();

	my ($orphanrows) = $sth->fetchrow_array();

	$sth->finish();

	if ($orphanrows > 0) {
	    print STDERR " has $orphanrows orphan rows",
	    " [autofix ",($autofix ? "is" : "NOT"), " possible]\n";

	    $query = "select is_nullable from information_schema.columns" .
		" where table_schema = database() and table_name = ? and column_name = ?";

	    $sth = $dbh->prepare($query);
	    $sth->execute($table, $column);

	    my ($nullable) = $sth->fetchrow_array();

	    $sth->finish();

	    my $colname = "$table.$column" . ($nullable eq 'NO' ? " [NOT NULLABLE]" : "");

	    printf STDERR "%-40s %8s\n",$colname,"COUNT";

	    $query = "select $table.$column,count(*) as hits from $table left join $fk_table " .
		" on ($table.$column = $fk_table.$fk_column) where $fk_table.$fk_column is null" .
		" and $table.$column is not null group by $table.$column order by hits desc";

	    $sth = $dbh->prepare($query);
	    $sth->execute();

	    while (my ($badvalue,$hits) = $sth->fetchrow_array()) {
		printf STDERR "%-40s %8d\n",$badvalue,$hits;
	    }

	    $sth->finish();

	    if ($deleteorphans) {
		if ($autofix) {
		    $query = "delete $table from $table left join $fk_table " .
			" on ($table.$column = $fk_table.$fk_column) where $fk_table.$fk_column is null";

		    my $rc = $dbh->do($query);

		    print STDERR "***** $rc orphan rows were deleted. *****\n";
		} else {
		    print STDERR "***** This problem CANNOT be fixed automatically. *****\n";
		    $with_orphans++;
		}
	    } else {
		$with_orphans++;
	    }
	} else {
	    print STDERR " OK.\n";
	}
    }

    if ($with_orphans > 0) {
	print STDERR "*******************************************************\n";
	print STDERR "ONE OR MORE CHILD TABLES HAVE ORPHAN ROWS.\n";
	print STDERR "THIS WILL CAUSE FOREIGN KEY CONSTRAINTS TO BE VIOLATED.\n";
	print STDERR "PLEASE FIX THESE PROBLEMS, THEN RE-RUN THIS SCRIPT.\n";
	print STDERR "*******************************************************\n";
	return;
    }

    if ($createfk) {
	foreach my $constraint (@{$constraints}) {
	    my ($autofix,$table,$column,$fk_table,$fk_column,$delete_op,$update_op) = @{$constraint};
	
	    $delete_op = "RESTRICT" unless defined($delete_op);
	    $update_op = "RESTRICT" unless defined($update_op);

	    my $query = "alter table $table add constraint foreign key ($column)" .
		" references $fk_table ($fk_column)" .
		" on delete $delete_op" .
		" on update $update_op";

	    print STDERR "Executing: $query\n";

	    my $rc = $dbh->do($query);
	}
    }
}
