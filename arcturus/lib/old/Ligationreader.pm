package Ligationreader;

# read Ligation and Clone data from Oracle database

use strict;
use vars qw($VERSION);

$VERSION = "0.9";

use Tracking;

my $tracking;

my $DEBUG = 1;

my $PEEKDIR = '/usr/local/badger/bin';
#$PEEKDIR = '/nfs/team81/ejz/arcturus/server/cgi-bin'; # temporary

###################################################################

sub new {
    my $prototype = shift;
    my $peekdir   = shift;

    my $ligation  = shift;

    my $class = ref($prototype) || $prototype;
    my $self  = {};

    $PEEKDIR = $peekdir if $peekdir;

# print "$ENV{PERL5LIB}   .= ':/usr/local/badger/bin';

#print "opening Ligationreader ( $ENV{PERL5LIB},  $PEEKDIR ) \n";
    $tracking = Tracking->new();

    $self->{lgdata}  = {};
    $self->{cndata}  = {};

    bless ($self, $class);
    return $self;
}

###################################################################

sub newLigation {
    my $self     = shift;
    my $ligation = shift;
    my $connect  = shift;

    my $count = 0;

    print "Polling the ORACLE database ... be patient, please ....\n";
    my @fields = `$PEEKDIR/peek ligation $ligation`;
    print "<br>" if $ENV{'PATH_INFO'}; # CGI mode

    if (!@fields) {
# try a recovery by going to another machine
        @fields = `/usr/bin/rsh babel "$PEEKDIR/peek ligation $ligation"`;
# print "recovered peek: @{fields}<br>\n";
    }

    undef my @plates;
    undef my %contents;
    foreach my $field (@fields) {
        my ($item, $value, $other) = split /[\s\:]+/,$field;
        $value =~ s/\"//g;
        if ($item =~ /plate/i) {
            push @plates, $value;
        } 
        elsif ($item =~ /size/i) {
            $value *= 1000; $value /= 1000 if ($value > 10E4);
            $other *= 1000; $other /= 1000 if ($other > 10E4);
            $contents{SIL} = $value;
            $contents{SIH} = $other;
            $count += 2;
        }
        else {
            $item =~ s/lig\w+/LG/i;
            $item =~ s/clo\w+/CN/i;
            $item =~ s/seq\w+/SV/i;
            $item =~ s/sta\w+/LS/i;
            $contents{$item} = $value;
            $count++;
        }
   # if any plates defined set up an alternative to CN
        if (@plates) {
            $contents{cn} = join ' ',@plates;
        }
        else {
            $contents{cn} = ' ';
        }

        $self->{plates} = \@plates;
        $self->{lgdata} = \%contents;

    }

# check clone info if available

    if ($connect && (my $cname = $self->{lgdata}->{CN})) {
        my $clone = $self->{cndata}->{CN}; # the current clone data
        newClone->($self,$cname,0) if (!$clone || $clone ne $cname);
    }

    return $count; # count > 0 for success
}

###################################################################

sub list {
# return a list string
    my $self = shift;
    my $LIST = shift;

    my $list;
    my $contents = $self->{lgdata};
    if ($contents && keys %$contents) {
        $list = "Current Ligation data:\n";
        foreach my $key (sort keys %$contents) {
            $list .= "$key $contents->{$key}\n";
        }
        $list .= "\n";
    }
    else {
        $list = "No Ligation data stored\n";
    }

    $contents = $self->{cndata};
    if ($contents && keys %$contents) {
        $list .= "Current Clone data:\n";
        foreach my $key (sort keys %$contents) {
            $list .= "$key $contents->{$key}\n";
        }
        $list .= "\n";
    }
    else {
        $list .= "No Clone data stored\n";
    }

    print STDOUT "$list\n" if $LIST;
    $list;
}

###################################################################

sub get {
# return hash value for item
    my $self = shift;
    my $item = shift;

    my $output = $self->{lgdata}->{$item};
    $output = $self->{cndata}->{$item} if !$output;

    $output;
}

####################################################################

sub newClone {
# retrieve data for a named clone 
    my $self      = shift;
    my $clonename = shift;
    my $connect   = shift;

    print "Tracking the ORACLE database .... be patient, please ....\n";
    $self->{cndata} = $tracking->get_clone_info($clonename);
    return 0 if !$self->{cndata}; # protection
    print "<br>" if $ENV{'PATH_INFO'}; # CGI mode

    my $count = keys %{$self->{cndata}};
    $self->{cndata}->{CN} = $clonename if ($count);

# check ligation info if available

    if ($connect && (my $cname = $self->{cndata}->{CN})) {
        my $clone = $self->{lgdata}->{CN};
        if (!$clone || $clone ne $cname) {
            print "Peeking the ORACLE database ... be patient, please ....\n";
            my @fields = `$PEEKDIR/peek clone $cname`; # execute Oracle query
            print "<br>" if $ENV{'PATH_INFO'}; # CGI mode
            undef my @ligations;
            foreach my $field (@fields) {
                my ($item, $value, $other) = split /[\s\:]+/,$field;
                $value =~ s/\"//g; # remove clutter, if any
                push @ligations, $value  if ($item =~ /ligation/i);
            }
        # store ligations as a string
            $self->{cndata}->{ligations} = join ' ',@ligations;
        # if one ligation: load it
            if (@ligations == 1) {
                newLigation($self,$ligations[0],0);
            }
        }
    }

    return $count;
}

####################################################################

1;









