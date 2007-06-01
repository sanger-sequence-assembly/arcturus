#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

require Mail::Send;

#----------------------------------------------------------------

my $organism;
my $instance;
my $action;
my $project;
my $assembly;
my $contig;
my $focn;
my $focpn;
my $foccn;
my $user;
my $owner;
my $request;
my $openproject = 'BIN,TRASH';
my $newoproject;

my $before;
my $after;
my $since;
my $truncate;

my $confirm;
my $force;
my $comment;

my $verbose;

my $PROJECTINSTANCECACHE = {};

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $actions = "transfer|grant|wait|defer|cancel|reject|execute|"
            . "reschedule|probe";

my $validKeys = "organism|o|instance|i|$actions|"
              . "contig|c|focn|fofn|project|p|focpn|foccn|assembly|a|"
              . "openproject|"
              . "user|u|owner|o|request|r|comment|"
              . "list|longlist|ll|before|after|since|truncate|trun|full|"
              . "help|h|s|"
              . "confirm|commit|force|preview|pre|verbose";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'",0,$action);
    }
 
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }  

    die "You can't re-define action" if ($action && $nextword =~ /\-($actions)\b/);

    $action      = 'transfer'   if ($nextword eq '-transfer');

    $action      = 'cancel'     if ($nextword eq '-cancel');

    $action      = 'execute'    if ($nextword eq '-execute');

    $action      = 'grant'      if ($nextword eq '-grant');

    $action      = 'defer'      if ($nextword eq '-wait');
    $action      = 'defer'      if ($nextword eq '-defer');

    $action      = 'reject'     if ($nextword eq '-reject');

$action      = 'reenter'    if ($nextword eq '-reschedule'); # test phase
$action      = 'probe'      if ($nextword eq '-probe');      # separate script?

    $action      = 'list'       if ($nextword eq '-list');     # pending requests only

    $action      = 'longlist'   if ($nextword eq '-longlist'); # all requests
    $action      = 'longlist'   if ($nextword eq '-ll');       # all requests

    $project     = shift @ARGV  if ($nextword eq '-project');
    $project     = shift @ARGV  if ($nextword eq '-p');

    $assembly    = shift @ARGV  if ($nextword eq '-assembly');
    $assembly    = shift @ARGV  if ($nextword eq '-a');

    $contig      = shift @ARGV  if ($nextword eq '-contig');

    $focn        = shift @ARGV  if ($nextword eq '-focn');
    $focn        = shift @ARGV  if ($nextword eq '-fofn');

    $focpn       = shift @ARGV  if ($nextword eq '-focpn');
    $foccn       = shift @ARGV  if ($nextword eq '-foccn');

$user        = shift @ARGV  if ($nextword eq '-user'); # ?
$user        = shift @ARGV  if ($nextword eq '-u');    # ?

    $owner       = shift @ARGV  if ($nextword eq '-owner');

    $request     = shift @ARGV  if ($nextword eq '-request');
    $request     = shift @ARGV  if ($nextword eq '-r');

    $comment     = shift @ARGV  if ($nextword eq '-comment');
    $truncate    = 0            if ($nextword eq '-comment');

    if ($newoproject && $nextword eq '-openproject') {
        die "You can't re-define open projects";
    }
    $newoproject = shift @ARGV  if ($nextword eq '-openproject');

    $before      = shift @ARGV  if ($nextword eq '-before');

    $after       = shift @ARGV  if ($nextword eq '-after');

    $since       = shift @ARGV  if ($nextword eq '-since');

    $verbose     = 1            if ($nextword eq '-verbose');
 
    $confirm     = 1            if ($nextword eq '-confirm' && !defined($confirm));
    $confirm     = 1            if ($nextword eq '-commit'  && !defined($confirm));

    $confirm     = 0            if ($nextword eq '-preview');
    $confirm     = 0            if ($nextword eq '-pre');

    $truncate    = 1            if ($nextword eq '-truncate');
    $truncate    = 1            if ($nextword eq '-trun');
    $truncate    = 0            if ($nextword eq '-full');

    $force       = 1            if ($nextword eq '-force');

# on-line help 

    &showUsage(0,1,$action) if ($nextword eq '-help'); # long write up
    &showUsage(0,0,$action) if ($nextword eq '-h'); # short write up
    &showUsage(0,2,$action) if ($nextword eq '-s'); # synopsis
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# test input parameters
#----------------------------------------------------------------

$action = 'list' unless $action;

&testdateformat($before) if $before;

&testdateformat($after)  if $after;

if ($since) {
    $since = lc($since);
    &testdateformat($since) unless ($since eq 'today' 
                                or  $since eq 'yesterday'
                                or  $since eq 'week'
                                or  $since eq 'month');
}

# contig identifier is mandatory for 'transfer', optional otherwise

if ($action eq 'transfer') {
# check on project and contig identifiers
    unless ($project || defined($focpn) || defined($foccn)) {
        &showUsage("Missing project ID or projectname",0,$action);
    }

    unless ($contig || defined($focn) || defined($focpn) || defined($foccn)) {
        &showUsage("Missing contig identifier or focn",0,$action);
    }

    if (defined($focpn) && ($project || $contig || $focn || $foccn)) {
        &showUsage("When using 'focpn' no contig or project can be specified ",0,$action);
    }

    if (defined($foccn) && ($project || $contig || $focn || $focpn)) {
        &showUsage("When using 'foccn' no contig or project can be specified ",0,$action);
    }

# perhaps more restrictive, here?
    if ($user || $owner || $request) {
        $logger->warning("Redundant keyword(s) ignored");
    }
    if ($action !~ /list/ && ($before || $after || $since)) {
        $logger->warning("Redundant time specification ignored");
    }
 }
else {
# focn may not be specified, but a contig ID is allowed
    if (defined($focn) || defined($focpn) || defined ($foccn)) {
        &showUsage("Invalid key 'focn', 'focpn' or 'foccn' for '$action' action",0,$action);
    }
}

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism eq 'default' || $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message

    &showUsage("Missing organism database") unless $organism;

    &showUsage("Missing database instance") unless $instance;

    &showUsage("Organism '$organism' not found on server '$instance'");
}

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection

