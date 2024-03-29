package Logging;

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

use FileHandle;

use Linux::Monitor;

#-------------------------------------------------------
# Class variable
#-------------------------------------------------------

my $linebreak;

my $monitor;

#-------------------------------------------------------
# Constructor always sets to 'info' filter level
#-------------------------------------------------------

sub new {
# optional parameter interpreted as standard output device
    my $class  = shift;

    my $this = {};

    bless $this, $class;

# allocate a list of hashes for stream parameters (4 handles)

    my @streams;
    $this->{STREAMS} = \@streams;
    for my $i (0 .. 4) {
        my $stream = {};
        $stream->{handle} = 0;  # for the e.g. file handle
        $stream->{device} = 0;  # for the device name
        $stream->{blocked} = 0 if ($i <  2); # for the blocked status
        $stream->{blocked} = 1 if ($i >= 2); # default debug,special is blocked
        $stream->{method} = 0;
        $stream->{stamp} = 0;
        push @streams,$stream;       
    }

    $this->setStandardFilter('warning');

    $this->setStandardStream(@_) if @_;

    $linebreak = $ENV{REQUEST_METHOD} ? "<br>" : "\n"; # class variable

    return $this;
}

#---------------------------------------------------------
# methods that write to the various output devices
#---------------------------------------------------------

sub severe {
# write message to the standard log
    my $this = shift;
    my $text = shift;
    my %options = @_;

    $options{flush} = 1 unless defined $options{flush}; # default not buffered
 
    return unless $this->testStandardFilter(4);
    &write(&getOutputStream($this->{STREAMS},0),$text,%options);
}

sub warning {
# write message to the standard log
    my $this = shift;
    my $text = shift;
    my %options = @_;

    $options{flush} = 1 unless defined $options{flush}; # default not buffered

    return unless $this->testStandardFilter(3);
    &write(&getOutputStream($this->{STREAMS},0),$text,%options);
}

sub info {
# write message to the standard log
    my $this = shift;

    return unless $this->testStandardFilter(2);
    &write(&getOutputStream($this->{STREAMS},0),@_);
}

sub fine {
# write message to the standard log
    my $this = shift;

    return unless $this->testStandardFilter(1);
    &write(&getOutputStream($this->{STREAMS},0),@_);
}

sub finest {
# write message to the standard log
    my $this = shift;

    return unless $this->testStandardFilter(0);
    &write(&getOutputStream($this->{STREAMS},0),@_);
}

sub error {
# write message to the error log; default flush stream handle
    my $this = shift;
    my $text = shift;
    my %options = @_;

    $options{flush} = 1 unless defined $options{flush}; # default not buffered

    $options{prefix} = $this->getPrefix() unless defined($options{prefix});
 
    &write(&getOutputStream($this->{STREAMS},1),$text,%options);
}

sub special {
# write message to special log
    my $this = shift;
    my $text = shift;

    &write(&getOutputStream($this->{STREAMS},2),$text,@_);
}

sub debug {
# write message to the debug log
    my $this = shift;
    my $text = shift;
    my %options = @_;

    $options{flush} = 1 unless defined $options{flush}; # default not buffered

    $options{prefix} = $this->getPrefix() unless defined($options{prefix});

    &write(&getOutputStream($this->{STREAMS},3),$text,%options);
}

#--------------------------------------------------------------
# standard output stream filter setting blocks all levels below  
# e.g. level 'info' lets through: 'info','warning' and 'severe'
#                   but cuts out: 'fine' and 'finest'
# e.g. level 'severe' will only print that level
#--------------------------------------------------------------

sub setFilter { # to be deprecated
print STDERR "Logging->setFilter TO BE DEPRECATED\n"; 
&setStandardFilter(@_);
}

sub setStandardFilter {
# define filter level either by number (0 ... 5) or by name
    my $this = shift;
    my $clip = shift;

    if ($clip && $clip =~ /\D/) {
        my %level = ( finest => 0,   fine => 1,    info => 2, 
                     warning => 3, severe => 4, suspend => 5);
        $clip = $level{$clip};
    }

    $clip = 2 unless defined $clip; # default 'info' level

    $this->{filter} = $clip;
}

