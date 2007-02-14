#!/usr/local/bin/perl5.6.1 -w

use strict;

use ArcturusDatabase;

use Logging;

use Mail::Send;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $organism;
my $instance;

my $workproject;
my $insideprojects;
my $betweenproject;
my $assembly;

my $repair = 2; # default mark as virtual parent
my $delete;
my $problemproject = 'PROBLEMS';
my $force = 0;

my $lockenabled;
my $abortonlock = 1; # default abort on any project locked (except TRASH)

my $output;
my $address;

my $confirm;
my $verbose;
my $debug;

my $validKeys  = "organism|instance|out|output|of|mail|movetoproblems|mtp|mark|"
               . "repair|delete|problemproject|pp|project|assembly|workproject|wp|"
               . "inside|ip|between|bp|force|noabort|lockenabled|la|"
               . "verbose|debug|confirm|help";

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

    $verbose        = 1            if ($nextword eq '-verbose');
    $verbose        = 1            if ($nextword eq '-debug');
    $debug          = 1            if ($nextword eq '-debug');

    if ($nextword eq '-movetoproblems' || $nextword eq '-mtp') {
        $repair     = 1;
        $confirm    = 1;
    }

    $repair         = 2            if ($nextword eq '-mark');

    $repair         = 3            if ($nextword eq '-repair');
    $force          = 1            if ($nextword eq '-repair');

    $problemproject = shift @ARGV  if ($nextword eq '-project');
    $problemproject = shift @ARGV  if ($nextword eq '-problemproject');
    $problemproject = shift @ARGV  if ($nextword eq '-pp');

    $workproject    = shift @ARGV  if ($nextword eq '-workproject');
    $workproject    = shift @ARGV  if ($nextword eq '-wp');
    $assembly       = shift @ARGV  if ($nextword eq '-assembly');

    $delete         = 1            if ($nextword eq '-delete');

    $abortonlock    = 0            if ($nextword eq '-noabort');

    $insideprojects = 1            if ($nextword eq '-inside');
    $insideprojects = 1            if ($nextword eq '-ip');
    $betweenproject = 1            if ($nextword eq '-between');
    $betweenproject = 1            if ($nextword eq '-bp');

    $lockenabled    = 1            if ($nextword eq '-lockenabled');
    $lockenabled    = 1            if ($nextword eq '-la');

    $confirm        = 1            if ($nextword eq '-confirm');

    if ($nextword eq '-output' || $nextword eq '-out' || $nextword eq '-of') {
	$output = shift @ARGV;
    }

    $address        = shift @ARGV  if ($nextword eq '-mail');

    $force          = 1            if ($nextword eq '-force');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level

$logger->setBlock('debug',unblock=>1) if $debug;
 
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

$adb->setLogger($logger);

$logger->info("Database ".$adb->getURL." opened succesfully");

# if a special log file is to be used, open it here

$logger->setSpecialStream($output,append=>1,timestamplabel=>"$instance:$organism") if $output;


#----------------------------------------------------------------
# get the backup project
#----------------------------------------------------------------

my %options;
 
$options{project_id}  = $problemproject if ($problemproject !~ /\D/);
$options{projectname} = $problemproject if ($problemproject =~ /\D/);

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
    $logger->error("Non-unique project specification : $problemproject (@namelist)");
    $logger->error("Perhaps specify the assembly ?") unless defined($assembly);
    $adb->disconnect();
    exit 1;
}
# protect against undefined project
elsif ($repair <= 1 && (!$projects || !@$projects)) {
    $logger->error("Project $problemproject not available : $message");
    $adb->disconnect();
    exit 1;     
}

# get the problem project assigned (also if is not actually used)

my $problemprojectid;
my $problemprojectname;

$problemproject = shift @$projects;   
$problemprojectid = $problemproject->getProjectID();
$problemprojectname = $problemproject->getProjectName();
if ($repair <= 1) {
    $logger->warning("Project $problemprojectname ($problemprojectid) used for recover mode");
}

# default run this script in repair mode only if no project is locked

my ($lock,$msg);

