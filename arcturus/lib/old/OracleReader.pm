package OracleReader;

#############################################################################
#
# Read a standard Sanger format READ from the Oracle database
# Hacked from the ADB_get_caf script by Robert Davies
# $Id: OracleReader.pm,v 1.1 2002-11-21 16:26:33 ejz Exp $
#
#############################################################################

use strict;

#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
#require Exporter;
#@ISA = qw(Exporter);
#@EXPORT = qw();
#@EXPORT_OK = qw();

use lib '/usr/local/badger/bin','/nfs/disk100/pubseq/PerlModules/Modules';

use Caftools;
use AssemblyDB2;

#############################################################################

my $schema;   # see description of ADB_get_caf 
my $project;  # see description of ADB_get_caf

my %readHash; # hash of hash references to retrieved reads 

my $ADB_DIR = "/nfs/disk222/yeastpub/scripts/WGSassembly/bin";

#############################################################################

sub new {
# constructor for Oracle reader from specified schema & project
   my $prototype = shift;
   my $inschema  = shift;
   my $inproject = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $schema   = $inschema;
   $project  = $inproject;
   $self->{schema}  = $schema;
   $self->{project} = $project;
   $self->{reads}   = {};# hash of hash references to retrieved reads 

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
#print "schema $schema  project $project <br>\n";
#print "files @{$files} <br>\n";

    undef my $readHash;
    $self->{reads} = \%readHash;

# translate readnames into hash

    undef my %reads;
    foreach my $file (@$files) {
        $reads{$file} = 1;
    }
    
    my $ignore = 0;

# access the Oracle database

    my $adb = AssemblyDB->new(login => 'pathlook',schema => $schema);

# retrieve the reads and store as hashes under the $caf handle

    undef my $caf;
    if ($project =~ /^\d+$/) {

#print "enter caf <br>";
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
#	delay_finishing => $opts{delay_finishing},
	    delay_finishing => 1,
        });
    
    }

# retrieve a list of files actually read and the corresponding hashes

    undef my $number;
    my @reads = $caf->readsList();
#print "test: @reads<BR>\n";
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

    print "get new ORACLE read $file\n";

    unlink "/nfs/darth/ejz/tmpfofn.lis" if (-e "/nfs/darth/ejz/tmpfofn.lis");
    open FOFN,'> /nfs/darth/ejz/tmpfofn.lis' or die "cannot open tmpfofn.lis";
    print FOFN "$file\n"; # write the file name to FOFN
    close (FOFN); 

    my $image = `$ADB_DIR/ADB_get_caf -fofn /nfs/darth/ejz/tmpfofn.lis $schema $project`;
    print "$image\n";
}

#############################################################################

1;