$adb->setLogger($logger);
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully",skip=>1);

#----------------------------------------------------------------
# preliminaries: get (possible) contig and/or project info
#----------------------------------------------------------------

my ($cids,$ctophash,$pid);

if (defined($focpn)) {

    $logger->info("Reading from file $focpn");

   ($cids,$ctophash) = &getContigProjectIdentifiers($focpn,$adb);

# run through all contigs and collect the projects

    foreach my $cid (@$cids) {
        my $project = $ctophash->{$cid};
	unless (&getCachedProject($adb,$project,$assembly)) {
# invalid project/assembly specification (all cases); abort
            $adb->disconnect();
            &showUsage("Unknown project '$project' specified on file $focpn",0,$action);
            exit 0;
	}
    }
}

elsif (defined($foccn)) {

    $logger->info("Reading from file $foccn");

   ($cids,$ctophash) = &getProjectIdentifiersForContigs($foccn,$adb);
# run through all contigs and collect the projects

    foreach my $cid (@$cids) {
        my $project = $ctophash->{$cid};
	unless (&getCachedProject($adb,$project,$assembly)) {
# invalid project/assembly specification (all cases); abort
            $adb->disconnect();
            &showUsage("Unknown project '$project' specified on file $foccn",0,$action);
            exit 0;
	}
    }
}

elsif ($contig || defined($focn)) {

    $cids = &getContigIdentifiers($contig,$focn,$adb);

}

# if the project is defined on the command line (all cases, except with 'focpn')
# then get the project and assembly information (ID or name for both, and if any)

if ($project) {
# get the project via the caching method
    my $Project = &getCachedProject($adb,$project,$assembly);

    unless ($Project) {
# invalid project/assembly specification (all cases); abort
        $adb->disconnect();
        &showUsage("Unknown project '$project'",0,$action);
        exit 0;
    }

    $pid = $Project->getProjectID();
}
 
#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

# These sections deal with the various options individually

# -transfer : enter a transafer request into the database
# -grant/reject/defer : approving or not a request
# -cancel :   cancel a request
# -execute :  process pending and approved requests
# -list/longlist : listing option for display of (pending) requests

#----------------------------------------------------------------
# CREATE a new contig transfer request
#----------------------------------------------------------------

if ($action eq 'transfer') {

    my %options;
    if ($newoproject) {
# open projects can only be re-defined by privileged users
        if ($adb->userCanAssignProject()) {
            $openproject = $newoproject; 
            $options{useropen} = 1;
        }
	else {
	    $logger->warning("Sorry, but you can not re-define 'open' projects");
	}
    }

    $options{open} = $openproject;
#$options{user} = $user if $user; # what does this, check
    $options{requester_comment} = $comment if $comment;
    $options{ignore_project} = 1 if $force;

    foreach my $contig (@$cids) {

        if ($ctophash) {
	    my $Project = &getCachedProject($adb,$ctophash->{$contig},$assembly);
            $pid = $Project->getProjectID() if $Project;
        } 

        my ($status,$message) = &createContigTransferRequest($adb,$contig,$pid,
                                                             $confirm,%options);
        if ($status == 1) {
            my $Project = &getCachedProject($adb,$pid,$assembly);
            $logger->warning("A request to transfer contig $contig to project ".
                             $Project->getProjectName()." is queued : $message");
        }
        elsif ($status == 2) {
            $logger->warning("$message  => use -confirm",preskip=>1);
	}
        else {
            $logger->warning("transfer request is REFUSED : $message",preskip=>1);
        }  
    }
}

#----------------------------------------------------------------
# LIST requests (default if NO specific request ID is specified) 
#----------------------------------------------------------------

elsif ($action eq 'list' || $action eq 'longlist' || (!$request && $action ne 'execute')) {
# if NO specific request ID is specified all these options revert to 'list'
    my %options;
    $options{requester} = $user if $user;
    $options{requester} = $owner if $owner; # overrides
    $options{contig_id} = $contig if $contig;
    $options{projectids} = $pid if $pid;
    $options{request_id} = $request if $request;
    $options{before} = $before if $before;
    $options{after}  = $after  if $after;
    $options{since}  = $since  if $since;

    unless ($options{projectids} || $options{request_id}) {
# default selection of projects to be used
        my $projectids = $adb->getAccessibleProjects();
        $options{projectids} = join ',',@$projectids  if @$projectids;
# if this user has no access to any project add owner if not already done
        unless (@$projectids || $options{owner}) {
            $options{owner} = $adb->getArcturusUser();
        }
    }

# get request IDs for input parameter options

    $options{orderby} = 'reviewed desc,request_id desc';
    my $full = ($action eq 'longlist' ? 1 : 0);
    my $requestsfound = $adb->getContigTransferRequestIDs($full,%options);

# print out

    $user = $adb->getArcturusUser(); # (possibly) redefine

    my $header;
    my $linemode = 1;
    if ($requestsfound && @$requestsfound > 1) {
        $header = " ID  contig         projects          owner    created  "
                . "       reviewed          by     status  ";
        $header .= "comments" unless $truncate;
    }
    elsif ($requestsfound && @$requestsfound == 1) {
        $linemode = 0;
    }
    else {
        $header = "There are NO transfer" 
                . ($action =~ /longlist/ ? " " : " pending ") 
                . "requests involving user $user";
    }

    $logger->warning($header, preskip=>1, skip=>1);

    foreach my $request (@$requestsfound) {
        my $rd = $adb->getContigTransferRequestData($request);
# translate project_ID's into project names
        my $old_project = &getCachedProject($adb,$rd->{old_project_id});
        my $new_project = &getCachedProject($adb,$rd->{new_project_id});
        $rd->{old_project_id} = $old_project->getProjectName() if $old_project;
        $rd->{new_project_id} = $new_project->getProjectName() if $new_project;
        if ($linemode) {
# clip created field down to date
            $rd->{opened} =~ s/^\s*(\S+)\s.*/$1/;
# get comment information (to be developed)
            my $comment = $rd->{requester_comment};
            $comment .= "\n\t\t\t\t\t\t\t\t\t\t\t\t" if $comment;
            $comment .= "$rd->{reviewer_comment}";
            unless ($comment || $rd->{status} ne 'pending') {
                $comment  = "AWAITING approval";
                $comment .= " by $rd->{reviewer}" if ($rd->{reviewer} ne $user);
	    }

            my $line = sprintf("%3d %7d %10s > %-10s %6s  %9s  %19s %6s %10s",
                       $rd->{request_id},$rd->{contig_id},$rd->{old_project_id},
        	       $rd->{new_project_id},$rd->{requester},$rd->{opened},
	               $rd->{reviewed},$rd->{reviewer},$rd->{status});
            $line .= sprintf("  %-40s",$comment) unless $truncate;
            $logger->warning($line,skip=>1);
	}
        else {
            unless ($rd->{reviewer_comment} || $rd->{status} ne 'pending') {
                $rd->{reviewer_comment}  = "AWAITING approval";
                if ($rd->{reviewer} ne $user) {
                    $rd->{reviewer_comment} .= " by $rd->{reviewer}";
                }
	    }
            my @keys = ('request_id','contig_id','old_project_id','new_project_id',
                        'requester','opened','requester_comment',
                        'reviewer','reviewed','reviewer_comment','status');
            push @keys, 'closed' if ($action eq 'longlist');
            foreach my $key (@keys) {
                my $line = sprintf("%20s : %-40s",$key,$rd->{$key});
                $logger->warning($line);
            }
	}
    }

    if ($requestsfound && @$requestsfound && $action !~ /list/) {
        $logger->warning("** Provide the '-request N' key to select a request **",preskip=>1);
    }
}

