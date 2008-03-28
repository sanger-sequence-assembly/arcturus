#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;
my $contig;
my $strong = 0;
my $fofn;
my $next = 1;
my $confirm = 0;
my $cleanup = 0;
my $force = 0;
my $verbose;
my $debug;

my $validKeys  = "organism|instance|contig|fofn|next|strong|force|"
               . "cleanup|preview|confirm|verbose|info|debug|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }                                                                           
    $instance  = shift @ARGV  if ($nextword eq '-instance');
      
    $organism  = shift @ARGV  if ($nextword eq '-organism');

    $contig    = shift @ARGV  if ($nextword eq '-contig');

    $next      = shift @ARGV  if ($nextword eq '-next');

    $fofn      = shift @ARGV  if ($nextword eq '-fofn');

    $strong    = 1            if ($nextword eq '-strong');

    $force     = 1            if ($nextword eq '-force');

    $cleanup   = 1            if ($nextword eq '-cleanup');

    $verbose   = 1            if ($nextword eq '-verbose');

    $verbose   = 2            if ($nextword eq '-info');

    $debug     = 1            if ($nextword eq '-debug');

    $confirm   = 0            if ($nextword eq '-preview');

    $confirm   = 1            if ($nextword eq '-confirm');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setStandardFilter($verbose) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

&showUsage("Missing contig ID") unless ($contig || $fofn);

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

$fofn = &getNamesFromFile($fofn) if $fofn;

# get the list of contigs to investigate

my @contigs;

if ($fofn) {
    @contigs = @$fofn;
}
elsif ($contig =~ /\,/) {
    @contigs = split /\,/,$contig;
}
elsif ($contig) {
    push @contigs,$contig;
    while (--$next > 0) {    
        push @contigs,++$contig;
    }
}
else {
    &showUsage("Missing contig specification");
}


foreach my $contig_id (@contigs) {

    $logger->skip();

    my $contig = $adb->getContig(contig_id=>$contig_id);

    $logger->warning("Contig $contig_id not found") unless $contig;

    next unless $contig; # no contig found

    $logger->warning("Contig returned for $contig_id: $contig");

    $contig->addContigToContigMapping(0); # erase any existing C2CMappings

$contig->setLogger() if ($verbose && $verbose > 1); 

# get the parents from a database search

    my $linked = $adb->getParentIDsForContig($contig); # exclude self

# replace the parent ID by the parent Contig instance

    foreach my $parent (@$linked) {
	$logger->info("Loading parent $parent");
        my $contig = $adb->getContig(contig_id=>$parent);
        print STDERR "Contig $parent not retrieved\n" unless $contig;
        $parent = $contig;
    }

    $logger->info("No parents found on detailed search") unless @$linked;

    $logger->info("Parents: @$linked") if @$linked;

# test the link for each of the parents, determine the mapping from scratch

    my @rejectids; # for spurious links
    foreach my $parent (@$linked) {

        unless (ref($parent) eq 'Contig') {
            $logger->error("undefined parent 1 ".($parent||'undef'));
	    next;
        }

        $logger->warning("\nTesting against parent ".$parent->getContigName);

        $parent->getMappings(1); # load mappings

        my ($segments,$dealloc) = $contig->linkToContig($parent,
                                                        forcelink => $force,
                                                        strong => $strong);
        unless ($segments) {
            my $previous = $parent->getContigName();
            $logger->warning("empty/spurious link detected to $previous");
            push @rejectids, $parent->getContigID();
            my $exclude = join ',',@rejectids;
            my $newids = $adb->getParentIDsForContig($contig,exclude=>$exclude);
# determine if any new contig ids are added to the list
#	    $logger->warning("new IDs: @$newids");
            my $parentidhash = {};
            foreach my $contig (@$linked) {
                unless (ref($contig) eq 'Contig') {
                    $logger->error("undefined parent 2 ".($contig||'undef'));
	            next;
                }

                next unless (ref($contig) eq 'Contig');
                my $pid = $contig->getContigID();
                $parentidhash->{$pid}++;
	    }
# find the newly added parent IDs, if any, which do not occur in the parent ID hash
            foreach my $pid (@$newids) {
                next if $parentidhash->{$pid}; # already in list
	        $logger->warning("Loading new parent $pid");
                my $contig = $adb->getContig(contig_id=>$pid);
                print STDERR "Contig $pid not retrieved\n" unless $contig;
                push @$linked,$contig if $contig;
            }
        }
 
        my $length = $parent->getConsensusLength();
 
        $logger->warning("number of mapping segments = $segments ($length)");
    }


    if ($verbose && $contig->hasContigToContigMappings) {

        $logger->warning("summary of parents for contig $contig_id");

        my $ccm = $contig->getContigToContigMappings();

        my $length = $contig->getConsensusLength();

        $logger->warning("number of mappings : ".scalar(@$ccm)." ($length)");

        foreach my $mapping (@$ccm) {
            $logger->warning($mapping->toString);   
        }
    }

    my ($s,$m)= $adb->repairContigToContigMappings($contig,
                                                   cleanup=>$cleanup,
                                                   confirm=>$confirm);
    $logger->warning($m);
}

exit;

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------
 
sub getNamesFromFile {
    my $file = shift; # file name
 
    &showUsage("File $file does not exist") unless (-e $file);
 
    my $FILE = new FileHandle($file,"r");
 
    &showUsage("Can't access $file for reading") unless $FILE;
 
    my @list;
    while (defined (my $name = <$FILE>)) {
        last unless ($name =~ /\S/);
        $name =~ s/^\s+|\s+$//g;
        $name =~ s/.*\scontig\s+(\d+)\s.*/$1/;
        push @list, $name;
    }
 
    return [@list];
}
 
#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID\n";
    print STDERR "-fofn\t\tfile with list of contig IDs\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-next\t\tnumber of contigs to be tested from given contig\n";
    print STDERR "\n";
    print STDERR "-force\t\t(no value) force installation of the links\n";
    print STDERR "\n";
    print STDERR "-confirm\tdo the change; preview in its absence\n";
    print STDERR "-cleanup\t(no value) cleanup of segments database \n";
    print STDERR "\n";
    print STDERR "-strong\t\t(no value) use more detailed search mode\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
