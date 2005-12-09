#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Logging;

require Mail::Send;

#----------------------------------------------------------------

my $organism;
my $instance;
my $action = 'list';
my $project;
my $assembly;
my $contig;
my $fofn;
my $user;
my $owner;
my $request;
my $openproject = 'BIN,TRASH';
my $confirm;
my $force;
my $comment;

my $verbose;
my $testmode;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $actions = "transfer|grant|wait|defer|cancel|reject|execute|reschedule|probe";

my $validKeys = "organism|instance|$actions|"
#              . "transfer|grant|wait|defer|cancel|reject|execute|reschedule|probe|"
              . "contig|fofn|project|assembly|"
              . "user|owner|request|comment|"
              . "list|longlist|"
              . "openproject|confirm|force|preview|test|help|verbose";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

# the next die statement prevents redefinition when used with e.g. a wrapper script 

    die "You can't re-define instance" if ($instance && $nextword eq '-instance');

    $instance    = shift @ARGV  if ($nextword eq '-instance');

    die "You can't re-define organism" if ($organism && $nextword eq '-organism');

    $organism    = shift @ARGV  if ($nextword eq '-organism');

    die "You can't re-define action" if ($action && $nextword =~ /\-($actions)\b/);

    $action      = 'transfer'   if ($nextword eq '-transfer');

    $action      = 'cancel'     if ($nextword eq '-cancel');

    $action      = 'execute'    if ($nextword eq '-execute');

    $action      = 'grant'      if ($nextword eq '-grant');

    $action      = 'wait'       if ($nextword eq '-wait');
    $action      = 'wait'       if ($nextword eq '-defer');

    $action      = 'deny'       if ($nextword eq '-reject');

    $action      = 'reenter'    if ($nextword eq '-reschedule');

    $action      = 'probe'      if ($nextword eq '-probe');

    $action      = 'list'       if ($nextword eq '-list'); # pending requests only

    $action      = 'longlist'   if ($nextword eq '-longlist'); # all requests

    $project     = shift @ARGV  if ($nextword eq '-project');

    $assembly    = shift @ARGV  if ($nextword eq '-assembly');

    $contig      = shift @ARGV  if ($nextword eq '-contig');

    $fofn        = shift @ARGV  if ($nextword eq '-fofn');

    $user        = shift @ARGV  if ($nextword eq '-user');

    $owner       = shift @ARGV  if ($nextword eq '-owner');

    $request     = shift @ARGV  if ($nextword eq '-request');

    $comment     = shift @ARGV  if ($nextword eq '-comment');

    $openproject = shift @ARGV  if ($nextword eq '-openproject');

    $verbose     = 1            if ($nextword eq '-verbose');
 
    $confirm     = 1            if ($nextword eq '-confirm' && !defined($confirm));

    $confirm     = 0            if ($nextword eq '-preview');

    $force       = 1            if ($nextword eq '-force');

    $testmode    = 1            if ($nextword eq '-test');

    &showUsage(0,1) if ($nextword eq '-help'); # long write up
}
 
#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging('STDOUT');
 
$logger->setFilter(0) if $verbose; # set reporting level
 
#----------------------------------------------------------------
# test input parameters
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

# contig identifier is mandatory for 'transfer', optional otherwise

if ($action eq 'transfer') {
# project and contig identifiers must be given; user is ignored
    &showUsage("Missing contig identifier or fofn") unless ($contig || $fofn);

    &showUsage("Missing project ID or projectname") unless $project;

    if ($user || $owner || $request) {
        $logger->warning("Redundant keyword(s) ignored");
    }
}
else {
# fofn may not be specified, only a contig ID allowed
    &showUsage("Invalid key 'fofn' for '$action' action") if $fofn;
}

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
    &showUsage("Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");
    
$logger->skip();

$user = 'ejztst' if ($testmode && !$user);
$adb->{ArcturusUser} = $user if $testmode;

#----------------------------------------------------------------
# preliminaries: get (possible) contig and/or project info
#----------------------------------------------------------------

my $cids;

$cids = &getContigIdentifiers($contig,$fofn,$adb) if ($contig || $fofn);


# get the project and assembly information (ID or name for both)

my ($Project,$pid);

$Project = &getProjectInstance($project,$assembly,$adb) if $project;

# disable for testmode with non existent projects

