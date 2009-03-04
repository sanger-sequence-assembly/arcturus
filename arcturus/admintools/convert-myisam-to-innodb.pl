#!/usr/local/bin/perl

use strict;

use DBI;

my $host;
my $port;
my $dbname;
my $username;
my $password;
my $skipconvert = 0;
my $skipfk = 0;

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
    } elsif ($nextword eq '-skipfk') {
	$skipfk = 1;
    } elsif ($nextword eq '-skipconvert') {
	$skipconvert = 1;
    } elsif ($nextword eq '-verbose') {
	$opts->{Verbose} = 1;
    } elsif ($nextword eq '-deleteorphans') {
	$opts->{DeleteOrphans} = 1;
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

my $arcturusPrivileges = 
    "SELECT, INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE";

&revokeArcturusPrivileges($dbh, $dbname, $arcturusPrivileges);

&convertMyISAMTablesToInnoDB($dbh, $opts) unless $skipconvert;

&addForeignKeyConstraints($dbh, $opts) unless $skipfk;

&grantArcturusPrivileges($dbh, $dbname, $arcturusPrivileges);

$dbh->disconnect();

exit(0);

sub showHelp {
    my $msg = shift;

    print STDERR $msg,"\n\n" if (defined($msg));

    print STDERR "MANDATORY PARAMETERS:\n";

    print STDERR "\t-host\t\tHost\n";
    print STDERR "\t-port\t\tPort\n";
    print STDERR "\t-db\t\tDatabase\n";
    print STDERR "\t-username\tUsername to connect to server\n";
    print STDERR "\t-password\tPassword to connect to server\n";

    print STDERR "\n";

    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\t-verbose\tRun in verbose mode\n";
    print STDERR "\t-skipconvert\tDo not convert MyISAM tables to InnoDB\n";
    print STDERR "\t-skipfk\t\tDo not add foreign key constraints\n";
    print STDERR "\t-deleteorphans\tDelete orphan rows where possible\n";
}

sub convertMyISAMTablesToInnoDB {
    my $dbh = shift;

    my $query = "select table_name,table_rows from information_schema.tables" .
	" where table_schema = ? and table_type = 'BASE TABLE' and engine = 'MyISAM'";

    my $sth = $dbh->prepare($query);

    $sth->execute($dbname);

    my %tables;

    while (my ($table_name, $table_rows) = $sth->fetchrow_array()) {
	$tables{$table_name} = $table_rows;
    }

    $sth->finish();

    foreach my $table_name (sort keys %tables) {
	my $table_rows = $tables{$table_name};
	print STDERR "Converting $table_name ($table_rows rows) ...";

	$query = "alter table $table_name engine = InnoDB";

	my $rc = $dbh->do($query);

	print STDERR " Done.\n";
    }
}

sub addForeignKeyConstraints {
    my $dbh = shift;

    my $opts = shift;

    my $verbose = defined($opts) && $opts->{Verbose};

    my $deleteorphans = defined($opts) && $opts->{DeleteOrphans};

    my $constraints = 
	[
	 [0,"PROJECT","assembly_id","ASSEMBLY","assembly_id"],

	 [1,"C2CMAPPING","contig_id","CONTIG","contig_id","CASCADE"],
	 [1,"C2CMAPPING","parent_id","CONTIG","contig_id"],
	 [1,"CONSENSUS","contig_id","CONTIG","contig_id","CASCADE"],
	 [1,"CONTIGORDER","contig_id","CONTIG","contig_id","CASCADE"],
	 [1,"CONTIGTRANSFERREQUEST","contig_id","CONTIG","contig_id","CASCADE"],
	 [1,"MAPPING","contig_id","CONTIG","contig_id","CASCADE"],
	 [1,"TAG2CONTIG","contig_id","CONTIG","contig_id","CASCADE"],

	 [0,"SCAFFOLD","import_id","IMPORTEXPORT","id"],

	 [1,"C2CSEGMENT","mapping_id","C2CMAPPING","mapping_id","CASCADE"],

	 [0,"CLONEVEC","cvector_id","CLONINGVECTOR","cvector_id"],
	 [0,"SEQVEC","svector_id","SEQUENCEVECTOR","svector_id"],

	 [0,"CONTIGTRANSFERREQUEST","old_project_id","PROJECT","project_id","RESTRICT","CASCADE"],
	 [0,"CONTIGTRANSFERREQUEST","new_project_id","PROJECT","project_id","RESTRICT","CASCADE"],
	 [0,"CONTIG","project_id","PROJECT","project_id","RESTRICT","CASCADE"],

	 [1,"READCOMMENT","read_id","READINFO","read_id","CASCADE"],
	 [1,"SEQ2READ","read_id","READINFO","read_id","CASCADE"],
	 [1,"TRACEARCHIVE","read_id","READINFO","read_id","CASCADE"],

	 [1,"CONTIGORDER","scaffold_id","SCAFFOLD","scaffold_id","CASCADE"],

	 [1,"ALIGN2SCF","seq_id","SEQUENCE","seq_id","CASCADE"],
	 [1,"CLONEVEC","seq_id","SEQUENCE","seq_id","CASCADE"],
	 [1,"MAPPING","seq_id","SEQUENCE","seq_id"],
	 [1,"QUALITYCLIP","seq_id","SEQUENCE","seq_id","CASCADE"],
	 [1,"READTAG","seq_id","SEQUENCE","seq_id","CASCADE"],
	 [1,"SEQ2READ","seq_id","SEQUENCE","seq_id","CASCADE"],
	 [1,"SEQVEC","seq_id","SEQUENCE","seq_id","CASCADE"],

	 [1,"SEGMENT","mapping_id","MAPPING","mapping_id","CASCADE"],

	 [1,"TAG2CONTIG","tag_id","CONTIGTAG","tag_id","CASCADE"],

	 [0,"SCAFFOLD","type_id","SCAFFOLDTYPE","type_id"]
	 ];

    my $with_orphans = 0;

    foreach my $constraint (@{$constraints}) {
	my ($autofix,$table,$column,$fk_table,$fk_column,$delete_op,$update_op) = @{$constraint};

	$delete_op = "RESTRICT" unless defined($delete_op);
	$update_op = "RESTRICT" unless defined($update_op);

	print STDERR "\n$table.$column --> $fk_table.$fk_column";

	my $query = "select count(*) from $table left join $fk_table " .
	    " on ($table.$column = $fk_table.$fk_column) where $fk_table.$fk_column is null";

	my $sth = $dbh->prepare($query);

	$sth->execute();

	my ($orphanrows) = $sth->fetchrow_array();

	$sth->finish();

	if ($orphanrows > 0) {
	    print STDERR " has $orphanrows orphan rows",
	    " [autofix ",($autofix ? "is" : "NOT"), " possible]\n";

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

sub revokeArcturusPrivileges {
    my $dbh = shift;
    my $dbname= shift;
    my $privileges = shift;

    print STDERR "Revoking privileges from arcturus ...";

    my $query = "revoke $privileges on \`$dbname\`.* from 'arcturus'\@'\%'";

    $dbh->do($query);

    print STDERR " Done.\n";
}

sub grantArcturusPrivileges {
    my $dbh = shift;
    my $dbname= shift;
    my $privileges = shift;

    print STDERR "Granting privileges to arcturus ...";

    my $query = "grant $privileges on \`$dbname\`.* to 'arcturus'\@'\%'";

    $dbh->do($query);

    print STDERR " Done.\n";
}
