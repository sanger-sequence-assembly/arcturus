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
my $repair = 2; # default mark as virtual parent
my $delete;
my $trashproject = 'TRASH';
my $assembly;
my $force = 0;
my $confirm;

my $validKeys  = "organism|instance|verbose|debug|trash|mark|repair|project|"
               . "assembly|delete|force|confirm|help";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
                                                                           
    if ($nextword eq '-instance') {
        &showUsage("You can't re-define instance") if $instance;
        $instance = shift @ARGV;
    }
      
    if ($nextword eq '-organism') {
        &showUsage("You can't re-define organism") if $organism;
        $organism = shift @ARGV; 
    }

    $verbose      = 1            if ($nextword eq '-verbose');

    $verbose      = 2            if ($nextword eq '-debug');

    $repair       = 1            if ($nextword eq '-trash');
    $confirm      = 1            if ($nextword eq '-trash');

    $repair       = 2            if ($nextword eq '-mark');

    $repair       = 3            if ($nextword eq '-repair');
    $force        = 1            if ($nextword eq '-repair');

    $trashproject = shift @ARGV  if ($nextword eq '-project');

    $assembly     = shift @ARGV  if ($nextword eq '-assembly');

    $delete       = 1            if ($nextword eq '-delete');

    $confirm      = 1            if ($nextword eq '-confirm');

    $force        = 1            if ($nextword eq '-force');

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

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
}

&showUsage("Missing database instance") unless $instance;

$logger->info("Database ".$adb->getURL." opened succesfully");

#----------------------------------------------------------------
# get the backup project
#----------------------------------------------------------------
my %options;
 
$options{project_id}  = $trashproject if ($trashproject !~ /\D/);
$options{projectname} = $trashproject if ($trashproject =~ /\D/);

if (defined($assembly)) {
    $options{assembly_id}  = $assembly if ($assembly !~ /\D/);
    $options{assemblyname} = $assembly if ($assembly =~ /\D/);
}
 
my ($projects,$message) = $adb->getProject(%options);
 
if ($projects && @$projects > 1) {
    my @namelist;
    foreach my $project (@$projects) {
        push @namelist,$project->getProjectName();
    }
    $logger->warning("Non-unique project specification : $trashproject (@namelist)");
    $logger->warning("Perhaps specify the assembly ?") unless defined($assembly);
    $adb->disconnect();
    exit;
}
elsif ($repair <= 1 && (!$projects || !@$projects)) {
    $logger->warning("Project $trashproject not available : $message");
    $adb->disconnect();
    exit;     
}

my $trashprojectid;
my $trashprojectname;

if ($repair <= 1) {
    $trashproject = shift @$projects;   
    $trashprojectid = $trashproject->getProjectID();
    $trashprojectname = $trashproject->getProjectName();
    $logger->warning("Project $trashprojectname ($trashprojectid) used for recover mode");
}

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my ($n,$hashlist);

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

$logger->skip if $n;

# test each contig to parent link; in default recover mode
# put offending contig in TRASH: this moves the contig out of the projects,
# which will then be clean. However, if wanted you can restore
# the link and move the contig back into its project by hand afterwards

foreach my $contig (sort {$a <=> $b} keys %$link) {
    my $parents = $link->{$contig};
    foreach my $parent (sort keys %$parents) {
        $logger->warning("Missing link between contig $contig and parent "
                        ."$parent (on $link->{$contig}->{$parent} reads)");
    }
}

$logger->skip if $n;
        
$logger->warning("Analysing link between contigs and parents") if $n;

undef %$link unless $repair;

my %markedparents;