#------------------------------------------------------------------------------
# CANCEL, GRANT or REJECT a request; these options come with confirm/force mode
#------------------------------------------------------------------------------

if ($action =~ /\b(grant|defer|cancel|reject|reenter)\b/) {

    my %options;
    $options{requester} = $user if $user;
    $options{requester} = $owner if $owner;
    $options{contig_id} = $contig if $contig;
    $options{projectids} = $pid if $pid;

# check if the request exists

    $options{request_id} = $request; # is always defined (see list selection above)
    $options{status} = 'pending' unless ($action eq 'reenter');
    $options{status} .= ',approved'  if ($action eq 'cancel');

    my $datamode = ($action eq 'reenter' ? 2 : 1);
    my $requestsfound = $adb->getContigTransferRequestIDs($datamode,%options);

    if ($requestsfound && @$requestsfound && $requestsfound->[0] == $request) {
# get request details
        my $rd = $adb->getContigTransferRequestData($request);
# translate project_ID's into project names
        my $old_project = &getCachedProject($adb,$rd->{old_project_id});
        my $new_project = &getCachedProject($adb,$rd->{new_project_id});
        $rd->{old_project_id} = $old_project->getProjectName() if $old_project;
        $rd->{new_project_id} = $new_project->getProjectName() if $new_project;
        my $description = "$rd->{request_id} "
                        . "(move contig $rd->{contig_id} "
	        	. "from project $rd->{old_project_id} "
	        	. "to $rd->{new_project_id} "
                        . "for user $rd->{requester})";
# and prepare for some intelligible messages
        my ($operation,$status,$report);

        $operation = "cancelled"  if ($action eq 'cancel');
        $operation = "approved"   if ($action eq 'grant');
        $operation = "refused"    if ($action eq 'reject');
        $operation = "re-entered" if ($action eq 'reenter');
        $operation = "marked for later consideration" if ($action eq 'defer');

        if (!$confirm) {
            $logger->warning("request $description is to be $operation  => use '-confirm'");
        }

        elsif ($action eq 'defer') {
            $comment = "" unless $comment;
            $comment = " ($comment)" if $comment;
            $comment = "will be considered later".$comment;
           ($status,$report) = $adb->modifyContigTransferRequest($request,1,$force,
					                        reviewer_comment => $comment);
        }

        elsif ($action eq 'reenter') {
# only for dba
   	    my %options = (status => 'pending');
            $options{requester_comment} = "previously $rd->{status} request was re-entered"
                                       . ($comment ? ": $comment" : "");
            undef $options{reviewer_comment};
            undef $options{closed};
           ($status,$report) = $adb->modifyContigTransferRequest($request,0,$force,%options);
        }

        else {
# the 'force' flag is required if invoked by other than owner
   	    my %options = (status => $operation);
            $options{reviewer_comment} = $comment; # clears existing if not defined
            my $ot = ($action eq 'cancel') ? 0 : 1; # only the owner can cancel
           ($status,$report) = $adb->modifyContigTransferRequest($request,$ot,$force,%options);
        }

# test status and report on command line

        if ($status) {
            $logger->warning("operation successful : request $description is $operation");
	    if ($status == 2) {
                &sendMessage($rd->{requester}, "your request $description was $operation "
                                               . "by user ".$adb->getArcturusUser());
	    }
        }
        elsif ($confirm) {
# replace project ID by name
            if ($report =~ /project\sID\s(\d+)\b/i) {
                my $project = &getCachedProject($adb,$1);
                my $projectname = $project->getProjectName();
                $report =~ s/ID\s(\d+)\b/$projectname/i;
            }
            $logger->warning("operation refused : $report");
        }
    }
    elsif ($request) {
        my $status = ($action ne 'reenter' ? "pending" : "completed");
        $logger->warning("operation refused : no such ($status) request $request");
    }
}

#----------------------------------------------------------------
# EXECUTE approved requests
#----------------------------------------------------------------

