package Projects;

#########################################################################
#
# Operations on an individual project
#
#########################################################################

use strict;

use ArcturusTableRow;

use vars qw(@ISA); # our qw(@ISA);

@ISA = qw(ArcturusTableRow);

#########################################################################
# Class variables
#########################################################################

my %Projects;

my $break = $ENV{REQUEST_METHOD} ? "<br>" : "\n";

#########################################################################
# constructor new: create an Projects instance
#########################################################################

sub new {
# create a new instance for the named or numbered project
    my $caller   = shift;
    my $project  = shift || 0; # optional, a number or name
    my $Assembly = shift;      # optional, pass it an assembly object

    return $Projects{$project} if $Projects{$project};

    my $class = ref($caller) || $caller;

    my $PROJECTS; # for the handle to the PROJECTS database table

    if ($class eq ref($caller) && !$Assembly) {
# the new object is spawned from an existing instance of this class
        $Assembly = $caller->{Assembly};
        $PROJECTS = $caller->tableHandle;
    }

# test the database table handle

    if (!$PROJECTS) {
# here we need to inherit from Assembly, which therefore must exist
        die "Missing Assembly reference for new Project" unless $Assembly;
        my $tableHandle = $Assembly->tableHandle; # of the ASSEMBLY table
# spawn the PROJECTS database table handle
        $PROJECTS = $tableHandle->spawn('PROJECTS');
    }

# okay, we seem to have everything to build a new instance

    my $self = $class->SUPER::new($PROJECTS);

# now fill the instance with data; the reference to the parent Assembly instance

    $self->{Assembly} = $Assembly;

# identify the project, either by number or by name and get the data

    my $loaded;

    if (!$project) {
# get the default project for the assembly
        $self = $self->getDefaultProject($Assembly);
        $loaded = 1 unless $self->status(1);
    }
    else {
# decide if it is a name or a number
        my $column = ($project =~ /\D/) ? 'projectname' : 'project';
        $loaded = $self->loadRecord($column,$project);
#my $status = $self->status; print "$column $project status: $status $break"; 
    }

# add this project to inventory of instances

    if ($loaded) {
# define the deault column
        $self->setDefaultColumn('projectname');
# perhaps include organism as wel?
        my $contents = $self->{contents};
        $Projects{$contents->{project}}     = $self;
        $Projects{$contents->{projectname}} = $self;
    }

    return $self; # possible error status to be tested
}

#############################################################################
# these methods can be used as instance methods and as class methods
#############################################################################

sub getDefaultProject {
# get/add the BIN project to the PROJECTS table for a give assembly
    my $self     = shift;
    my $Assembly = shift; # optional, pass it an Assembly object
    my $new      = shift;

    $Assembly = $self->{Assembly} unless $Assembly;

    return 0 if (ref($Assembly) ne 'Assembly');

    my $aname = $Assembly->get('assemblyname');

    my $default = $aname.'BIN'; # default project for the given assembly

    return $Projects{$default} if $Projects{$default};

    my $tableHandle = $self->tableHandle; # = $self->{table}

    my $project = $tableHandle->associate('project',$default,'projectname');

# if the default project already exists for this assembly, spawn/return its Project instance

    return $self->new($project) if $project; # returns a new instance

# the project does not yet exist, hence create it (inherit data from assembly)

    my $auser = $Assembly->get('creator');
    my $anmbr = $Assembly->get('assembly');

    $self->put('projectname',$default);
    $self->put('assembly',$anmbr);
    $self->put('comment','auto-generated by Projects module');
    my $timestamp = $tableHandle->timestamp(0);
    $self->put('created',$timestamp);
    $self->put('creator',$auser);

# write the new row to the table; then either load the data or spawn a new instance

# an error status is handled by newRow and can be tested afterwards 

    if ($self->newRow()) {
# project added okay; update the row in the ASSEMBLY table
        my $count = $self->count("assembly=$anmbr") || 'projects+1'; # print "count $count $break";
        $Assembly->put('projects',$count,1);
# either spawn a new instance (forced with $new)
        return $self->new($project) if $new;
# or (re)load the date into this instance
        $self->loadRecord('projectname',$project);
    }

    return $self; # always returns an instance
}

#############################################################################

sub getProjects {
# return a list of all project names, or those for a given assembly
    my $self     = shift;
    my $Assembly = shift; # optional, pass an Assembly object

    $Assembly = $self->{Assembly} if ($Assembly =~ /self/i);

    return $self->getDefaultColumn() unless $Assembly; # return ALL projects

# return projects for the specified assembly only

    my $where = "assembly=".$Assembly->get('assembly');
       
    return $self->getDefaultColumn($where);
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>       "group 81",
        version =>             0.9 ,
        updated =>    "18 Feb 2004",
        date    =>    "10 Feb 2004",
    };
}

#############################################################################

1;
