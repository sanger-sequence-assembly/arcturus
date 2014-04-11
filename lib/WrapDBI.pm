#######################################################################

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

# This software has been created by Genome Research Limited (GRL).    # 
# GRL hereby grants permission to use, copy, modify and distribute    # 
# this software and its documentation for non-commercial purposes     # 
# without fee at the user's own risk on the basis set out below.      #
# GRL neither undertakes nor accepts any duty whether contractual or  # 
# otherwise in connection with the software, its use or the use of    # 
# any derivative, and makes no representations or warranties, express #
# or implied, concerning the software, its suitability, fitness for   #
# a particular purpose or non-infringement.                           #
# In no event shall the authors of the software or GRL be responsible # 
# or liable for any loss or damage whatsoever arising in any way      # 
# directly or indirectly out of the use of this software or its       # 
# derivatives, even if advised of the possibility of such damage.     #
# Our software can be freely distributed under the conditions set out # 
# above, and must contain this copyright notice.                      #
#######################################################################
#
# WrapDBI
#
# Author: (or at least maintainer) Jennifer Liddle (js10)
#
# $Id: WrapDBI.pm 26998 2008-09-17 11:46:35Z mca $
#
#
package WrapDBI;

use strict;
use DBI;
use Carp;

my $debug;

BEGIN {
	# setenv DEBUG_WRAPDBI to turn on connect debugging!
	$debug = exists($ENV{DEBUG_WRAPDBI});

	# setenv BENCHMARK_DBI to enable query timing
	if (defined $ENV{WRAPDBI_BENCHMARK} ) { 
		require newDBI;
		@WrapDBI::ISA = qw(newDBI); 
	} else { 
		@WrapDBI::ISA = qw(DBI); 
	}
}

###########################################################
# This part required by Makefile.PL - don't fiddle with it
#
my $VERSION;
( $VERSION ) = '$Revision: 26998 $ ' =~ /\$Revision:\s+([^\s]+)/;
#
###########################################################

my %db_login;
my $loginFile;
# Find the logins file (need to think of a better way to do this some time...)
if (exists($ENV{WRAPDBI_TEST_CONFIG})
    && $ENV{WRAPDBI_TEST_CONFIG}) {

    $loginFile = $ENV{WRAPDBI_TEST_CONFIG};

} else {

    foreach (@INC) {
	if (-e "$_/DBlogs") {
	    $loginFile = "$_/DBlogs";
	    last;
	}
    }

}
unless (defined($loginFile)) {
    die "Couldn't find database login file\n";
}
# Read in the login file...
open(WrapDBI::LOGIN, "< $loginFile")
    || die "Can't open login file for reading\n";
while (<WrapDBI::LOGIN>) {

    chomp;
    s/\#.*$//;   # Get rid of comments
    my ($entry, $user, $pass, @connections) = split;

    if (defined($entry)) {
	unless (@connections) { @connections = ($ENV{TWO_TASK}); }
	# print STDERR "$entry $user $pass @connections\n";
	$db_login{$entry} = [$user, $pass, \@connections];
    }

}
close(WrapDBI::LOGIN);

# Subroutine to log into the database.
# Pass in one of the login names in %db_login
# Returns a database handle that can be used in the normal way