sub testStandardFilter {
    my $this = shift;
    my $test = shift;

   ($this->{filter} <= $test) ? return 1 : return 0;
}

#-----------------------------------------------------------------------
# Output Stream definitions
#-----------------------------------------------------------------------

sub setStandardStream {
# define explicitly the standard output stream
    my $this = shift;
    my $file = shift;
    my %options = @_;

    return &setStream($this->{STREAMS},0,$file,alias=>'standard',@_);
}

sub setErrorStream {
# define explicitly the error output stream
    my $this = shift;
    my $file = shift;
    my %options = @_;

    return &setStream($this->{STREAMS},1,$file,alias=>'error',@_);
}

sub setSpecialStream {
# define explicitly the special output stream
    my $this = shift;
    my $file = shift;
    my %options = @_; # append=>, list=>, [type=> and db specs]

    return &setStream($this->{STREAMS},2,$file,alias=>'special',@_);
}

sub setDebugStream {
# define explicitly the special output stream
    my $this = shift;
    my $file = shift;
    my %options = @_;

    return &setStream($this->{STREAMS},3,$file,alias=>'debug',@_);
}

sub closeStreams {
# close the file handles
    my $this = shift;

    my $streams = $this->{STREAMS};

    my %closed;
    foreach my $stream (@$streams) {
        my $handle = $stream->{handle};
        next unless $handle;
        &timestamp($stream,'close') if $stream->{stamp};
# redirected streams need to be closed only once
        &closeDevice($handle) unless($closed{$handle}++); 
        $stream = {};
    }
}

sub close {
# alias for closeStreams
    &closeStreams(@_);
}

sub flush {
# close the file handles
    my $this = shift;

    my $streams = $this->{STREAMS};

    foreach my $stream (@$streams) {
        my $handle = $stream->{handle};
        next unless $handle;
        &timestamp($stream,'flush') if $stream->{stamp};
        $handle->flush();
    }
}

sub stderr2stdout {
# redirect STDERR to STDOUT

    open(STDERR,">&STDOUT") || return 0; # exit 0 for failure

    return 1; # success
}

#-----------------------------------------------------------------------

sub setPrefix {
    my $this = shift;

    $this->{prefix} = shift;
}

sub getPrefix {
    my $this = shift;

    return $this->{prefix};
}

#-----------------------------------------------------------------------

my %streams = (standard => 0, error => 1, special => 2, debug => 3);

sub setBlock {
# block or unblock an output stream; block EXCEPT when 'unblock' option is given 
    my $this = shift;
    my $stream = shift;
    my %options = @_;

    my $number = $streams{$stream};

    unless ($number) {
        $this->error("Invalid stream specification $stream in setBlock");
        return;
    }

#    $stream = &getOutputStream($this->{STREAMS},$number); # ?

    $stream = $this->{STREAMS}->[$number]; 

    $stream->{blocked} = ($options{unblock} ? 0 : 1);
}

#-----------------------------------------------------------------------
#  private methods and helper methods 
#-----------------------------------------------------------------------

sub openDevice {
    my $device = shift || return undef;
    my $append = shift;

    &verifyPrivate($device,'openDevice');

    my $handle = new FileHandle();

    if ($device =~ /^STDOUT|STDERR$/) {
        $handle = new FileHandle(">&${device}");
    }
    elsif ($append) {
        $handle = new FileHandle($device,"a");
    }
    else {
        $handle = new FileHandle($device,"w");
    }

    return $handle;
}

sub closeDevice {
# close the deviice, if it exists
    my $device = shift || return;

    &verifyPrivate($device,'closeDevice');

    return unless (ref($device) eq 'FileHandle');

    $device->flush();
    $device->close();
}

#-----------------------------------------------------------------

