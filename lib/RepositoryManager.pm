package RepositoryManager;

use strict;

use Carp;

use OORepository;

sub new {
    my $class = shift;

    my $this = {};

    bless $this, $class;

    $this->{'OORepository'} = new OORepository();

    return $this;
}

sub getOnlinePath {
    my $this = shift;

    my $alias = shift;

    $this->{'OORepository'}->get_online_path_from_project($alias);

    return $this->{'OORepository'}->{online_path};
}

sub convertMetaDirectoryToAbsolutePath {
    my $this = shift;

    my $metadir = shift;

    my %opts = @_;

    if ($metadir =~ /^:([\w\-]+):/) {
	my $name = $1;

	my $alias = $opts{$name} || $opts{lc($name)} || $name;

	my $location = $this->getOnlinePath($alias);

	croak "Could not find location for $alias" unless defined($location);

	$metadir =~ s/^:$name:/$location/;
    }

    return $metadir;
}

sub convertAbsolutePathToMetaDirectory {
    my $this = shift;

    my $abspath = shift;

    my %opts = @_;

    my $assembly = $opts{'assembly'} || $opts{'ASSEMBLY'};

    if (defined($assembly)) {
	my $location = $this->getOnlinePath($assembly);

	if (defined($location) && $abspath =~ /^$location/) {
	    $abspath =~ s/^$location/:ASSEMBLY:/;
	    return $abspath;
	}
    }

    my $project = $opts{'project'} || $opts{'PROJECT'};

    if (defined($project)) {
	my $location = $this->getOnlinePath($project);

	if (defined($location) && $abspath =~ /^$location/) {
	    $abspath =~ s/^$location/:PROJECT:/;
	    return $abspath;
	}
    }

    return $abspath;
}

1;