sub connect {
    my ($type, $login_name, $attr) = @_;

    # Get the information needed for this connection.
    
    unless (exists($db_login{$login_name})) {
	croak "Unknown database login: $login_name\n";
    }

    my ($user, $pass, $connections) = @{$db_login{$login_name}};
    unless (@$connections) {
	croak "Can't connect to database: No database name found!";
    }

    # Backwards compatibility - we used to use the old-style connection
    # which left AutoCommit undefined (effectively 0) if you didn't set it.
    # The new style sets it to 1 in this case, which causes strange behaviour
    # in programs that assumed AutoCommit was off when not set explicitly.
    # To cover this, we set AutoCommit off by default unlike DBI->connect

    unless (defined($attr)) { $attr = {}; }
    unless (exists($attr->{AutoCommit})) {
	$attr->{AutoCommit} = 0;
    }
    unless (exists($attr->{PrintError})) {
	$attr->{PrintError} = 0;
    }

    my $dbh;
    my $msg;
    
    # Go through the list of connections to try.  If we manage to get
    # a connection break out and return it.  If there wasn't and RaiseError
    # was 1, we should have an error message that we can die with.  Otherwise,
    # assume RasieError was 0 in which case we just return undef - which is
    # what DBI->connect() does.

    my $real_user = $user;
    foreach my $c (@$connections) {

	my $connection = $c; # as we fiddle with $connection below

	if ($connection eq 'local') {
	    $connection = '';
	} elsif ($connection && $connection !~ /\@|\:/) {

	    # This is a work-around for a problem with DBI.pm when
	    # used on a cluster that is also running an Oracle instance.
	    # DBI.pm finds the database in /etc/oratab and thinks it can
	    # connect locally when it can't.  The result is a hanging
	    # application.  Putting an @ in the connection string forces
	    # the use of SQL*NET which solves the problem.

	    # $connection = "\@$connection";

	    # And now the work-around for the work-around....
	    # The above was fine for DBI version 1.02, but had broken by
	    # DBI version 1.20_1 when DBD::Oracle::ORA_OCI() >= 8.
	    # Fortunately, putting @$connection on
	    # the end of the user name works in both, so do that.

	    $user = "$real_user\@$connection";
	    $connection = "";

	}
	   
	my $data_source;
	if ($login_name =~ /:/i) {
	    $data_source = $connection;
	} else {
	    $data_source = "dbi:Oracle:$connection";
	}
	$pass='' if $pass eq 'none';
	if ($debug) { print STDERR "Trying $data_source $user\n"; }
	eval {
	    $dbh = $WrapDBI::ISA[0]->connect($data_source, $user, $pass, $attr);
	};
	if ($@) {
	    $msg = $@;
	    if ($debug) {
		print STDERR "Connection failed: $msg\n";
	    }
	}

	# Turn on serverside Oracle logging
	# NB this is highly unlikely to work for mySQL or any non-Oracle database
	if (defined $ENV{WRAPDBI_LOGGING}) {
		my $useful = $0 . " " . $ENV{USER};
		my $sth1 = $dbh->prepare('BEGIN dbms_application_info.set_client_info(:1); END;');
		$sth1->execute($useful);
		my $sth3 = $dbh->prepare('alter session set sql_trace=true');
		$sth3->execute();
		print STDERR "Oracle server side logging enabled\n" if $debug;
	}

	if ($dbh) {
	    if ($debug) { print STDERR "Connected to $data_source $user\n"; }
	    last;
	}
    }

    unless (defined($dbh)) {
	if ($msg) {
	    # remove username and password from error message!
	    $msg =~ s/connect\(.*?\)/connect\(\.\.\.\)/g;
	    die $msg;
	}
    }

    return $dbh;  # $dbh is blessed as type DBI::db
}

package DBI::db;

####### Utility functions - now installed in DBI::db namespace
                                                                                                       
# NB These are now obsolete - DBI.pm contains routines that provide
# exactly the same functionality.  These should be used in preference
# as they allow bind variables to be passed in.
                                                                                                       
# Fetch a single scalar value - use when only one value is expected
                                                                                                       
sub fetch_scalar {
    my ($dbh, $statement, $attr, $trace_level, $trace_file) = @_;
                                                                                                       
    my $sth = $dbh->prepare($statement, $attr) || return undef;
    if ($trace_level) { $sth->trace($trace_level, $trace_file); }
    $sth->execute() || return undef;
    my ($scalar) = $sth->fetchrow();
    $sth->finish();
    return $scalar;
}
                                                                                                       
# Fetch a single row - use when only one row is expected
                                                                                                       
sub fetch_row {
    my ($dbh, $statement, $attr, $trace_level, $trace_file) = @_;
                                                                                                       
    my $sth =  $dbh->prepare($statement, $attr) || return undef;
    if ($trace_level) { $sth->trace($trace_level, $trace_file); }
    $sth->execute() || return undef;
    my @result = $sth->fetchrow();
    $sth->finish();
    return @result;
}
                                                                                                       
# Fetch an array of arrays
                                                                                                       
sub fetch_all {
    my ($dbh, $statement, $attr, $trace_level, $trace_file) = @_;
                                                                                                       
    my $sth = $dbh->prepare($statement, $attr) || return undef;
    if ($trace_level) { $sth->trace($trace_level, $trace_file); }
    $sth->execute() || return undef;
    my $ref = $sth->fetchall_arrayref();
    $sth->finish();
    return $ref;
}
                                                                                                       
# Verify that a statement will compile
                                                                                                       
sub verify {
    my ($dbh, $statement, $attr) = @_;
                                                                                                       
    print STDERR "***$statement\n";
    my $sth = $dbh->prepare($statement, $attr) || return undef;
    $sth->finish;
    return 1;
}

1;


__END__

=head1 NAME

WrapDBI.pm - Wrapper for the perl DBI module

=head1 SYNOPSIS

# Note: you should use WrapDBI where you would normally use DBI.

use WrapDBI;

eval {

    # Set RaiseError = 1 so an exception is raised if anything bad happens.

    my $dbh = WrapDBI->connect('tele_edit', {RaiseError => 1});
    my $worked = $dbh->verify('some_sql_statement');

    ...

    $dbh->disconnect();
};
if ($@) {
    # Handle error
}

=head1 PARAMETERS

=head2 WrapDBI->connect($login, \%attr)

=over 4

=item $login

Name of database login to use.  Is converted to a database name
and password and passed to DBI::connect

=item \%attr

Reference to a hash of attributes.  Passed directly to DBI::connect.

=back

