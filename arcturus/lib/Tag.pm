package Tag;

use strict;






sub new {

    my $class = shift;
    my $type = shift;

    my $this = {};

    bless $this, $class;

    return $this;
}

sub readTag {
    my $this = shift;
    my $data = shift;
    print "readTag detected $data\n";
}

sub editReplace {
    my $this = shift;
    my $data = shift;
    print "editReplace tag detected $data\n";

}

sub editDelete {
    my $this = shift;
    my $data = shift;
    print "editDelete tag detected $data\n";

}

sub contigTag {
    my $this = shift;
    my $data = shift;
#    print "Contig TAG detected $data\n";

}

1;