unless ($Project) {
# TEMPORARY provision for TEST mode when no valid project specified
    if ($project && !$testmode) {
# invalid project identifier (all cases)
        $adb->disconnect();
        exit 0;
    }
    if ($project && $testmode) {
print STDERR "creating test project with project ID $project\n";
        my $p = new Project();
        $p->setProjectName("project $project");
        $p->setProjectID($project);
        $project = $p;
    }
}

$pid = $Project->getProjectID() if $Project;
 
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

    my %options = (open=>$openproject);
$options{user} = $user if $user;
    $options{requester_comment} = $comment if $comment;
#$pid=7;

    foreach my $contig (@$cids) {

        my ($status,$message) = &createContigTransferRequest($adb,$contig,$pid,
                                                             $confirm,%options);
        if ($status == 1) {
            $logger->warning("A request to transfer contig $contig to project ".
                             $Project->getProjectName()." is queued : $message");
        }
        elsif ($status == 2) {
            $logger->warning("$message \n=> use -confirm");
	}
        else {
            $logger->warning("transfer request is REJECTED : $message");
        }  
    }
}

#----------------------------------------------------------------
# LIST requests (default if NO specific request ID is specified) 
#----------------------------------------------------------------

elsif ($action eq 'list' or $action eq 'longlist' or (!$request && $action ne 'execute')) {
# if NO specific request ID is specified all these options revert to 'list'
    my %options;
    $options{requester} = $user if $user;
    $options{requester} = $owner if $owner;
    $options{contig_id} = $contig if $contig;
    $options{projectids} = $pid if $pid;
    $options{request_id} = $request if $request;

    unless ($options{projectids}) {
# default selection of projects to be used
        my $projectids = $adb->getAccessibleProjects();
        $options{projectids} = join ',',@$projectids  if @$projectids;
# if this user has no access to any project add owner if not already done
        unless (@$projectids || $options{owner}) {
            $options{owner} = $adb->getArcturusUser();
        }
    }

# get request IDs for input parameter options

    my $full = ($action eq 'longlist' ? 1 : 0);
    my $requestsfound = $adb->getContigTransferRequestIDs($full,%options);

# print out

    my $header;
    my $linemode = 1;
    if ($requestsfound && @$requestsfound > 1) {
        $header = " ID  contig projects owner       created       "
                . "     reviewed          by      status comments";
    }
    elsif ($requestsfound && @$requestsfound == 1) {
        $linemode = 0;
    }
    else {
        $user = $adb->getArcturusUser();
        $header = "There are NO transfer requests involving user $user";
    }

    $logger->skip();
    $logger->warning($header);
    $logger->skip();

    foreach my $request (@$requestsfound) {
        my $rd = $adb->getContigTransferRequestData($request);
# get comment information
        $user = $adb->getArcturusUser();
        if ($linemode) {
            my $comment = $rd->{requester_comment};
            $comment .= " " if $comment;
            $comment .= "$rd->{reviewer_comment}";
            unless ($comment || $rd->{status} ne 'pending') {
                $comment  = "AWAITING approval";
                $comment .= " by $rd->{reviewer}" if ($rd->{reviewer} ne $user);
	    }
            my $line = sprintf("%3d %7d %2d > %-2d %6s %19s %19s %6s %10s %-40s",
                       $rd->{request_id},$rd->{contig_id},$rd->{old_project_id},
        	       $rd->{new_project_id},$rd->{requester},$rd->{opened},
	               $rd->{reviewed},$rd->{reviewer},$rd->{status},$comment);
            $logger->warning($line);
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
            $logger->skip();
	}

    }
    $logger->skip();
}

#------------------------------------------------------------------------------
# CANCEL, GRANT or REJECT a request; these options come with confirm/force mode
#------------------------------------------------------------------------------

