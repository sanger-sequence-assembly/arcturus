package LigationReader;

# read Ligation data from Oracle database


use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

$VERSION = "0.9";

my $DEBUG = 1;

my $PEEKDIR = '/usr/local/badger/bin';

=head1 NAME

TableReader::LigationReader - 

=head1 SYNOPSIS

   use TableReader::LigationReader;

   $trl = TableReader::LigationReader->new($ligation);


=head1 DESCRIPTION

   C<TableReader::LigationReader> 

=cut

###################################################################
# Functions under here are member functions                       #
###################################################################

=head1 CONSTRUCTOR

=item new ( LIGATION )

This is the constructor for a new TableReader::LigationReader object.

=cut

sub new {
   my $prototype = shift;
   my $ligation  = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $self->{"ligation"}  = $ligation;

   bless ($self, $class);
   return $self;
}

# destructor

sub DESTROY {
   my $self = shift;

   return 1;
}

=pod
=item build ([SWITCH])

This does the initialisation. SWITCH "off" for full build including hash, else only table columns

=cut

sub build {
   my $self   = shift;

   my $ligation = $self->{'ligation'};

   my $count = 0;

   print "Polling the ORACLE database ... be patient, please ....\n";
   my @fields = `$PEEKDIR/peek ligation $ligation`; # execute Oracle query
   print "<br>" if $ENV{'PATH_INFO'}; # CGI mode
   if (!@fields) {
# try a recovery by going to another machine
       @fields = `/usr/bin/rsh babel "$PEEKDIR/peek ligation $ligation"`; # execute Oracle query
 print "recovered peek: @{fields}<br>\n";
   }

   undef my @plates;
   undef my %contents;
   foreach my $field (@fields) {
       my ($item, $value,$other) = split /[\s\:]+/,$field;
       $value =~ s/\"//g;
       if ($item =~ /plate/i) {
           push @plates, $value;
       } else {
       #decode this lot
           if ($item =~ /size/i) {
               $value *= 1000; $value /= 1000 if ($value > 10E4);
               $other *= 1000; $other /= 1000 if ($other > 10E4);
               $contents{'SIL'} = $value;
               $contents{'SIH'} = $other;
               $count += 2;
           } else {
               $item =~ s/lig\w+/LG/i;
               $item =~ s/clo\w+/CN/i;
               $item =~ s/seq\w+/SV/i;
               $item =~ s/sta\w+/LS/i;
               $contents{$item} = $value;
               $count++;
           }
       }
   # if any plates defined set up an alternative to CN
       if (@plates) {
           $contents{'cn'} = join ' ',@plates;
       } else {
           $contents{'cn'} = ' ';
       }

       $self->{'plates'} = \@plates;
       $self->{'lgdata'} = \%contents;
   }

#   foreach my $key (sort keys %contents) {
#       print "$key $contents{$key}\n";
#   }

   return $count;
}

# get hash value for given name

sub get {
    my $self = shift;
    my $name = shift;

    my $ligation = $self->{'lgdata'};

    $ligation->{$name};
}

=pod

=head1 LIMITATIONS/BUGS


=head1 AUTHOR

Ed Zuiderwijk <ejz@sanger.ac.uk>

=head1 COPYRIGHT

Copyright (c) 2000 E.J. Zuiderwijk.  All rights reserved.

=cut

#
# End code.
#
1;
