package ExpFileReadFactory;

use strict;

use ReadFactory;

use Read;

our (@ISA);

@ISA = qw(ReadFactory);

#------------------------------------------------------------
# constructor takes directory information where to find files
#------------------------------------------------------------

sub new {

    my $class = shift;

# invoke the constructor of the superclass

    my $this = $class->SUPER::new();

# parse the input parameters

    my ($root, $sub, $includes, $excludes);

    while (my $nextword = shift) {

        $root = shift if ($nextword eq 'root');

        $sub  = shift if ($nextword eq 'sub');

        $includes = shift if ($nextword eq 'include');

        $excludes = shift if ($nextword eq 'exclude');
    }

# set up buffer for possibly included files

    my $includeset;
    if (ref($includes) eq 'ARRAY') {
        $includeset = {};
        while (my $readname = shift @$includes) {
            $includeset->{$readname} = 1;
        }
    }
    elsif ($includes) {
        die "ExpFileReadFactory constructor expects an 'include' array";
    }     

# set up buffer for possibly excluded or included files

    my $excludeset = {};
    if (ref($excludes) eq 'ARRAY') {
        while (my $readname = shift @$excludes) {
            $excludeset->{$readname} = 1;
        }
    }
    elsif ($excludes) {
        die "ExpFileReadFactory constructor expects an 'exclude' array";
    }     

# scan the directories and sub dir and build a list of filenames
    return $this;
}

