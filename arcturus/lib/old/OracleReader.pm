package OracleReader;

#############################################################################
#
# Read a standard Sanger format READ from the Oracle database
# Hacked from the ADB_get_caf script by Robert Davies
# $Id: OracleReader.pm,v 1.4 2003-09-10 15:19:12 ejz Exp $
#
#############################################################################

use strict;

#use lib '/usr/local/badger/bin','/nfs/disk100/pubseq/PerlModules/Modules';

use Caftools;
use AssemblyDB2;

#############################################################################

#my $ADB_DIR = "/nfs/disk222/yeastpub/scripts/WGSassembly/bin";
my $ADB_DIR = "/nfs/pathsoft/prod/WGSassembly/bin";

my $TMP_DIR = "/tmp";

#############################################################################

sub new {
# constructor for Oracle reader from specified schema & project
   my $prototype = shift;
   my $schema    = shift;
   my $project   = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $self->{schema}  = $schema;
   $self->{project} = $project;
   $self->{reads}   = {};# hash of hash references to retrieved reads 
   $self->{status}  = '';

   bless ($self, $class);
   return $self;
}

#############################################################################

sub getOracleReads {
# read files in input list from Oracle database and store hashes
    my $self  = shift;
    my $files = shift; # ref to array of read names

    my $schema  = $self->{schema};
    my $project = $self->{project};

    undef my %readHash;
    $self->{reads} = \%readHash;
# translate readnames into hash

    undef my %reads;
    foreach my $file (@$files) {
        $reads{$file} = 1;
    }
    
    my $ignore = 0;

# access the Oracle database

    my $adb = AssemblyDB->new(login => 'pathlook', schema => $schema, RaiseError => 0);
    if (!$adb) {
        $self->{status} = "Unknown SCHEMA $schema"; print "$self->{status} <br>";
        return 0;
    }

# retrieve the reads and store as hashes under the $caf handle

    undef my $caf;
    if ($project =~ /^\d+$/) {

        $caf = $adb->get_caf({
	    projid => $project,
	    fofn => \%reads,
	    ignore => $ignore,
	    delay_finishing => 1,
        });

    } else {
    
        $caf = $adb->get_caf({
	    project => $project,
	    fofn => \%reads,
	    ignore => $ignore,
	    delay_finishing => 1,
        });
    
    }

# retrieve a list of files actually read and the corresponding hashes

    undef my $number;
    my @reads = $caf->readsList();
    foreach my $read (@reads) {
        $readHash{$read} = $caf->getEntry($read);
        $number++;
    }

    undef @reads;

    return $number;
}

#############################################################################

sub readHash {
# retrieve hash reference for requested read
    my $self = shift;
    my $read = shift;

    return $self->{reads}->{$read};
}

#############################################################################

sub getOracleRead {
# adhoc version: reads a Read file from Oracle database using ADB_get_caf commmand
    my $self = shift;
    my $file = shift;

    my $schema  = $self->{schema};
    my $project = $self->{project};

    print "<br>get new ORACLE read $file\n";

    unlink "$TMP_DIR/tmpfofn.lis" if (-e "$TMP_DIR/tmpfofn.lis");
    open FOFN,'> $TMP_DIR/tmpfofn.lis' or die "cannot open tmpfofn.lis";
    print FOFN "$file\n"; # write the file name to FOFN
    close (FOFN); 

    my $image = `$ADB_DIR/ADB_get_caf -fofn $TMP_DIR/tmpfofn.lis $schema $project`;
}

#############################################################################

1;