elsif ($action eq 'execute') {

    $user = $adb->getArcturusUser();

# select approved requests only

    my %options;
    $options{status} = 'approved';
    $options{requester} = $owner if $owner;
    $options{request_id} = $request if $request;
# relating to projects accessible to the current user (we don't allow execution for
# requests the user has nothing to do with)
    unless ($options{projectids}) {
        my $projectids = $adb->getAccessibleProjects();
#        push @$projectids, 0 if $force;
        $options{projectids} = join ',',@$projectids  if @$projectids;
# if this user has no access to any project add owner if not already done
        unless (@$projectids || $options{requester}) {
            $options{requester} = $user;
        }
    }
           
    my $requestsfound = $adb->getContigTransferRequestIDs(1,%options);

    my $processed = 0;
    foreach my $request (@$requestsfound) {
# get request data
        my $rd = $adb->getContigTransferRequestData($request);
# get the corresponding projects
        my $old_project = &getCachedProject($adb,$rd->{old_project_id});
        my $new_project = &getCachedProject($adb,$rd->{new_project_id});
# and the user
        my $requester = $rd->{requester};
# test current generation the contig is in, and the current project

        my $cid = $rd->{contig_id};
        unless ($adb->isCurrentContigID($cid)) {
            my $report = "contig $cid is not (anymore) in the current generation";
            $logger->warning($report);
            next unless $confirm;
            $adb->modifyContigTransferRequest($request,2,$force,status =>'failed',
                                              reviewer_comment =>"expired generation");
            &sendMessage($requester,"contig $cid could NOT be transfered: $report");
            next;
        }

        my $pid = $rd->{old_project_id};

        my $cpid = $adb->getProjectIDforContigID($cid); # current project ID
        $cpid = 0 unless defined($cpid); # assign project ID 0

        unless ($pid == $cpid) {
# translate project IDs into project names
            my $cur_project = &getCachedProject($adb,$cpid);
            $pid  = $old_project->getProjectName() if $old_project;
            $cpid = $cur_project->getProjectName() if $cur_project;
            my $report = "contig $cid is not anymore in project $pid (but is in $cpid)";
            $logger->warning($report);
            next unless $confirm;
            $adb->modifyContigTransferRequest($request,2,$force,status =>'failed',
                                              reviewer_comment =>"expired original project");
            &sendMessage($requester,"contig $cid could NOT be transfered: $report");
            next;
        }        
        
        unless ($confirm) {
# translate project_ID's into project names
            $rd->{old_project_id} = $old_project->getProjectName() if $old_project;
            $rd->{new_project_id} = $new_project->getProjectName() if $new_project;
            my $line = sprintf("%3d %7d %10s > %-10s %6s  %9s  %19s %6s %10s  %-40s",
                       $rd->{request_id},$rd->{contig_id},$rd->{old_project_id},
            	       $rd->{new_project_id},$rd->{requester},$rd->{opened},
	               $rd->{reviewer},$rd->{status},
                       $rd->{reviewer_comment});
            $logger->warning("contig transfer request to be executed "
                           . "(=> use '-confirm') :\n\n".$line);
            next;
        }

# execute the request, first do the status to done (to check access rights)

        my ($status,$report) = $adb->modifyContigTransferRequest($request,2,$force,
                                                                  status=>'done');

        unless ($status) {
            $logger->warning("transfer refused: $report");
            next;
        }

# ok, the operation is authorized

        $pid = $rd->{new_project_id};
# pass the cid on as reference to an array of (length 1)
       ($status,$report) = $adb->assignContigIDsToProjectID([($cid)],$pid);
# replace pid by (new) project name
        $pid = $new_project->getProjectName() if $new_project;

# status 0, failure project locked (-> back to 'approved' for later execution)
# status 1, success
# status 2, contig already allocated (-> set to 'failed') should not occur


        if ($status == 1) {
            $report = "contig $cid was moved to project $pid";
            $logger->warning($report);
# send message if this user differs from owner
            &sendMessage($requester,"$report by $user") if ($user ne $requester);
            $processed++;
        }
        elsif ($status) {
            print STDERR "THIS SHOULD NOT OCCUR\n";
	}
        else {
            $report = "project $pid is locked; request will be requeued";
            $adb->modifyContigTransferRequest($request,2,$force,status=>'approved');
	}
    }

    $logger->warning("no transfer requests processed",preskip=>1) unless $processed;            
}



elsif ($action eq 'probe') {
# ? separate script?
}
  
$adb->disconnect();
    
$logger->info("Processing user mail (if any)",preskip=>1,skip=>1);

# send messages to users, if any

my $addressees = $adb->getMessageAddresses(1);

foreach my $user (@$addressees) {
    my $message = $adb->getMessageForUser($user);
    &sendMessage($user,$message) if $message;
}

exit 0;

#------------------------------------------------------------------------
# subroutines (ad hoc for this script only)
#------------------------------------------------------------------------

sub testdateformat {
    my $date = shift;
    unless ($date =~ /^\d{4}\-\d{2}-\d{2}$/) {
        &showUsage("Invalid date specification $date (use YYYY-MM-DD)");
    }
}