foreach my $contig_id (sort {$a <=> $b} keys %$link) {

    $logger->skip;
    $logger->warning("Loading contig $contig_id");
    my $contig = $adb->getContig(contig_id=>$contig_id);
    $logger->warning("Contig $contig_id not found") unless $contig;
    next unless $contig; # no contig found

    $contig->addContigToContigMapping(0); # erase any existing C2CMappings

    $contig->setDEBUG() if ($verbose && $verbose > 1);

    my $currentproject = $contig->getProject();

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

# list the mappings into the database (result of 'force' option)

    if ($contig->hasContigToContigMappings) {
        $logger->warning("summary of parents for contig $contig_id");
        my $ccm = $contig->getContigToContigMappings();
        my $length = $contig->getConsensusLength();
        $logger->warning("number of mappings : ".scalar(@$ccm)." ($length)");
        foreach my $mapping (@$ccm) {
            $logger->warning($mapping->toString); 
        }
    }

    foreach my $parent_id (sort keys %$parents) {

        my $parent = $adb->getContig(contig_id=>$parent_id,metaDataOnly=>1);
        my $nr = $parent->getNumberOfReads();

# first, treat single read contigs (delete if delete option active)

        if ($nr <= 1 && $delete) {
            unless ($confirm) {
                $logger->warning("Single-read parent contig "
                                . $parent->getContigID()
				. " will be deleted in recover mode");
	        $logger->warning("repeat command with '-confirm' switch");
                next;
            }
# delete the contig
            my ($success,$msg) = $adb->deleteContig($parent_id,confirm=>1);
            $logger->severe("FAILED to remove contig $parent_id") unless $success;
            $logger->warning("Contig $parent_id is deleted") if $success;
            next if $success;
        }

# then, do the remaining ones

        my $project_id = $parent->getProject();
        
        if ($repair <= 1 && $project_id == $trashprojectid) {
            $logger->warning("parent contig $parent_id is already allocated to "
			    . "project $trashprojectname");
        }
        elsif ($repair <= 1) {
# move the offending parent contig to the trash project
            $logger->warning("Contig $parent_id will be allocated to "
		   	   . "project $trashprojectname in recover mode");
            unless ($confirm) {
	        $logger->warning("repeat command with '-confirm' switch");
                next;
	    }
# move contig to trash project
            my ($status,$msg) = $adb->assignContigToProject($parent,$trashproject);
            $logger->warning("status $status: $msg");
	}

        elsif ($repair == 2) {
# move the contig out of the current generation by making it a parent of contig 0
            if ($markedparents{$parent_id}++) {
                $logger->warning("Contig $parent_id has been processed earlier");
                next;
            }
            $logger->warning("Contig $parent_id will be marked as not belonging to "
		   	   . "the current generation in recover mode");
            unless ($confirm) {
	        $logger->warning("repeat with '-confirm' switch");
                next;
	    }

            my ($status,$msg) = $adb->retireContig($parent_id);
            unless ($status) {
                $logger->severe("Failed to re-allocate contig $parent_id : $msg");
            }
	}

        elsif ($repair == 3) {
# restore the link from $contig to $parent
            $logger->warning("The link to parent contig $parent_id will be added to "
		   	   . "the database in recover mode");
            unless ($confirm) {
	        $logger->warning("repeat command with '-confirm' switch");
                next;
	    }
# add the new link(s) to the C2CMAPPING list for this contig  TO BE TESTED
            my ($s,$m)= $adb->repairContigToContigMappings($contig,confirm=>1,
                                                                   nodelete=>1);
            $logger->warning($m);
	}

        else {
            $logger->warning("invalid parameter value $repair");
	}
    }
}

$logger->skip;

$adb->disconnect();

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\nList multiple allocated reads in the current assembly\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 

    unless ($organism && $instance) {
        print STDERR "\n";
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    }
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-repair\t\t(no value) if multiple allocations, repair links\n";
    print STDERR "\t\trepair requires the -confirm switch to have the effect\n";
    print STDERR "-trash\t\t(no value) if multiple allocations, assign offending\n";
    print STDERR "\t\tparent to trash project (default TRASH)\n";
    print STDERR "-project\tdefine the trash project explicitly\n";
    print STDERR "-mark\t\t(no value) if multiple allocations, link offending\n";
    print STDERR "\t\tparent to virtual contig 0\n";




#    print STDERR "-confirm\t(no value) confirm changes to database\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