if ($lockenabled) {
    
    my $lockcount = $adb->getLockCount(exclude=>'TRASH,RUBBISH');
    $logger->warning("there are $lockcount locked projects");

    if ($lockcount && ($repair && $confirm || $abortonlock) ) {
# abort the script if there are any locked projects, to prevent any
# changes being made to the contig-to-contig mappings while other data
# is being loaded, or prevent running this script with itself concurrently 
# (a locked project signals the possibility of new data being entered
#  which would interfere with the workings of this script)
        $logger->warning("read-allocation test abandoned");
        $adb->disconnect();
        exit 1;
    }

# acquire a lock on the problem project unless the script is run 
# in the inventarisation mode (i.e. without the '-confirm' flag)

    if ($confirm) {
       ($lock,$msg) = $adb->acquireLockForProject($problemproject,confirm=>1);
        unless ($lock) {
	    $logger->severe("Failed to acquire lock on project $problemprojectname");
            $adb->disconnect();
            exit 1;        
        }
        $logger->warning($msg);
# register the project for unlocking on non-standard termination of execution
        $adb->registerLockedProject($problemproject);
    }
}

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

undef %options;

$message = "multiply allocated reads found";

if ($workproject) { 
# a (work) project is specified 
    $options{project_id}  = $workproject if ($workproject !~ /\D/);
    $options{projectname} = $workproject if ($workproject =~ /\D/);
    $message .= " for project $workproject";
}

if ($insideprojects) {
    $options{insideprojects}  = 1;
    $message .= ", tested inside projects"; 
}

if ($betweenproject) {
    $options{betweenprojects} = 1;
    $message .= ", tested between projects";
}

$logger->warning("Testing consistency of read allocations ... ");

my $hashlist = $adb->testReadAllocation(%options); # find multiple allocations

my $m = scalar(keys %$hashlist);

$logger->special( ($m || "No")." ".$message,preskip => 1,skip => 1);

if ($m && $address) { # mail message
    my $pwd = `pwd`; chomp $pwd;
    $message .= "  ($instance:$organism)";
    $message .= "\n\ndetails in log file $pwd/$output" if $output;
    &sendMessage($address,"$m $message");
}

# build the link list from contigs to parents based on the read allocation

my $link = {};
foreach my $read (sort {$a <=> $b} keys %$hashlist) {
    my @contigs = sort {$b <=> $a} @{$hashlist->{$read}};
    $logger->special("Read $read occurs in contigs @contigs");
    for (my $i = 1 ; $i < scalar(@contigs) ; $i++) {
        my $contig = $contigs[$i-1];
        my $parent = $contigs[$i];
        next unless ($parent < $contig); # just in case
        $link->{$contig} = {} unless $link->{$contig};
        $link->{$contig}->{$parent}++;
    }
}

# test each contig to parent link; in default recover mode
# put offending contig in PROBLEMS: this moves the contig out of the projects,
# which will then be clean. However, if wanted you can restore
# the link and move the contig back into its project by hand afterwards

my $skip = -1;
foreach my $contig (sort {$a <=> $b} keys %$link) {
    my $parents = $link->{$contig};
    foreach my $parent (sort keys %$parents) {
        $logger->special("Missing link between contig $contig and parent "
                        ."$parent (on $link->{$contig}->{$parent} reads)", skip=>$skip);
    }
    $skip = 0;
}
        
$logger->special("Analysing links between contigs and parents",preskip=>1) if $m;

undef %$link unless $repair; # skips next foreach block

my %markedparents;

