package CanonicalMapping;

# Copyright (c) 2001-2014 Genome Research Ltd.
#
# Authors: David Harper
#          Ed Zuiderwijk
#          Kate Taylor
#
# This file is part of Arcturus.
#
# Arcturus is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.


use strict;

use CanonicalSegment;

use Digest::MD5 qw(md5 md5_hex md5_base64);

#-------------------------------------------------------------------
# Constructor new 
#-------------------------------------------------------------------

sub new {
# if a parameter is passed, use the cache
    my $class = shift;

    my $this = {};

    bless $this, $class;

    return $this;
}

#-----------------------------------------------------------------------------
# cache look up
#-----------------------------------------------------------------------------

my $CANONICALMAPPING_HASHREF = {}; # cache

my $BUILDCACHE = 1; # default enable usage

sub lookup { 
# class method: retrieve a cached mapping keyed on the checksum
    my $class = shift;
    my $checksum = shift || 0;
    return $CANONICALMAPPING_HASHREF->{$checksum};
}

sub cache { 
# class method: returns the size of the cache
    my $class = shift;
    my %options = @_; # disable=>, reset=>
# optionally disables/resets cache; default enables cache
    $BUILDCACHE = $options{disable} ? 0 : 1;
    $CANONICALMAPPING_HASHREF = {} if $options{reset};
    return scalar(keys %$CANONICALMAPPING_HASHREF);
}

#-----------------------------------------------------------------------------
# parameters of the canonical mapping
#-----------------------------------------------------------------------------

sub setSpanX { # e.g. contig
    my $this = shift;
    $this->{xrange} = shift;
}

sub getSpanX {
    my $this = shift;
    $this->verify() unless $this->{xrange};
    return $this->{xrange};
}

sub setSpanY { # e.g. read
    my $this = shift;
    $this->{yrange} = shift;
}

sub getSpanY {
    my $this = shift;
    $this->verify() unless $this->{yrange};
    return $this->{yrange};
}

sub setCheckSum {
# set the checksum and add to the cache; test return value
    my $this = shift;
    my $checksum = shift || return undef;
    $this->{segmentchecksum} = $checksum;
# check if a cached version of the mapping already exists
    return 0 unless $BUILDCACHE;
    return 0 if $this->lookup($checksum); # already cached
# add instance to cache 
    $CANONICALMAPPING_HASHREF->{$checksum} = $this;
    return 1;
}


sub getCheckSum {
    my $this = shift;
    unless ($this->{segmentchecksum}) {
        $this->setCheckSum( &buildCheckSum($this->verify()) );
    }
    return $this->{segmentchecksum};
}

sub buildCheckSum {
# private: construct a hash of string formatted from segment parameters
    my $segments = shift || [];
    my $signature = '';
    foreach my $segment (@$segments) {
        $signature .= ':' if $signature;
        $signature .= join ',',@$segment[0 .. 2];
    }
    return md5($signature);
}

#-------------------------------------------------------------------
# canonical mapping ID
#-------------------------------------------------------------------

sub getMappingID {
    my $this = shift;
    return $this->{mapping_id};
}

sub setMappingID {
    my $this = shift;
    $this->{mapping_id} = shift;
}
 
#-------------------------------------------------------------------
# importing alignment segments
#-------------------------------------------------------------------

sub addCanonicalSegment {
    my $this = shift;
    my ($xs, $ys, $length, @dummy) = @_;

    my $segments = $this->getSegments();

    my $segment = new CanonicalSegment($xs, $ys, $length);

    return 0 unless $segment; # failed to create; process outside 

    push @$segments, $segment;

    return scalar(@$segments);
}

#-------------------------------------------------------------------
# export of alignment segments
#-------------------------------------------------------------------

sub hasSegments {
# returns true if at least one canonical segment is defined
    my $this = shift;

    return scalar(@{$this->getSegments()}); # else regular
}

sub getSegments {
# export the array of alignment segments
    my $this = shift;

    $this->{Segments} = [] if !$this->{Segments}; # ensure an array ref
    my $segments = $this->{Segments};
    return $segments;
}

sub verify {
# order and test the canonical segments; return undef if none or invalid
    my $this = shift;

    my $segments = $this->getSegments();
    return undef unless ($segments && @$segments);

    @$segments = sort {$a->getXstart() <=> $b->getXstart()} @$segments;

# verify the first segment; should start at position 1 on both domains

    my @first = $segments->[0]->getSegment();
    return undef unless ($first[0] == 1 && $first[2] == 1);

# define the span

    my @last = $segments->[$#$segments]->getSegment();
    $this->setSpanX($last[1]);  
    $this->setSpanY($last[3]);  

    return $segments;
}

#-------------------------------------------------------------------

1;
