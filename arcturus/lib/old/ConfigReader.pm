package ConfigReader;
#
# Simpleton interface to a configuration file
#
# Adapted from Simple.pm by Bek Oberin 
#
# ObLegalStuff:
#    Copyright (c) 1998 Bek Oberin. All rights reserved. This program is
#    free software; you can redistribute it and/or modify it under the
#    same terms as Perl itself.
# 
# Last updated by EJZ on Fri Nov 24, 2000
#

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

$VERSION = "0.9";

my $DEBUG = 0;

=head1 NAME

ConfigReader::Simple - Simple configuration file parser

=head1 SYNOPSIS

   use ConfigReader::Simple;

   $config = ConfigReader::Simple->new("configrc");

   $config->parse();

=head1 DESCRIPTION

   C<ConfigReader::Simpleton> reads and parses simple configuration files.
   It is designed to be smaller and simpler than the C<ConfigReader> module
   and is more suited to simple configuration files.

=cut

###################################################################
# Functions under here are member functions                       #
###################################################################

=head1 CONSTRUCTOR

=item new ( FILENAME )

This is the constructor for a new ConfigReader::Simple object.

C<FILENAME> tells the instance where to look for the configuration
file.

C<DIRECTIVES> is a reference to an array.  Each member of the array
should contain one valid directive.

=cut

sub new {
   my $prototype = shift;
   my $filename  = shift;
#   my $keyref = shift;

   my $class = ref($prototype) || $prototype;
   my $self  = {};

   $self->{filename} = $filename;
   undef $self->{errors};
#   $self->{validkeys} = $keyref;

   bless($self, $class);
   return $self;
}
#
# destructor
#
sub DESTROY {
   my $self = shift;

   return 1;
}

=pod
=item parse ()

This does the actual work.  No parameters needed.

=cut

sub parse {
   my $self = shift;

   open(CONFIG, $self->{filename}) || return 0;
#      die "Config: Can't open config file " . $self->{filename} . ": $!";

   while (<CONFIG>) {
      chomp;

      s/(\#.*)$//;      # delete everything after a comment
      next if /^\s*$/;  # blank

      my ($key, $value, $type) = &parse_line($_);
#   print "key: $key  $value    $type\n";
      print STDERR "Key:  '$key'   Value:  '$value'\n" if $DEBUG;
      if ($type == 1) { # a scalar
          $self->{config_data}{$key} = $value;
      } elsif ($type==2) { # an array
          @{$self->{config_data}{$key}} = split /\s*\,\s*/,$value;
      } else { # invalid stuff
          print STDERR "Error on configuration file ".$self->{filename}.":\nCan't parse: \"$_\""; 
      }
   }

   close(CONFIG);
   return 1;

}

=pod
=item get ( DIRECTIVE )

Returns the parsed value for that directive.

=cut

sub get {
   my $self = shift;
   my $key  = shift;
   my $test = shift;

   undef my $item;
   $item = $self->{config_data}{$key} if defined($key);

   if (defined($key) && $test) {
       if ($test =~ /insist/i && !defined($item)) {
           $self->{errors} .= "Missing item $key "; 
           $self->{errors} .= "on configuration file $self->{filename}"; 
       }
       if ($test =~ /unique/i && ref($item) eq 'ARRAY') {
           my $size = @$item;
           for (my $i = 1; $i < $size; $i++) {
               for (my $j = $i+1 ; $j < $size ; $j++) {
                   if ($item->[$j] eq $item->[$i]) {
                       $self->{errors} .= "Multiple occurance of $item->[$i] in array $key ";
                       $self->{errors} .= "on configuration file $self->{filename}";
                   } 
               }
           }
       }
       if ($test =~ /array/i && ref($item) ne 'ARRAY') {
           $self->{errors} .= "item $key is not an array "; 
           $self->{errors} .= "on configuration file $self->{filename}"; 
# ? recover possible single array element
#           my @array;
#           push @array, $item;
#           $self->{config_data}{$key} = \@array;
       }
   }

   return $item;
}

sub probe {
# return error status
    my $self  = shift;
    my $reset = shift;

    my $error = $self->{errors};
    undef $self->{errors} if $reset;

    return $error;
}

sub parse_line {
   my $text = shift;

   my ($key, $value, $type);

   $type = 1; # default variable
   if ($text =~ /^\s*(\$|\@)?(\w+)[\s\=]+(['"]?)(\S?.*\S)\3([^\3]*)$/) {
      $type = 1 if ($1 eq '$');
      $type = 2 if ($1 eq '@');
      $key = $2;
      $value = $4;
      print STDERR "Trailing input \"$5\" ignored by ConfigReader Simpleton\n" if ($5 =~ /\S/);
#print "1=$1 2=$2 3=$3 4=$4 5=$5\n";
   # test the input value for an array description (test for parentheses)
      if ($value =~ s/^\s*\((.*)\)\s*$/$1/  or $type == 2) { 
          $value =~ s/["']//g; # cleanup: remove quotation marks
          $type = 2; # just in case
      }
   }  else {
      $type = 0; # signal error status
      undef $key; 
      undef $value;
   }
#print "key: $key  $value    $type\n";
  return ($key, $value, $type);
}


sub replace {
# replace or append a key's value or add a new one
    my $self   = shift;
    my $key    = shift;
    my $value  = shift;
    my $append = shift;

    my $in = $self->{config_data};

    $append = 0 if (!$append || !defined($in->{$key}));

    $in->{$key} = $value if (!$append);
    $in->{$key} .= $value if ($append);
}

=pod

=head1 LIMITATIONS/BUGS

Directives are case-sensitive.

If a directive is repeated, the first instance will silently be
ignored.

Always die()s on errors instead of reporting them.

C<get()> doesn't warn if used before C<parse()>.

C<get()> doesn't warn if you try to acces the value of an
unknown directive not know (ie: one that wasn't passed via C<new()>).

All these will be addressed in future releases.

=head1 AUTHOR

Bek Oberin <gossamer@tertius.net.au>

=head1 COPYRIGHT

Copyright (c) 1998 Bek Oberin.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#
# End code.
#
1;