if ($action =~ /\b(grant|wait|cancel|deny|reenter)\b/) {

    my %options;
    $options{requester} = $user if $user;
    $options{requester} = $owner if $owner;
    $options{contig_id} = $contig if $contig;
    $options{projectids} = $pid if $pid;

# check if the request exists

    $options{request_id} = $request;
    $options{status} = 'pending' unless ($action eq 'reenter');
    $options{status} .= ',approved'  if ($action eq 'cancel');

    my $datamode = ($action eq 'reenter' ? 2 : 1);
    my $requestsfound = $adb->getContigTransferRequestIDs($datamode,%options);

    if ($requestsfound && @$requestsfound && $requestsfound->[0] == $request) {
# get request details
        my $hash = $adb->getContigTransferRequestData($request);
        my $description = "$hash->{request_id} (move contig "
                        . "$hash->{contig_id} to project "
	        	. "$hash->{new_project_id} for user "
                        . "$hash->{requester})";
# and prepare for some intelligible messages
        my ($operation,$status,$report);

        $operation = "cancelled"  if ($action eq 'cancel');
        $operation = "approved"   if ($action eq 'grant');
        $operation = "refused"    if ($action eq 'deny');
        $operation = "re-entered" if ($action eq 'reenter');
        $operation = "marked for later consideration" if ($action eq 'wait');

# adjust the force flag, if any (=1 to test requestor against user, =2 to include reviewer)

        $force = 2 if ($force && $action ne 'cancel');

        if (!$confirm) {
            $logger->warning("request $description is to be $operation\n=> use -confirm");
        }


        if ($action eq 'wait') {
            $comment = "" unless $comment;
            $comment = " ($comment)" if $comment;
            $comment = "will be considered later".$comment;
           ($status,$report) = $adb->modifyContigTransferRequest($request,$force,
					            reviewer_comment => $comment);
        }

        elsif ($action eq 'reenter') {
# only for dba
   	    my %options = (status => 'pending');
            $options{requester_comment} = "previously $hash->{status} request was re-entered"
                                       . ($comment ? ": $comment" : "");
            undef $options{reviewer_comment};
            undef $options{closed};
           ($status,$report) = $adb->modifyContigTransferRequest($request,$force,%options);
        }

        else {
# the 'force' flag is required if invoked by other than owner
   	    my %options = (status => $operation);
            $options{reviewer_comment} = $comment; # clears existing if not defined
           ($status,$report) = $adb->modifyContigTransferRequest($request,$force,%options);
        }

# test status and report on command line

        if ($status) {
            $logger->warning("operation successful : request $description is $operation");
	    if ($status == 2) {
                &sendMessage($hash->{requester}, "your request $description was $operation "
                                               . "by user ".$adb->getArcturusUser());
	    }
        }
        elsif ($confirm) {
            $logger->warning("operation refused : $report");
        }
    }
    else {
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
        my $requester = $rd->{requester};

# test current generation the contig is in, and the current project

        my $cid = $rd->{contig_id};
        unless ($adb->isCurrentContigID($cid)) {
            my $report = "contig $cid is not (anymore) in the current generation";
            $logger->warning($report);
            next unless $confirm;
            $adb->modifyContigTransferRequest($request,2,status =>'failed',
                                               reviewer_comment =>"expired generation");
            &sendMessage($requester,"contig $cid could not be transfered: $report");
            next;
        }

        my $pid = $rd->{old_project_id};
        my ($cpid,$lock) = $adb->getProjectIDforContigID($cid); # current project ID
        unless ($pid == $cpid) {
            my $report = "contig $cid is not anymore in project $pid (but is in $cpid)";
            $logger->warning($report);
            next unless $confirm;
            $adb->modifyContigTransferRequest($request,2,status =>'failed',
                                               reviewer_comment =>"expired original project");
            &sendMessage($requester,"contig $cid could not be transfered: $report");
            next;
        }        
        
        unless ($confirm) {
            my $line = sprintf("%3d %7d %2d > %-2d %6s %19s %19s %6s %10s %-40s",
                       $rd->{request_id},$rd->{contig_id},$rd->{old_project_id},
            	       $rd->{new_project_id},$rd->{requester},$rd->{opened},
	               $rd->{reviewed},$rd->{reviewer},$rd->{status},
                       $rd->{reviewer_comment});
            $logger->warning("contig transfer request to be executed:\n".$line);
            next;
        }

# execute the request, first do the status to done (to check access rights)

        my ($status,$report) = $adb->modifyContigTransferRequest($request,2,status=>'done');

        unless ($status) {
            $logger->warning("transfer refused: $report");
            next;
        }

# ok, the operation is authorized

        $pid = $rd->{new_project_id};
       ($status,$report) = $adb->assignContigIDsToProjectID([($cid)],$pid,1);

# status 0, failure project lock (=> back to 'approved' for later execution)
# status 1, success
# status 2, contig already allocated (=> set to 'failed') should not occur


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
            $adb->modifyContigTransferRequest($request,2,status=>'approved');
	}
    }

    $logger->skip();
    $logger->warning("no transfer requests processed") unless $processed;            
    $logger->skip();
}