sub getContigIdentifiers {
# ad hoc routine, returns contig IDs specified with $contig, $focn or both
    my $contig = shift; # contig ID, name or comma-separated list of these
    my $focn = shift; # filename, can be 0 for STDIN
    my $adb = shift; # database handle

    my @contigs;

    if ($contig || defined($focn)) {
# get contig identifiers in array
        if ($contig && $contig =~ /\,/) {
            @contigs = split /\,/,$contig;
        }
        elsif ($contig && $contig =~ /\%|\_/) {
            my %options = (maximumnumberofreads => 1, readname => $contig);
$options{project} = 173;
	    my $result = $adb->getContigIDsForContigProperty(%options);
            @contigs = @$result if $result;
        }
        elsif ($contig) {
            push @contigs,$contig;
        }
# add possible info from file with names
        if (defined($focn)) {
            my $names = &getNamesFromFile($focn);
            push @contigs,@$names;
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

sub getContigProjectIdentifiers {
# the input file has a contigname/ID and project name/ID per line
    my $focpn = shift; # filename with contig-project pairs
    my $adb = shift; # database handle

    my ($contigs,$ctophash) = &getNamesFromFile($focpn,2);

# identify the contigs, also if cids already is the contig ID to test existence
# and collect the projects listed on the file with each contig

    my $cids = [];
    my $itophash = {}; # contig ID to project

    foreach my $contig (@$contigs) {

        next unless $contig;

# do the project first

        my $project = $ctophash->{$contig};

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

        push @$cids,$contig;
        $itophash->{$contig} = $project;
    }

    return $cids,$itophash;
}

#------------------------------------------------------------------------

sub getProjectIdentifiersForContigs {
# the input file has a contig name/ID and another contig name/ID per line;
# the second name is a contig in the project to which the first contig is moved
    my $focpn = shift; # filename with contig-contig pairs
    my $adb = shift; # database handle

    my ($contigs,$ctophash) = &getNamesFromFile($focpn,2);

# identify the contigs, also if cids already is the contig ID to test existence
# and collect the projects listed on the file with each contig

    my $cids = [];
    my $itophash = {}; # contig ID to project

    foreach my $contig (@$contigs) {

        next unless $contig;

# grab project identifier

        my $projectcontig = $ctophash->{$contig};

# identify the contig if a name is provided (the first field)

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
# add to output list
        push @$cids,$contig;

# now find the project (from the contig name in the second field

        my $project;

        if ($projectcontig =~ /\D/) {
# get project from the readname provided
            my $resultlist = $adb->getProjectIDforReadName($projectcontig);
            foreach my $cid (sort {$b <=> $a} keys %$resultlist) {
		$project = $resultlist->{$cid};
                last; # get the current contig
            }
        }
        else {
            $project = $adb->getProjectIDforContigID($projectcontig); 
	}

        $itophash->{$contig} = $project;
    }

    return $cids,$itophash;
}

#------------------------------------------------------------------------

sub getNamesFromFile {
# read a list of names from a file and return an array
    my $file = shift; # file name
    my $ncol = shift || 1;

# open a file handle if a filename is provided, else open STDIN
    
    my $FILE;

    if ($file) {

        &showUsage("File $file does not exist") unless (-e $file);
        $FILE = new FileHandle($file,"r");
        &showUsage("Can't access $file for reading") unless $FILE;
    }
    else{
	$FILE = *STDIN;
        $file = 'STDIN'; # for reporting
    }

    my $cids = [];
    my $hash = {};

    $ncol = 2 if ($ncol != 1);

    while (defined (my $record = <$FILE>)) {
        next unless ($record =~ /\S/);
        $record =~ s/^\s+|\s+$//g; # renmove leading / trailing blank space
        my @fields = split /\s+/,$record;
        unless (scalar(@fields) == $ncol) {
            print STDERR "** ".scalar(@fields)." data field(s) "
		       . "detected on file '$file' when $ncol expected ** : ";
            print STDERR "data ignored: @fields\n";
            next;
        }
# add first field (contig ID) to list
        push @$cids, $fields[0];
        next if ($ncol == 1);
# add second field to hash, keyed on first field
        if ($hash->{$fields[0]}) {
            print STDERR "Duplicate contig ID $fields[0] on file $file\n";
	}
        $hash->{$fields[0]} = $fields[1];
    }

    $FILE->close();

    print STDERR "NO valid data found on file '$file'\n" unless @$cids; 

    return $cids if ($ncol == 1);

    return $cids,$hash;
}

#------------------------------------------------------------------------

sub getProjectInstance {
# returns Project given project ID or name and (optionally) assembly
# (also in case of project ID we consult the database to check its existence)
    my $adb = shift; # database handle
    my $identifier = shift;  # ID or name
    my $assembly = shift; # ID or name

    return undef unless $identifier;

# get project info by getting a Project instance

    my %projectoptions;
    $projectoptions{project_id}  = $identifier if ($identifier !~ /\D/);
    $projectoptions{projectname} = $identifier if ($identifier =~ /\D/);
    if (defined($assembly)) {
        $projectoptions{assembly_id}   = $assembly if ($assembly !~ /\D/);
        $projectoptions{assemblyname}  = $assembly if ($assembly =~ /\D/);
    }

# find the project and test if it is unique

    my ($Project,$log) = $adb->getProject(%projectoptions);
# test if any found
    unless ($Project && @$Project) {
        my $message = "No project $identifier found";
        $message .= " in assembly $assembly" if $projectoptions{assemblyname};
        $logger->warning("$message: $log");
        return undef;
    }
# test if project is unique; if not return undef
    if ($Project && @$Project > 1) {
        my $list = '';
        foreach my $project (@$Project) {
	    $list .= $project->getProjectName()." ("
                   . $project->getAssemblyID().") ";
        }
        $logger->warning("More than one project found: $list");
        $logger->warning("Are you sure you do not need to specify assembly?")
            unless defined($assembly);
        return undef;
    }

    return $Project->[0] if $Project;

    return undef;
}

sub getCachedProject {
# build cache of project names keyed on project ID
    my $adb = shift;
    my $pid = shift; # project identifier
    my $aid = shift; # assembly identifier, optional

    return $PROJECTINSTANCECACHE->{$pid}  if $PROJECTINSTANCECACHE->{$pid};

# get project and cache

    my $Project = &getProjectInstance($adb,$pid,$aid);

    return 0 unless $Project; 

# cache the project instance reference on both project ID and project name

    $PROJECTINSTANCECACHE->{$Project->getProjectID()}   = $Project;
    $PROJECTINSTANCECACHE->{$Project->getProjectName()} = $Project;

    return $Project;
}

#------------------------------------------------------------------------

sub createContigTransferRequest {
# create a contig transfer request if it does not already exist
    my $adb = shift;
    my $cid = shift; # contig ID
    my $tpid = shift; # project ID (target project)
    my $confirm = shift;
    my %options = @_;

# each request is tested against other (active) requests in the queue for
# consistency; each request is then tested for validity, i.e. whether it
# can be executed

    return 0,"undefined contig or project identifier" unless ($cid && defined($tpid));

    my $user = $adb->getArcturusUser();

# test if a pending request to move the contig is not already present

    my $rids = $adb->getContigTransferRequestIDs(0,contig_id=>$cid);

# test if the contig is already requested for another or for the same project

    my $message = '';
    foreach my $rid (@$rids) {
        my $hash = $adb->getContigTransferRequestData($rid);
        if ($hash->{new_project_id} == $pid) {
# this request is already queued
            my $comment = $hash->{requester_comment} || '';
            return 0, "existing request $rid was created on $hash->{opened} "
                    . "by $hash->{requester} (current status: $hash->{status}"
                    . ($comment ? ", $comment)" : ")");
        }
        my @pnames = $adb->getNamesForProjectID($hash->{new_project_id});
        $message .= "!! contig $cid is also requested for project $pnames[0] "
                  . "by user $hash->{requester}\n";
    }

# test if the contig is in the latest generation

    unless ($adb->isCurrentContigID($cid)) {
        return 0,"contig $cid is not in the current generation";
    }

# test if the contig is not already allocated to the target project 

    my $cpid = $adb->getProjectIDforContigID($cid); # current project ID

    unless (defined($cpid)) {
        my $message = "contig $cid does not exist or has an invalid "
                    . "project reference";
        return 0,$message unless $options{ignore_project};
        $cpid = 0;
    }

    if ($cpid == $tpid) {
        my @pns = $adb->getNamesForProjectID($tpid);
        return 0,"contig $cid is already allocated to project $pns[0]";# $tpid
    }  

# ok, a transfer request can be queued provided that the user has access
# privilege on the contig's current project and/or its target project

    my $open = '';
# see if any open projects are defined, to which everybody has access
    if ($options{open}) {
        my @opns = split /\W/,$options{open}; # open project names
        foreach my $openprojectname (@opns) {
            my $projects = $adb->getProjectIDsForProjectName($openprojectname);
# returns a list of project ID, assembly ID pairs
            unless (@$projects || !$options{useropen}) {
    	        print STDERR "!! invalid open project name $openprojectname !!\n";
            }
            foreach my $project (@$projects) {
                $open .= " " if $open;
                $open .= $project->[0];
            }
	}
    }

# test access of this user to current project of the contig

    my $cpp = $adb->getAccessibleProjects(project=>$cpid,user=>$user);
    $cpp = (@$cpp ? $cpp->[0] : 0); # replace reference by value

# test access of this user to target project

    my $tpp = $adb->getAccessibleProjects(project=>$tpid,user=>$user);
    $tpp = (@$tpp ? $tpp->[0] : 0); # replace reference by value

    my @cnames = $adb->getNamesForProjectID($cpid); 
    @cnames = ('UNDEF','UNDEF',$user) unless $cnames[2];
    my @tnames = $adb->getNamesForProjectID($tpid);

    return 0,"invalid project ID: project $tpid does not exist" unless $tnames[2];
 
    unless ($cpp || $tpp) {
        my $report = "user $user has no privilege for a transfer from project "
                   . "$cnames[0] ($cnames[1]) to project $tnames[0] ($tnames[1])";
        $report =~ s/\s\([^\)]+\)//g if ($cnames[1] eq $tnames[1]);
        return 0, $report;
    }
  
    unless ($confirm) {
        my $report = "contig $cid may be moved "
                   . "from project $cnames[0] ($cnames[1]) "
                   . "to project $tnames[0] ($tnames[1])";
        $report =~ s/\s\([^\)]+\)//g if ($cnames[1] eq $tnames[1]);
        return 2, $report;
    }

# test for open projects (either original or target)

    $cpp = 1 if (!$cpp && $open && $open =~ /\b$cpid\b/); # override open project
    $tpp = 1 if (!$tpp && $open && $open =~ /\b$tpid\b/); # override open project

# OK, enter the new request with rstatus 'pending'; get its request ID

    my $rqid = 0;
    unless ($rqid = $adb->putContigTransferRequest($cid,$tpid,$user)) {
        return 0, "failed to insert request; possibly invalid "
                . "contig ID or project ID?";
    }

# the request has been added with status 'pending', now update comment and reviewer

    my $comment = $options{comment};

    my $status; # for output message

    if ($cpp && $tpp) {
# user has privilege on both (current & destination) projects; add comment if not project owner
        unless ($comment || $user eq $cnames[2]) {
     	    $comment = "original contig owner $cnames[2]";
	}
        $adb->modifyContigTransferRequest($rqid,0,0,requester_comment => $comment,
                                                    status =>'approved');
        $status = "approved";
    }
    elsif ($tpp) {
# user has no privilege on the project the contig is currently in
        $status = "waiting for approval by $cnames[2]";
# update the comment (if any) and set the reviewer of the new request
        $adb->modifyContigTransferRequest($rqid,0,0,requester_comment => $comment,
                                                    reviewer => $cnames[2]);
        &mailMessageToOwner($adb,$rqid,$cid,$cnames[0],$tnames[0],$cnames[2],$user,0);
    }
    else {
# user has no privilege on the target project
        $status = "waiting for approval by $tnames[2]";
# update the comment of the new request
        $adb->modifyContigTransferRequest($rqid,0,0,requester_comment => $comment,
                                                    reviewer => $tnames[2]);
        &mailMessageToOwner($adb,$rqid,$cid,$cnames[0],$tnames[0],$tnames[2],$user,1);
    }

    return 1, "request $rqid was created for user $user ($status)"
            . ($message ? " $message" : "");
}

sub mailMessageToOwner {
# compose and submit a message to the owner of project 
    my ($adb,$request,$contig,$cproject,$tproject,$owner,$requestor,$in) = @_;

    my $arcturusworkdir = `pfind -q $organism`;
    $arcturusworkdir .= "/arcturus";

    my $message = "user $requestor requests contig $contig to be moved\n";
    $message .= "from ".($in ? "" : "** your **")." project $cproject\n"
             .  "into ".($in ? "** your **" : ""). "project $tproject\n\n";

    $message .= "To cancel, grant or reject this transfer, or to defer a decision,\n"
             .  "do execute one of the following commands in the arcturus work\n"
             .  "directory for $organism ($arcturusworkdir) : \n\n";

    $message .= "transfer/grantContigRequest  -request $request\n"
#             .  "transfer/cancelContigRequest -request $request\n"
             .  "transfer/rejectContigRequest -request $request\n"
             .  "transfer/deferContigRequest  -request $request\n"
	     .  "\n";

    $message .= "In order to list requests that relate to you use :\n\n"
             .  "transfer/listContigRequest  [-longlist]\n\n";

    $message .= "In order to execute your approved requests use :\n\n"
             .  "executeContigRequest [-request $request]\n\n";

    $message .= "Most of these scripts come with additional options. Get a \n"
	     .  "parameter list or synopsis with the '-h' or the '-s' switch\n\n";

# add the message to the queue

    $adb->logMessage($owner,$cproject,$message) unless $in;
    $adb->logMessage($owner,$tproject,$message) if $in;
}

#-----------------------------------------------------------------------------

sub sendMessage {
    my ($user,$message) = @_;

    print STDOUT "message to be emailed to user $user:\n$message\n\n";

    $user = 'ejz' if ($user eq 'arcturus');

$user="ejz+$user"; # temporary redirect

    my $mail = new Mail::Send;
    $mail->to($user);
    $mail->subject("Arcturus contig transfer requests");
    $mail->add("X-Arcturus", "contig-transfer-manager");
    my $handle = $mail->open;
    print $handle "$message\n";
    $handle->close;
    
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage { 
    my $code = shift || 0;
    my $long = shift || 0;
    my $action = shift;

    my %section = (transfer=>1,cancel=>2,grant=>2,defer=>2,reject=>2,execute=>3,
                    list=>4,longlist=>4);
    my $help = ($action ? $section{$action} : 0);

    if ($long) {
        print STDERR "\n";
        print STDERR " contig-transfer-manager" . ($action ? " ($action) ":" ");
        print STDERR ": OVERVIEW\n";
        unless ($action) {
            print STDERR "\n";
            print STDERR " Allocate contig(s) to a specified project (split)\n";
            print STDERR "\n";
            print STDERR " Select one of the following options:\n";
            print STDERR "\n";
            print STDERR "-transfer\n";
            print STDERR "-grant , -reject , -defer , -cancel\n";
            print STDERR "-execute\n";
            print STDERR "-list , -longlist\n";
        }
        if ($help == 1) {
            print STDERR "\n";
            print STDERR " Issue a request to allocate contig(s) to a specified ";
            print STDERR "project (split)\n";
            print STDERR "\n";
            print STDERR " Transfer requests are entered into a queue. If you have ";
            print STDERR "the appropriate privilege\n a request is entered with ";
            print STDERR "status 'approved'. If, conversely, approval is required\n ";
            print STDERR "from another Arcturus user, the request will be entered as ";
            print STDERR "'pending'; in addition,\n a mail message will be sent to ";
            print STDERR "inform that user that action is required on your\n request ";
            print STDERR "(approval or otherwise). 'approved' transfer requests are ";
            print STDERR "executed\n separately by using this script in '-execute' ";
            print STDERR "mode (by a privileged user)\n";
            print STDERR "\n";
            print STDERR " You can only issue a transfer request if you have (owner ";
            print STDERR "or other) privilege on\n";
            print STDERR " at least one of the projects involved\n";
            print STDERR "\n";
            print STDERR " A contig can be specified on the command line by a ";
            print STDERR "contig ID or by the name of\n a read occurring in it.";
            print STDERR " Further, a list of contig identifiers can be presented in\n";
            print STDERR " a file using the '-focn' option; in these cases the target";
            print STDERR " project ** must ** be\n specified on the command line.\n";
            print STDERR "\n";
            print STDERR " Alternatively, a list of contig identifier and project pairs can";
            print STDERR " be presented in\n a file using the '-focpn' option. In that";
            print STDERR " case ** no ** project can be specified\n on the command line\n";
            print STDERR "\n";
            print STDERR " Both project and assembly can be specified by ";
            print STDERR "number (ID) or by name;\n";
            print STDERR " the assembly has to be specified in case of ambiguity\n"; 
            print STDERR "\n";
            print STDERR " Use the '-comment' switch to add additional information\n";
            print STDERR "\n";
            print STDERR " When entering a request you will get a preview of how ";
            print STDERR "Arcturus will (try to) deal\n with it; ";
            print STDERR "to commit a valid transfer request to the queue the ";
            print STDERR "'-commit' switch\n *must* be used\n";
        }
	if ($help == 2) {
            print STDERR "\n";
            print STDERR " ".ucfirst($action)." a"
                       . ($action eq 'defer' ? " decision about a " : " ")
                       . "'pending' request\n";
            print STDERR "\n";
            print STDERR " This command operates on one pending request only, which ";
            print STDERR "*has* to be specified\n with the '-request' switch. In its ";
            print STDERR "absence a list will be displayed of all, if\n any, pending ";
            print STDERR "requests involving projects relating to you (as owner or ";
            print STDERR "otherwise)\n The selection may be restricted by specifying ";
            print STDERR "additional constrainst (e.g. the\n project, ownership of ";
            print STDERR "the request, etc.)\n";
            print STDERR "\n";
            print STDERR " Use the '-comment' switch to add your remarks as reviewer.\n";
            if ($action eq 'defer') {
                print STDERR " (Recommended, as a sign that you are considering ";
                print STDERR "the request)\n";
	    }
            print STDERR "\n";
            print STDERR " The '$action' action will only take effect when the ";
            print STDERR "'-commit' switch is used,\n with one proviso: ";
            if ($action eq 'cancel') {
                print STDERR "you can only cancel your own requests; requests made ";
                print STDERR "by\n other users have to be rejected\n";
            }
            else {
                print STDERR "if you are ${action}ing on behalf of another user ";
                print STDERR "(that is you're\n not the owner of the projects ";
                print STDERR "involved, but do have the required privilege),\n then ";
                print STDERR "you must also use the '-force' switch. (This is meant ";
                print STDERR "as safeguard to\n give some protection against you ";
                print STDERR "operating on requests by accident).\n";
	    }
        }
        elsif ($help == 3) {
            print STDERR "\n";
            print STDERR " Execute 'approved' requests\n";
            print STDERR "\n";
            print STDERR " This command implements approved requests relating to you ";
            print STDERR "(as owner or otherwise).\n";
            print STDERR " The selection may be restricted by specifying a particular ";
            print STDERR "request ID and/or other\n constrainst (e.g. the project, ";
            print STDERR "ownership, etc.)\n";
            print STDERR "\n";
            print STDERR " To execute the selected request(s) add '-commit'\n";
            print STDERR "\n";
            print STDERR " When processing a transfer request, one of three things ";
            print STDERR "can happen:\n\n 1) The transfer is completed normally.\n";
            print STDERR " 2) It aborts because e.g. the contig does not anymore ";
            print STDERR "belong to the current generation;\n    the request status ";
            print STDERR "is set to 'failed'\n";
            print STDERR " 3) It bounces because the project the contig is in is ";
            print STDERR "locked by another user;\n    the request will be re-queued\n";
            print STDERR "\n";
        }
        elsif ($help == 4) { 
            print STDERR "\n";
            print STDERR " List ".($action eq 'list' ? "pending and approved" : "all")
                       . " requests\n";
            print STDERR "\n";
            print STDERR " The selection may be restricted by specifying a particular ";
            print STDERR "request ID and/or other\n constrainst (e.g. the project, ";
            print STDERR "ownership, etc.)\n";
        }

        print STDERR "\n\n";
        unless ($long == 1) {
            print STDERR "** Use the '-h' switch for parameter information **\n";
            print STDERR "\n";
            print STDERR "++ questions and comments to Ed Zuiderwijk (ejz) ++\n";
            print STDERR "\n";
            exit 0;
        }
    }

    print STDERR "\n";
    print STDERR "contig-transfer-manager" . ($action ? " ($action) " : " ") . ":\n";
    print STDERR "\n" if $code;
    print STDERR "Parameter input ERROR: ** $code **\n" if $code;

    unless ($organism && $instance) {
        print STDERR "\n";
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\teither 'prod' or 'dev'\n" unless $instance;
    }
# help level 0
    unless ($help) {
        print STDERR "\n";
        print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-transfer\t(no value) create a new request\n";
        print STDERR "-cancel\t\t(no value) remove a pending request from the queue\n";
        print STDERR "-grant\t\t(no value) approve a pending request\n";
        print STDERR "-defer\t\t(no value) delay a decision on a pending request\n";
        print STDERR "-reject\t\t(no value) reject pending request\n";
        print STDERR "\n";
        print STDERR "-list\t\t (default) show all pending requests relating to you\n";
        print STDERR "-longlist\t(no value) show all requests relating to you\n";
        print STDERR "\n";
        print STDERR "** select one of these options **\n";
    }

    if ($help == 1) { # parameters for transfer function
        print STDERR "\n";
        print STDERR "MANDATORY PARAMETER:\n";
        print STDERR "\n";
        print STDERR "-project\tproject ID or projectname (except with '-focpn')\n";
        print STDERR "\n";
        print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-contig\t\tcontig ID or name of constituent read, or";
        print STDERR " comma-separated list of these\n";
        print STDERR "-fofn\t\t(-focn) filename with list of contig IDs or names\n";
        print STDERR "-focpn\t\tfilename with list of contig ID/name and project ID/name";
        print STDERR " pairs\n";
        print STDERR "-foccn\t\tfilename with list of two contig IDs/names per line, ";
        print STDERR "the first\n";
        print STDERR "\t\tof the contig to be moved to the project of the second\n";
        print STDERR "\n";
        print STDERR "OPTIONAL PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-assembly\tassembly ID or assemblyname\n";
        print STDERR "-comment\tany information explaining the request\n";
#        print STDERR "-openproject\tcomma-separated list of open projects (default ";
#        print STDERR "'BIN,TRASH')\n";
        print STDERR "\n";
        print STDERR "-commit\t\t(no value) to enter the request into the database\n";
    }
    elsif ($help == 2) {
        print STDERR "\n";
        print STDERR "MANDATORY/OPTIONAL PARAMETER:\n";
        print STDERR "\n";
        print STDERR "-request\trequest ID; if absent, defaulting to list mode\n";
        print STDERR "\n";
        print STDERR "OPTIONAL PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-owner\t\tthe owner/originator of the request\n";
        print STDERR "-project\tproject ID or projectname\n";
        print STDERR "-assembly\tassembly ID or assemblyname (only with '-project')\n";
        print STDERR "-contig\t\tcontig ID or name of a constituent read\n";
        print STDERR "\n";
        print STDERR "-commit\t\t(no value) to execute on the database\n";
        print STDERR "-force\t\t(no value) to operate on requests owned by other ";
        print STDERR "users (requires privilege)\n";
    }
    elsif ($help) {
        print STDERR "\n";
        print STDERR "OPTIONAL PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-request\trequest ID\n";
        print STDERR "-owner\t\tthe owner/originator of the request\n";
        print STDERR "-project\tproject ID or projectname\n";
        print STDERR "-assembly\tassembly ID or assemblyname (only with '-project')\n";
        print STDERR "-contig\t\tcontig ID or name of a constituent read\n";
        if ($help == 3) { # execute
            print STDERR "\n";
            print STDERR "-commit\t\t(no value) to execute the selected request(s)\n";
	}
        else { # specific for listing
            print STDERR "-before\t\tdate of last review\n";
            print STDERR "-after\t\tdate of last review\n";
            print STDERR "-since\t\tcreation date or :today, yesterday, week\n";
        }
    }
    print STDERR "\n" if $code;
    print STDERR "Parameter input ERROR: ** $code **\n" if $code; 
    print STDERR "\n";
    unless ($long) {
        print STDERR "** Use the '-s' switch for a synopsis **\n";
        print STDERR "\n";
    }

    print STDERR "++ questions and comments to Ed Zuiderwijk (email:ejz) ++\n";
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