sub setStream {
    my $streams = shift; # array of stream hashes
    my $number = shift;
    my $device = shift; # device name (e.g. filename)
    my %options = @_; # type=>, append=>, alias=>, list =>

# verify input parameters

    &verifyPrivate($streams,'setStream');

    return 0 unless defined ($streams->[$number]); # invalid stream number

    return 0 unless $device; # missing device

# check if the device already exists, if so copy the handle

    for (my $i = 0 ; $i < scalar(@$streams) ; $i++) {
        my $stream = $streams->[$i];
        next unless ($stream->{device} && $device eq $stream->{device});
# the named device is already open for writing; if so redirect and unblock
        return 1 if ($i == $number); # same device and stream
        print STDOUT "Re-directing stream '$options{alias}' to existing "
                   . "stream on $device\n" if $options{list};
        foreach my $key ('handle','device','method') {
            $streams->[$number]->{$key} = $stream->{$key};
        }
        $streams->[$number]->{blocked} = 0;
        return 1;
    }

# the device is new

    my $stream = $streams->[$number];
    if (ref($device) eq 'FileHandle') {
# the device is an externally defined file handle
        $stream->{handle} = $device; # the FileHandle
        $stream->{device} = $device; # the FileHandle
        $stream->{blocked} = 0;
        $stream->{method} = 'print';
    }
    elsif (ref($device)) {
# it's e.g. a database handle
        $stream->{handle} = $device;
        $stream->{device} = $device->getURL() if $options{url};
        $stream->{device} = $device       unless $options{url};
        $stream->{blocked} = 0;
        $stream->{method} = $options{method} || 'write';
    }
    else {
# it's a string, to be taken as filename
        return &setOutputStream($streams->[$number],$device,@_);
    }
}

sub setOutputStream {
# open an output stream to a FileHandle
    my $stream = shift; # a hash
    my $device = shift || 0; # a name
    my %options = @_; # alias=> , list=> , append=>

    &verifyPrivate($stream,'setOutputStream');

    my $handle = $stream->{handle};
    &closeDevice($handle) if $handle;
    $stream->{handle} = &openDevice($device,$options{append});
    $stream->{device} = $device;
    $stream->{blocked} = 0;
    $stream->{method} = 'print';

    my $alias = $options{alias};
    unless ($stream->{handle}) {
        print STDERR "Failed to open $device for $alias output ($!)\n";
        return 0;
    } 

    if ($options{list}) {
        my $pwd = `pwd`; chomp $pwd; # include the current directory
        print STDOUT "$device opened for $alias output stream\n";
        print STDOUT "(current directory $pwd)\n" unless ($device =~ /STD/);
    }

    if (my $label = $options{timestamplabel}) {
        &timestamp($stream,"open on $label");
    }
    elsif ($options{timestamp}) {
        &timestamp($stream,'open');
    }

    return 1;
}

sub getOutputStream {
# return the numbered output stream with default provision
    my $streams = shift; # array of stream hashes
    my $number = shift; # stream number

    &verifyPrivate($streams,'getOutputStream');

    my $stream = $streams->[$number];

    unless ($stream->{handle}) {
# redirect and/or auto install 
        if ($number == 0) { 
# auto install STDOUT
            &setOutputStream($streams->[0],"STDOUT",alias=>"standard");
        }
        elsif ($number == 1) { 
# auto install STDERR
            &setOutputStream($streams->[1],"STDERR",alias=>"error");
        }
        elsif ($number < 4) { # default to STDOUT or STDERR
# redirect and copy the stream settings from the parent stream
            my $stdstream = &getOutputStream($streams,$number-2);
            foreach my $key ('handle','device','method') {
                $stream->{$key} = $stdstream->{$key};
            }
#            $stream->{blocked} = 0;
        }
        else {
            print STDERR "Invalid stream number $number\n";
	}
        
    }

    return $stream;
}

