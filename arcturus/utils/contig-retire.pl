#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use FileHandle;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig;
my $verbose;
my $confirm;
my $focn;

my $validKeys  = "organism|instance|contig|focn|verbose|confirm|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                         
# the next die statement prevents redefinition when used with e.g. a wrapper script

    die "You can't re-define instance" if ($instance && $nextword eq '-instance');
 
    $instance     = shift @ARGV  if ($nextword eq '-instance');

    die "You can't re-define organism" if ($organism && $nextword eq '-organism');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $contig       = shift @ARGV  if ($nextword eq '-contig');

    $focn         = shift @ARGV  if ($nextword eq '-focn');

    $verbose      = 1            if ($nextword eq '-verbose');

    $confirm      = 1            if ($nextword eq '-confirm');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing contig identifier or focn") unless ($contig || $focn);

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# get the contig(s)
#----------------------------------------------------------------

my $cids = &getContigIdentifiers($contig,$focn,$adb);

&showUsage("No valid contig identifier provided") unless @$cids;

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my %options;

$options{confirm} = 1 if $confirm;

foreach my $cid (@$cids) {

    my ($status,$message) = $adb->retireContig($cid,%options);

    if ($status) {
        $logger->warning("Contig $cid has been retired");
    }
    elsif ($confirm) {
        $logger->severe("FAILED to retire contig $cid: $message");
    }
    elsif ($message =~ /can\sbe\sretired/) {
        $logger->warning($message." (=> use '-confirm')");
    }
    else {
        $logger->severe($message);
    }
}

$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $record = <$FILE>)) {
        next unless ($record =~ /\S/);
        if ($record =~ s/^\s*(\S+)\s*$//) {
            push @list, $1;
        }
        elsif ($record =~ /^\s*from\s+(\d+)\s+to\s+(\d+)\s*$/i) {
            my $start = $1;
            my $final = $2;
            for my $i ($start .. $final) {
                push @list, $i;
            }
        }
        else {
            print STDERR "Invalid input on focn: $record\n";
        }
    }
    return [@list];
}

#------------------------------------------------------------------------

sub getContigIdentifiers {
# ad hoc routine, returns contig IDs specified with $contig, $focn or both
    my $contig = shift; # contig ID, name or comma-separated list of these
    my $focn = shift; # filename
    my $adb = shift; # database handle

    my @contigs;

    if ($contig || $focn) {
# get contig identifiers in array
        if ($contig && $contig =~ /\,/) {
            @contigs = split /\,/,$contig;
        }
        elsif ($contig) {
            push @contigs,$contig;
        }
# add possible info from file with names
        if ($focn) {
            $focn = &getNamesFromFile($focn);
            push @contigs,@$focn;
        }
    }

# translate (possible) contig names into contig IDs

    my @cids;

    foreach my $contig (@contigs) {

        next unless $contig;

# identify the contig if a name is provided

        if ($contig =~ /\D/) {
# get contig ID from contig name
            my $contig_id = $adb->hasContig(withRead=>$contig);
# test its existence
            unless ($contig_id) {
                $logger->warning("contig with read $contig not found");
                next;
            }
            $contig = $contig_id;
        }
        push @cids,$contig;
    }
    return [@cids];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "Mothball (retire) a contig or contigs\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tarcturus database name\n" unless $organism;
        print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
        print STDERR "\n";
    }
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID or name of a read occurring in it\n";
    print STDERR "-focn\t\tfilename with list of contig IDs or read names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) \n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}