foreach my $contig_id (sort {$a <=> $b} keys %$link) {

    $logger->special("Loading contig $contig_id",preskip => 1);
    my $contig = $adb->getContig(contig_id=>$contig_id, notags => 1);
    $logger->special("Contig $contig_id not found") unless $contig;
    next unless $contig; # no contig found

    $contig->addContigToContigMapping(0); # erase any existing C2CMappings

    my $currentproject = $contig->getProject();

    my $parents = $link->{$contig_id};
    foreach my $parent_id (sort keys %$parents) {
	$logger->special("Testing contig $contig_id against parent $parent_id");
	$logger->info("Loading parent $parent_id");
        my $parent = $adb->getContig(contig_id=>$parent_id, notags => 1);
# analyse the link
        my ($segments,$dealloc) = $contig->linkToContig($parent,forcelink=>$force);
        unless (defined($segments)) {
            $logger->special("UNDEFINED output of Contig->linkToContig");
            next;
        }
        my $length = $parent->getConsensusLength();
        $logger->special("number of mapping segments = $segments ($length)");
    }

# list the mappings into the database (result of 'force' option)

    if ($contig->hasContigToContigMappings) {
        $logger->special("summary of parents for contig $contig_id");
        my $ccm = $contig->getContigToContigMappings();
        my $length = $contig->getConsensusLength();
        $logger->special("number of mappings : ".scalar(@$ccm)." ($length)");
        foreach my $mapping (@$ccm) {
            $logger->info($mapping->toString);
        }
    }

    foreach my $parent_id (sort keys %$parents) {

        my $parent = $adb->getContig(contig_id=>$parent_id,metaDataOnly=>1);
        my $nr = $parent->getNumberOfReads();

# first, treat single read contigs (delete if delete option active)

        if ($nr <= 1 && $delete) {
            unless ($confirm) {
                $logger->special("Single-read parent contig "
                                . $parent->getContigID()
				. " will be deleted in recover mode");
	        $logger->warning("repeat command with '-confirm' switch",skip=>1);
                next;
            }
# delete the contig (to be replaced/requires passwords?)
#            my ($success,$msg) = $adb->deleteSingleReadContig ($parent_id,confirm=>1);
            my ($success,$msg) = $adb->deleteContig($parent_id,confirm=>1);
            $logger->special("FAILED to remove contig $parent_id") unless $success;
            $logger->special("Contig $parent_id is deleted") if $success;
            next if $success;
        }

# then, do the remaining ones

        my $project_id = $parent->getProject();
        
        if ($repair <= 1 && $project_id == $problemprojectid) {
            $logger->special("parent contig $parent_id is already allocated to "
			    . "project $problemprojectname");
        }
        elsif ($repair <= 1) {
# move the offending parent contig to the problems project
            $logger->special("Contig $parent_id will be allocated to "
		   	   . "project $problemprojectname in recover mode");
            unless ($confirm) {
	        $logger->warning("repeat command with '-confirm' switch",skip=>1);
# mail message?
                next;
	    }
# move contig to problems project
            my ($status,$msg) = $adb->assignContigToProject($parent,$problemproject);
            $logger->special("status $status: $msg");
# enter record in transfer queue with status 'done'
	}

        elsif ($repair == 2) {
# move the contig out of the current generation by making it a parent of contig 0
            if ($markedparents{$parent_id}++) {
                $logger->special("Contig $parent_id has been processed earlier");
                next;
            }
            $logger->warning("Contig $parent_id will be marked as not in "
		   	   . "the current generation in recover mode");
            unless ($confirm) {
	        $logger->warning("repeat with '-confirm' switch", skip=>1);
                next;
	    }

            my ($status,$msg) = $adb->retireContig($parent_id,confirm=>$confirm);
            unless ($status) {
                $logger->special("Failed to re-allocate contig $parent_id : $msg");
		next;
            }
            $logger->warning("DONE");
	}

        elsif ($repair == 3) {
# restore the link from $contig to $parent
            $logger->special("The link to parent contig $parent_id will be added to "
		   	   . "the database in recover mode");
            unless ($confirm) {
	        $logger->warning("repeat command with '-confirm' switch",skip=>1);
                next;
	    }
# add the new link(s) to the C2CMAPPING list for this contig  TO BE TESTED
            my ($s,$m)= $adb->repairContigToContigMappings($contig,confirm=>1,
                                                                   nodelete=>1);
            $logger->special($m);
	}

        else {
            $logger->error("invalid parameter value repair $repair");
	}
    }
}

#$logger->warning("",skip => 1);

# if problem project locked, unlock

$adb->releaseLockForProject($problemproject,confirm=>1) if $lock;

$adb->disconnect();

$logger->close();

exit 0;

#------------------------------------------------------------------------

sub sendMessage {
    my ($user,$message) = @_;

#    print STDOUT "message to be emailed to user $user:\n$message\n\n";
    $user="ejz+$user" unless ($user =~ /\bejz\b/); # temporary redirect

    my $mail = new Mail::Send;
    $mail->to($user);
    $mail->subject("Arcturus multiple read allocations warning");
    $mail->add("X-Arcturus", "read-allocation-test");
    my $handle = $mail->open;
    print $handle "$message\n";
    $handle->close;

}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "List multiple allocated reads in the current assembly\n";
    print STDERR "This script can only be run when no data is being loaded\n";
    print STDERR "into any project; the default lock can be overridden only\n";
    print STDERR "when the repair mode is no active (i.e. without '-confirm')\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 

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
    print STDERR "-movetoproblems\t(mtp, no value) if multiple allocations, assign\n";
    print STDERR "\t\toffending parent to problems project (default PROBLEMS)\n";
    print STDERR "-project\tdefine the problems project explicitly\n";
    print STDERR "-mark\t\t(no value) if multiple allocations, link offending\n";
    print STDERR "\t\tparent to virtual contig 0\n";
    print STDERR "\n";
    print STDERR "-noabort\t\tOverrides the default abort on any project lock\n";
    print STDERR "\t\tunless the confirm flag is set\n";
    print STDERR "\n";
    print STDERR "-confirm\t(no value) confirm changes to database\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