sub write {
# private, write text to the handle (file or otherwise) of the given stream
    my $stream = shift; # stream hash
    my $text = shift;
    my %options = @_; 

# formatting options: preskip,ps,ss,skip,prespace,space,postspace,emphasis,
#                     space,prefix,nobreak,nb,bs
# other options     : flush,   (xml)

    return unless $stream;

    &verifyPrivate($stream,'write');

    return if $stream->{blocked};

    my $message = '';

    if ($options{xml}) {
# to be added: XML formatting
    }
    else {
# formatting before: skip (preskip/ps/ss), skip after (skip/ss), pre/space
        if ($options{preskip} || $options{ps} || $options{ss}) {
            $message .= $linebreak;
        }
        if (my $space = $options{prespace} || $options{space}) {
            while ($space-- > 0) {
                $message .= " ";
	    }
        }
        $message .= "!! " if $options{emphasis};
        $message .= "$options{prefix} " if $options{prefix};
# the text, if any
        $message .= $text if ($text && length($text) > 0);
# formatting after
        if (my $space = $options{postspace}) {
            while ($space-- > 0) {
                $message .= " ";
	    }
        }
        unless ($options{nobreak} || $options{nb} || $options{bs}) {
	    $message .= $linebreak;
	}
        $message .= "\r" if $options{bs};
        my $skip = $options{skip} || $options{ss} || 0;
        while ($skip-- > 0) {
            $message .= $linebreak;
        }
    }

# ok, write the message to the output stream

    my $handle = $stream->{handle};
    my $method = $stream->{method};

    unless ($handle) {
        print STDERR "missing handle for $stream->{device} : $message\n";
	return;
    }    

    if ($method eq 'print') {
# to a file handle
        $handle->print($message);
        $handle->flush() if $options{flush};
    }
#    elsif ($method) {
#        eval("\$handle->$method(\$message)"); # will do nicely
#    }
    elsif ($method eq 'write') {
# to a default write method of e.g. a database handle
print STDERR "handle: $handle  method: $method  msg:'$text'\n";
        $handle->write($message);
    }
    elsif ($method) {
# use the specified method on the stream handle
print STDERR "handle: $handle  method: $method  msg:'$text'\n";
        eval("\$handle->$method(\$message)");
    }
    else {
        print STDERR "missing writing method on output stream $handle\n";
    }
    return 1;
}

sub timestamp {
    my $stream = shift;
    my $marker = shift || 'open';

    &verifyPrivate($stream,'timestamp');

    my $timestamp = scalar(localtime);

    &write($stream,"$marker : $timestamp",skip=>1,preskip=>1);

    $stream->{stamp} = 1;
}

#---------------------------------------------------------------------------
# special
#---------------------------------------------------------------------------

sub listStreams {
    my $this = shift;

    my @devices;
    foreach my $stream (0,1,2,3) {
        my $device = $this->{STREAMS}->[$stream]->{device};
        $device = '' unless defined($device);
        push @devices, $device;
    }

    $this->warning("Standard Stream active on device $devices[0]");
    $this->info("Standard Stream active (level: info)");
    $this->fine("Standard Stream active (level: fine)");
    $this->finest("Standard Stream active (level: finest)");
    $this->error("Error Stream active on device $devices[1]");
    $this->debug("Debug Stream active on device $devices[3]");
    $this->special("Special Stream active on device $devices[2]");
}

sub monitor {
# report current memory usage on standard stream
    my $this = shift;
    my $text = shift;
    my %options = @_; # memory, timing

    $monitor = new Linux::Monitor() unless $monitor;

    my $list;
    $list = $this->warning($text." ".$monitor->usage()) if $options{memory};
    $list = $this->warning($text." ".$monitor->timer()) if $options{timing};

    return if $list;

    $this->warning($text." ".$monitor->usage()." ".$monitor->timer());
}

#---------------------------------------------------------------------------

sub verifyPrivate {
    my $caller = shift;
    my $method = shift;

    if (ref($caller) eq 'Logging') {
        die "Invalid use of private Logging->$method";
    }
}

#-----------------------------------------------------------------------
# close streams on destruction  
#-----------------------------------------------------------------------
 
sub DESTROY {
    my $this = shift;
    $this->closeStreams();
}

#-----------------------------------------------------------------------

sub skip { # DEPRECATED
my $this = shift;
$this->warning("  skip to be deprecated ");
}

1;
