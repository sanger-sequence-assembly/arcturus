#!/usr/local/bin/perl

use strict;

use DBI;

my $host;
my $port;
my $dbname;
my $username;
my $password;
my $fix = 0;

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
    } elsif ($nextword eq '-fix') {
	$fix = 1;
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

foreach my $constraint (@{$constraints}) {
    my ($autofix,$table,$column,$fk_table,$fk_column,$delete_op,$update_op) = @{$constraint};
    
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

	if ($fix && $autofix) {
	    $query = "delete $table from $table left join $fk_table " .
		" on ($table.$column = $fk_table.$fk_column) where $fk_table.$fk_column is null";
	    
	    my $rc = $dbh->do($query);
		
	    print STDERR "***** $rc orphan rows were deleted. *****\n";
	}
    } else {
	print STDERR " OK.\n";
    }
}

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
}