elsif ($action eq 'probe') {
}

# execute if confirm switch set, else list 
  
$adb->disconnect();

exit 0;

#------------------------------------------------------------------------
# subroutines (ad hoc for this script only)
#------------------------------------------------------------------------

sub getContigIdentifiers {
# ad hoc routine, returns contig IDs specified with $contig, $fofn or both
    my $contig = shift; # contig ID, name or comma-separated list of these
    my $fofn = shift; # filename
    my $adb = shift; # database handle

    my @contigs;

    if ($contig || $fofn) {
# get contig identifiers in array
        if ($contig =~ /\,/) {
            @contigs = split /\,/,$contig;
        }
        elsif ($contig) {
            push @contigs,$contig;
        }
# add possible info from file with names
        if ($fofn) {
            $fofn = &getNamesFromFile($fofn);
            push @contigs,@$fofn;
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

sub getNamesFromFile {
# read a list of names from a file and return an array
    my $file = shift; # file name

    &showUsage(0,"File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage(0,"Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        next unless $name;
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------

sub getProjectInstance {
# returns Project given project ID or name and (optionally) assembly
# (also in case of project ID we consult the database to check its existence)
    my $identifier = shift;  # ID or name
    my $assembly = shift; # ID or name
    my $adb = shift;

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

    return 0,"invalid parameters ($cid,$tpid)" unless ($cid && $tpid);

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

    my ($cpid,$lock) = $adb->getProjectIDforContigID($cid); # current project ID

    if ($cpid == $tpid) {
        return 0,"contig $cid is already allocated to project $tpid";
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
	    return 0,"invalid project name $openprojectname" unless @$projects;
            foreach my $project (@$projects) {
                $open .= " " if $open;
                $open .= $project->[0];
            }
	}
    }

# test access of this user to current project of the contig

    my $cpp = $adb->getAccessibleProjects(project=>$cpid,user=>$user);
    $cpp = (@$cpp ? $cpp->[0] : 0); # replace reference by value
# $cpp = 1 if (!$cpp && $open && $open =~ /\b$cpid\b/); # override open project

# test access of this user to target project

    my $tpp = $adb->getAccessibleProjects(project=>$tpid,user=>$user);
    $tpp = (@$tpp ? $tpp->[0] : 0); # replace reference by value
# $tpp = 1 if (!$tpp && $open && $open =~ /\b$tpid\b/); # override open project

    my @cnames = $adb->getNamesForProjectID($cpid);
    my @tnames = $adb->getNamesForProjectID($tpid);

    return 0,"invalid project ID: project $tpid does not exist" unless $tnames[2];
 
    unless ($cpp || $tpp) {
        return 0, "user $user has no privilege for a transfer from project "
                . "$cnames[0] ($cpid, $cnames[1]) to "
                . "$tnames[0] ($tpid, $tnames[1])";
    }
  
    unless ($confirm) {
        return 2, "contig $cid may be moved from project "
                . "$cnames[0] ($cpid, $cnames[1]) to "
                . "$tnames[0] ($tpid, $tnames[1])";
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
# user has privilege on both (current & destination) projects; add comment if not owner
        unless ($comment || $user eq $cnames[2]) {
     	    $comment = "original contig owner $cnames[2]";
	}
        $adb->modifyContigTransferRequest($rqid,1,status =>'approved',
                                          requester_comment => $comment);
        $status = "approved";
    }
    elsif ($tpp) {
# user has no privilege on the project the contig is currently in
        $status = "waiting for approval by $cnames[2]";
# update the comment (if any) and set the reviewer of the new request
        $adb->modifyContigTransferRequest($rqid,0,requester_comment => $comment,
                                                  reviewer => $cnames[2]);
        &mailMessageToOwner($rqid,$cid,$cnames[0],$tnames[0],$cnames[2],$user,0);
    }
    else {
# user has no privilege on the target project
        $status = "waiting for approval by $tnames[2]";
# update the comment of the new request
        $adb->modifyContigTransferRequest($rqid,1,requester_comment => $comment,
                                                  reviewer => $tnames[2]);
        &mailMessageToOwner($rqid,$cid,$cnames[0],$tnames[0],$tnames[2],$user,1);
    }

    return 1, "request $rqid was created for user $user\n   ($status)"
            . ($message ? "\n$message" : "");
}

sub mailMessageToOwner {
# compose and submit a message to the owner of project 
    my ($request,$contig,$cproject,$tproject,$owner,$requestor,$in) = @_;

    my $message = "user $requestor requests contig $contig to be moved ";
    $message .= "from ".($in ? "" : "your ")." project $cproject "
             .  "into ".($in ? "your " : ""). "project $tproject\n\n";
    $message .= "To cancel, grant or deny this transfer, or to defer a decision,\n"
             .  "execute one of the following commands (use cut & paste):\n\n"; 

    $message .= "grantContigRequest  -request $request\n"
             .  "cancelContigRequest -request $request\n"
             .  "rejectContigRequest -request $request\n"
             .  "deferContigRequest  -request $request\n"
	     .  "\n";

    $message .= "listContigRequests will show all request that relate to you\n\n";

    $message .= "executeContigRequests -request $request will execute your requests\n\n";

    $message .= "\n"; 

    &sendMessage($owner,$message);
}

#-----------------------------------------------------------------------------

sub sendMessage {
    my ($user,$message) = @_;

    print STDOUT "message to be emailed to user $user:\n$message\n\n";
$user='ejz';

    my $mail = new Mail::Send;
    $mail->to($user);
    $mail->subject("your arcturus contig transfer request");
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

    if ($long) {
     print STDERR "\n";
     print STDERR "Allocate contig(s) to a specified project, optionally in a\n";
     print STDERR "specified assembly\n\n";
     print STDERR "A contig can be specified on the command line by a number (ID)\n";
     print STDERR "or by the name of a contig occurring in it; a list of contigs can\n";
     print STDERR "be presented in a file using the '-fofn' option\n\n";
     print STDERR "Both project and assembly can be specified with \n";
     print STDERR "a number (ID) or a name (i.e. not a number)\n\n";
     print STDERR "The allocation process tests the project locking status:\n";
     print STDERR "Contigs will only be (re-)allocated from their current\n";
     print STDERR "project (if any) to the new one specified, if BOTH the\n";
     print STDERR "current project AND the target project are not locked by\n";
     print STDERR "another user. Carefully check the results log!\n\n";
     print STDERR "A special case is when a contig is in a project owned by\n";
     print STDERR "another user, but not locked. In default mode such contigs\n";
     print STDERR "are NOT re-allocated (as a protection measure). In order to \n";
     print STDERR "reassign those contig(s), the '-force' switch must be used.\n\n";
     print STDERR "In default mode this script lists the contigs that it will\n";
     print STDERR "(try to) re-allocate. In order to actually make the change,\n";
     print STDERR "the '-confirm' switch must be used\n";
     print STDERR "\n";
    }
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-instance\teither 'prod' or 'dev'\n";
    print STDERR "-project\tproject ID or projectname\n";
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS (default '-list'):\n";
    print STDERR "\n";
    print STDERR "-transfer\t(no value) create a new request\n";
    print STDERR "-grant\t\t(no value) approve a pending request\n";
    print STDERR "-wait\t\t(no value) delay a decision on a pending request\n";
    print STDERR "-reject\t\t(no value) deny approval of a pending request\n";
    print STDERR "-cancel\t\t(no value) delete a pending request from the queue\n";
    print STDERR "\n";
    print STDERR "-list\t\t(no value) show all pending requests\n";
    print STDERR "-longlist\t(no value) show all requests\n";
    print STDERR "\n";
    print STDERR "MUTUALLY EXCLUSIVE PARAMETERS (mandatory with '-create'):\n";
    print STDERR "\n";
    print STDERR "-contig\t\tcontig ID or name of constituent read\n";
    print STDERR "-fofn\t\tfilename with list of contig IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-assembly\tassembly ID or assemblyname\n";
    print STDERR "-confirm\t(no value) to execute on the database\n";
    print STDERR "-preview\t(no value) produce default listing (negates 'confirm')\n";
    print STDERR "-force\t\t(no value) to process requests allocated to other users\n";
    print STDERR "-verbose\t(no value) \n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
}