=head2 $dbh->verify($sql, \%attr);

=over 4

=item $dbh

database handle returned by connect.

=item $sql

sql statement to be executed

=item \%attr

Reference to a hash of attributes.  Passed directly to DBI::db::prepare

=back

=head1 DESCRIPTION

WrapDBI is a wrapper around the DBI.pm module.  It replaces the standard DBI
connect function with one that takes a login name for the program being run.
This login is converted to a username and password and passed to DBI::connect
which returns a database handle in the normal way.  If the database being
connected to is a parallel server, WrapDBI can also handle fail-over between
the nodes of the server.

There is a verify function to quickly check if an sql statement has the
correct syntax.

=head1 RETURN VALUES

=head2 my $dbh = WrapDBI->connect(...)

returns a database handle in the same way as DBI->connect.  This can be
used for calling both DBI and WrapDBI methods.

=head2 my $worked = $dbh->verify(...);

Returns 1 if DBI::prepare() worked, undef otherwise.

All of the functions return undef on failure.  If needed, they can be made
to die by setting the handle attribute RaiseError equal to 1.  This can then
be caught using eval, thus:

eval {

    # RaiseError => 1 makes DBI throw exceptions on bad things happening

    my $dbh = WrapDBI->connect('a_login', {RaiseError => 1});

    my $results = $dbh->selectall_arrayref('select all * from some_table');

    # Use results...

    my $dbh->disconnect();

};

if ($@) {

    # Eval caught an exception

    if ($DBI::err) {

        # This was an Oracle error
	print STDERR "Caught Oracle error number $DBI::err\n";
	print STDERR "$DBI::errstr\n";
    } else {
	# Whatever eval caught, it wasn't an Oracle error.
	print STDERR "Caught non-Oracle error:\n";
	print STDERR "$@\n";
    }

}

=head1 BUGS / CAVEATS

The following methods provided by WrapDBI are now deprecated.  The equivalent
methods from DBI.pm should be used instead:

=over 4

=item $var = $dbh->fetch_scalar($sql);

Use ($var) = $dbh->selectrow_arrayref($sql); instead

=item @array = $dbh->fetch_row($sql);

Use @array = $dbh->selectrow_arrayref($sql); instead

=item $array_ref = $dbh->fetch_all($sql);

Use $array_ref = $dbh->selectall_arrayref($sql); instead

=back

The advantage of this is that the DBI methods can take values to be inserted
into bind variables.  The DBI methods are also more portable.

=head1 SEE ALSO

The B<DBI> pod documentation.

=head1 AUTHOR

Rob Davies

=head1 HISTORY


 # $Log$
 # Revision 1.11  2006/10/24 13:36:12  js10
 # Hacked to support really *really* old programs such as request_plate
 #
 # Revision 1.10  2006/10/24 09:13:29  js10
 # Added support for Oracle server-side logging, profiling, and mySQL
 # Moved from RCS to CVS
 #
 #
 # Revision 1.9  2006/03/14  15:08:27  jkb
 # Removed the windows hack with <DATA>. This only served to confound
 # perl and prevent warning-free programs when using perl -w. Eg:
 #
 # Name "WrapDBI::DATA" used only once: possible typo at <binary string> line 67.
 #
 # The apparent desire for this code is to obfuscate reading usernames
 # and passwords from after the __END__ block, but they do not exist
 # there and these days we have LDAP anyway.
 #
 # Revision 1.8  2002/02/04  11:09:18  rmd
 # Can now override the DBlogs file location using environment variable
 # WRAPDBI_TEST_CONFIG.
 #
 # Revision 1.7  2002/01/21  15:16:47  rmd
 # Oops!  $user was getting more connection strings appended to it.
 # Entries in @connection array were being removed slowly.
 # Added connection debugging - turned on by setenv DEBUG_WRAPDBI
 #
 # Revision 1.6  2002/01/21  12:12:09  rmd
 # Moved @connection to user name so connections work with DBI 1.20.
 #
 # Revision 1.5  2001/12/10  14:58:15  rmd
 # Added an @ to the connection string to force the use of SQL*NET.
 #
 # Revision 1.4  2001/12/04  10:10:23  ja1
 # Added WinNT stuff, keeping Unix code unchanged
 # Added support for 'local' sid - WinNT will connect to onboard database when
 # this is specified (via a blank sid in the connection string)
 #
 # Revision 1.3  2001/06/06  13:41:14  rmd
 # Added support for OPS fail-over.  The database(s) to connect to are now
 # stored in the config file.  If there is more than one for a particular login,
 # WrapDBI will go through them in order until one connects.  This should
 # reduce problems seen when one of the listeners dies.
 #
 # Revision 1.2  1998/08/05  13:19:11  rmd
 # Stopped user name and password from being printed when an error occurs on
 # connect.
 #
 # Revision 1.1  1998/06/16  12:12:11  rmd
 # Initial revision
 # 
