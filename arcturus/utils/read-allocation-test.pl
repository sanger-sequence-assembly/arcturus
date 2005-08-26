#!/usr/local/bin/perl5.6.1 -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $verbose;
my $repair;
my $confirm = 0;
my $force = 0;

my $validKeys  = "organism|instance|verbose|debug|repair|force|confirm|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }                                                                           
    $instance     = shift @ARGV  if ($nextword eq '-instance');
      
    $organism     = shift @ARGV  if ($nextword eq '-organism');

    $verbose      = 1            if ($nextword eq '-verbose');

    $verbose      = 2            if ($nextword eq '-debug');

    $repair       = 1            if ($nextword eq '-repair');

    $force        = 1            if ($nextword eq '-force');

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

&showUsage(0,"Missing organism database") unless $organism;

&showUsage(0,"Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}

$logger->info("Database ".$adb->getURL." opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------
my ($n,$hashlist);

# test set up
#@{$hashlist->{1}} = (30280,7712);#@{$hashlist->{2}} = (30280,7712);
#@{$hashlist->{3}} = (30496,16349);#@{$hashlist->{4}} = (30496,16349);
#@{$hashlist->{5}} = (30000,20000,10000);#@{$hashlist->{7}} = (30000,20000,10000);

$logger->info("Building temporary tables (be patient ... )");

($n,$hashlist) = $adb->testReadAllocation (); # find multiply allocated reads

$logger->warning( ($n || "No")." multiple allocated reads found");

$logger->skip;

# build the link list from contigs to parents based on the read allocation

my $link = {};
foreach my $read (sort {$a <=> $b} keys %$hashlist) {
    my @contigs = sort {$b <=> $a} @{$hashlist->{$read}};
    $logger->info("Read $read occurs in contigs @contigs");
    for (my $i = 1 ; $i < scalar(@contigs) ; $i++) {
        my $contig = $contigs[$i-1];
        my $parent = $contigs[$i];
        next unless ($parent < $contig); # just in case
        $link->{$contig} = {} unless $link->{$contig};
        $link->{$contig}->{$parent}++;
    }
}

$logger->skip;

# test each contig to parent link; in repair mode add the missing link to database

foreach my $contig (sort keys %$link) {
    my $parents = $link->{$contig};
    foreach my $parent (sort keys %$parents) {
        $logger->warning("Missing link between contig $contig and parent "
                        ."$parent (on $link->{$contig}->{$parent} reads)");
    }
}

$logger->skip;
        
$logger->warning("Analysing link between contigs and parents") if $n;

foreach my $contig_id (sort keys %$link) {

    $logger->skip;
    $logger->warning("Loading contig $contig_id");
    my $contig = $adb->getContig(contig_id=>$contig_id);
    $logger->warning("Contig $contig_id not found") unless $contig;
    next unless $contig; # no contig found

    $contig->addContigToContigMapping(0); # erase any existing C2CMappings

    $contig->setDEBUG() if ($verbose && $verbose > 1);

    my $parents = $link->{$contig_id};
    foreach my $parent_id (sort keys %$parents) {
	$logger->warning("Testing contig $contig_id against parent $parent_id");
	$logger->warning("Loading parent $parent_id");
        my $parent = $adb->getContig(contig_id=>$parent_id);
# analyse the link
        my ($segments,$dealloc) = $contig->linkToContig($parent,forcelink=>$force);
        unless (defined($segments)) {
            $logger->severe("UNDEFINED output of Contig->linkToContig");
            next;
        }
        my $length = $parent->getConsensusLength();
        $logger->warning("number of mapping segments = $segments ($length)");
    }
# enter the mappings into the database
    if ($contig->hasContigToContigMappings) {
        $logger->warning("summary of parents for contig $contig_id");
        my $ccm = $contig->getContigToContigMappings();
print STDOUT "number of mappings: $ccm \n";
        my $length = $contig->getConsensusLength();
        $logger->warning("number of mappings : ".scalar(@$ccm)." ($length)");
        foreach my $mapping (@$ccm) {
            $logger->warning($mapping->toString); 
        }
    }

    next unless $repair;
# no cleanup required
    my ($s,$m)= $adb->repairContigToContigMappings($contig,confirm=>$confirm);
    $logger->warning($m);
}

$logger->skip;

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nList multiply allocated reads in the current assembly\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-repair\t(no value) if multiple allocations, repair links\n";
    print STDERR "-confirm\t(no value) confirm changes to database\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
