package GateKeeper;

use strict;

use DBI;
use CGI qw(:standard);
use MyHTML;
use ArcturusTable;
use ConfigReader;

my $debug = 0;

#############################################################################
#
# GateKeeper module for the ARCTURUS assembly tracking database system
#
# The module sets up access to: the configuration file data 
#                               the CGI input parameters, if in CGI mode
#                               the database handle on the current server
#
# Retrieve the database table handle and configuration & cgi references by
# using methods dbHandle, configHandle and cgiHandle
#
# Method dbHandle requires an arcturus organism database as parameter. This 
# module bounces the query to another server if it is not found at the current
# server & port 
#
# method isAvailable tests the 'available' status of the requested database
#
#############################################################################

sub new {
# open database handle for database $database in arcturus
    my $caller = shift;
    my $engine = shift; # MySQL or Oracle 
    my $eraise = shift; # raise error setting (optional, default 1)
    my $usecgi = shift; # set to true if must be run under CGI

# determine the class and invoke the class variable

    my $class  = ref($caller) || $caller;
    my $self   = {};

    undef $self->{server};
    undef $self->{Script};
    undef $self->{TCPort};
    undef $self->{handle};
    undef $self->{database};
    undef $self->{config};
    undef $self->{cgi};
    $self->{ARGV} = [];
    undef $self->{USER};

    bless ($self, $class);

# get options

    my %options = (eraiseMySQL   => 0,  # open (MySQL) with RaiseError =0 
                   dieOnNoTable  => 1,  # die if ORGANISMS table not found/ opened
                   insistOnCgi   => 0,  # default alow command-line access
                   diagnosticsOn => 0); # set to 1 for some progress information

    if ($eraise && ref($eraise) eq 'HASH') {
        &importOptions(\%options,$eraise);
        $debug =  "\n"  if ($options{diagnosticsOn} == 1);
        $debug = "<br>" if ($options{diagnosticsOn} == 2);
    }
    else {
        $options{eraiseMySQL} = $eraise if $eraise;
        $options{insistOnCGI} = $usecgi if $usecgi;
    }

# check on command-line input

    &clinput(0,$self);

# open the CGI input handler if in CGI mode

    &cginput(0,$self,$options{insistOnCGI});

# produce return string for diagnostic purposes, if specified

    &cgiHeader($self,$options{diagnosticsOn}) if $options{diagnosticsOn};

# open and parse the configuration file

    &configure(0,$self);

# open the database

    &opendb_MySQL(0,$self,\%options) if ($engine && $engine =~ /^mysql$/i);

# &opendb_Oracle(0,$self,$eraise) if ($engine && $engine =~ /^oracle$/i); # or similar later

    &dropDead($self,"Invalid database engine $engine") if ($engine && !$self->{handle});

    return $self;
}

#*******************************************************************************
# parse the configuration file
#*******************************************************************************

sub configure {
# create a handle to the configuration data
    my $lock  = shift;
    my $self  = shift;

    &dropDead($self,"You're not supposed to access this method") if $lock;

# Get configuration parameters using Configuration File ".arc_common.cnf"

    my $CONFIG = '/nfs/pathsoft/arcturus/conf/.arc_config.cnf';
    my $config = ConfigReader->new($CONFIG);

    $config->parse() || &dropDead($self,"No such file or directory: $CONFIG");

# data are in $self->{config}->{config_data}->{<name>}

    $self->{config} = $config;
}

#*******************************************************************************

sub configHandle {
    my $self = shift;

    return $self->{config};
}

#*******************************************************************************
# set up cgi input stream
#*******************************************************************************

sub cginput {
# create a handle to the cgi input hash, if any
    my $lock = shift;
    my $self = shift;
    my $fail = shift; # die if no CGI mode and fail is set

    &dropDead($self,"You're not supposed to access this method") if $lock;

    $self->{cgi} = MyHTML->new(0);

    if (!$self->{cgi}) {
        &dropDead($self,"Cannot open the MyCGI module");
    }
    elsif (!$self->{cgi}->{status} && $fail) {
        &dropDead($self,"This script cannot be run from the command line");
    }
}

#*******************************************************************************

sub cgiHandle {
    my $self = shift;
    my $test = shift; # id true: test and return 0 if not in CGI mode

    my $cgi = $self->{cgi};
    $cgi = 0 if ($test && (!$cgi || !$cgi->{status}));

    return $cgi;
}

#*******************************************************************************

sub cgiHeader {
    my $self = shift;
    my $type = shift; # 1 for plain, 2 for html, else nothing

    if ($self->{cgi} && $self->cgiHandle(1)) {
        $self->{cgi}->PrintHeader(1) if ($type == 1);
        $self->{cgi}->PrintHeader(0) if ($type == 2);
    }
}

#*******************************************************************************

sub clinput {
# process command-line input
    my $lock = shift;
    my $self = shift;

    &dropDead($self,"You're not supposed to access this method") if $lock;

    @{$self->{ARGV}} = @ARGV  if @ARGV;    
}

#*******************************************************************************

sub origin {
# return PATH information
    my $self = shift;
    my $path = shift; # (max) number of path elements (ARGV input)
#    my $skip = shift; # true for skipping PATH_INFO

    undef my $origin;
    if ($ENV{'GATEWAY_INTERFACE'}) {
        $origin = $ENV{'PATH_INFO'} || '';
    }

# either path_info or blank (under CGI, both 'true') OR undef (not CGI, 'false')

# the next part builds $origin from ARGV (first $path elements) as quasi 'path info'
# (this allows command line access and PERL system(..) or back-tick execution to be
#  interpreted in identical manner)

    if ((!$origin || $origin !~ /\S/) && @{$self->{ARGV}}) {
        $origin = '';
        while (@{$self->{ARGV}} && $path--) {
            $origin .= '/'.(shift @{$self->{ARGV}});
        }
    }

    return $origin;
}

#*******************************************************************************
# open the MySQL database on the current host
#*******************************************************************************

sub ping_MySQL {
# test if a specified database is alive
    my $self = shift;
    my $host = shift;
    my $port = shift;
    my $kill = shift;

    my $mysqladmin = $self->{config}->get('mysql_admin')   or
       &dropDead($self,"Missing configuration parameter 'mysql_admin'");

    `$mysqladmin -h $host -P $port -u ping ping >/dev/null 2>&1`;

    my $alive = ($? == 0);

    $self->report("The MySQL instance $host:$port is not available") if !$alive;

    $self->dropDead() if ($kill && !$alive);

    return $alive;
}

#*******************************************************************************

sub opendb_MySQL_unchecked {
# open mysql directly with only basic checks
    my $self = shift;
    my $host = shift; # hostname:TCPport
    my $hash = shift;

    my %options = (defaultOpenNew => 0, dieOnError => 1, RaiseError => 0);
    &importOptions(\%options,$hash);

# test against default server, else open a new connection

    my ($name,$port) = split ':',$host;
    if (!$options{defaultOpenNew} && $self->{handle}) {
        &dropDead($self,"Invalid host:TCP port specification in host $host") if ($host !~ /\:/);
        return $self->{handle} if ($self->{server} =~ /$name/ && $self->{TCPort} == $port);
    }

# register server and TCP port

    $self->{server} = $name;
    $self->{TCPort} = $port;

# build the data source name

    my $dsn = "DBI:mysql:arcturus:host=$host";

# get database authorization

    my $config = $self->{config};

    my $username = $config->get("mysql_username",'insist');
    my $password = $config->get("mysql_password",'insist');
# test configuration data input status
    if (my $status = $config->probe(1)) {
        &dropDead($self,"Missing or Invalid information on configuration file:\n$status") if $options{dieOnError};
        return 0;
    }

# and open up the connection

    $self->{handle} = DBI->connect($dsn, $username, $password, $options{RaiseError});
    if (!$self->{handle}) {          
        &dropDead($self,"Failed to access arcturus on host $host",1) if $options{dieOnError};
        return 0;
    }

# okay, here the database has been properly opened on host/port $self->{server};

    $self->{mother} = new ArcturusTable($self->{handle},'ORGANISMS','arcturus',1,'dbasename');
    if ($self->{mother}->{errors} && $options{dieOnNoTable}) {
        &dropDead($self,"Failed to access table ORGANISMS on $self->{server}");
    }

    return $self->{handle};
}

#*******************************************************************************

sub opendb_MySQL {
# create database handle on the current server and port
    my $lock = shift;
    my $self = shift;
    my $hash = shift;

    my %options = (RaiseError   => 0,  # default do NOT die on error
                   dieOnNoTable => 1); # default die on ORGANISMS table error

    &importOptions(\%options,$hash);
    my $eraise = $options{RaiseError} || 0;

    print "GateKeeper enter opendb_MySQL $debug" if $debug;

    &dropDead($self,"You're not supposed to access this method") if $lock;

    undef $self->{server};
    undef $self->{handle};

# we now test if the specified database is installed on the current CGI server

print "config $self->{config}\n" if $debug;

    if (my $config = $self->{config}) {
# get database parameters
        my $driver    = $config->get("db_driver",'insist');
        my $username  = $config->get("mysql_username",'insist');
        my $password  = $config->get("mysql_password",'insist');
        my $db_name   = $config->get("mysql_database");
        $db_name = 'arcturus' if !$db_name; # default
        my $base_url  = $config->get("mysql_base_url");
        my $hosts     = $config->get("mysql_hosts",'insist unique array');
        my $port_maps = $config->get("port_maps"  ,'insist unique array');
# test configuration data input status
        my $status    = $config->probe(1);
        &dropDead($self,"Missing or Invalid information on configuration file:\n$status") if $status;
print "test combinations: @$port_maps\n" if $debug;

# The next section may be somewhat paranoid, but I want to be absolutely
# certain that the server port (if in CGI), the MySQL port and the script
# invoked (production against development) correspond. The allowed 
# combinations are read from the configuration file as @port_maps: each
# entry should consist of a string: <scriptdir>:<cgiport>:<mysqlport>.
# The scriptdir MUST be the name of the subdirectory in which the
# script resides, usually 'prod' for production and 'dev' for development;
# if not in CGI mode, the environment variable SCRIPT_FILENAME has to be
# defined by the invoking shell (use a wrapper shell)
# Note that if the CGI and MySQL servers are set up correctly, effectively
# only the directory is tested; however, this GateKeeper bums out if the
# servers do not correspond to the specification, and thus provides an extra
# test on the arcturus environment configuration. 

# check if the current server host is among the allowed hosts

        my @url; my $http_port = 0;
        if (defined($ENV{HTTP_HOST})) {
            my $HTTP_HOST = $ENV{HTTP_HOST};
            $HTTP_HOST =~ s/\:/.${base_url}:/ if ($base_url && $HTTP_HOST !~ /\.|$base_url/);
            foreach my $host (@$hosts) {
                $host =~ s/\:/.${base_url}:/ if ($base_url && $host !~ /\.|$base_url/);
                if ($host eq $HTTP_HOST) {
                    $self->{server} = $host;
                    @url = split /\.|\:/,$host;
                    $http_port = $url[$#url];
                }
            }
        }
# try local host or default if HTTP_POST not defined
        else {
            my $name = `echo \$HOST`;
            chomp $name; # print "host $name\n";
            foreach my $host (@$hosts) {
                @url = split /\.|\:/,$host;
                $self->{server} = $url[0] if ($name eq $url[0]);
            }
            $self->{server} = $config->get("default_host") if !$self->{server}; # default
        }

# TEMPORARY fix:this line is added because the pcs3 cluster is not visible as pcs3.sanger.ac.uk
        $self->{server} =~ s/pcs3\.sanger\.ac\.uk/pcs3/;

# check the MySQL port against the CGI port and/or the scriptname

        my $mysqlport;
        if (defined($ENV{MYSQL_TCP_PORT})) {
# get the port and script names
            $mysqlport = $ENV{MYSQL_TCP_PORT}; 
            if (my $scriptname = $ENV{SCRIPT_FILENAME}) {
# test the MySQL port and script name combination; get cgi port
                my $identify = 0;
print "test combinations: @$port_maps\n" if $debug;
                foreach my $combination (@$port_maps) {
                    my ($script, $tcp, $cgi) = split /\:/,$combination;
print "combination $combination MSQLPORT $ENV{MYSQL_TCP_PORT} $scriptname $script\n" if $debug;
	            if ($tcp eq $ENV{MYSQL_TCP_PORT} && $scriptname =~ /^.*\b($script)\b.*$/) {
# MySQL port and script directory verified; finally test the cgi port (if any)
print "http_port $http_port   cgi $cgi\n" if $debug;
                        if (!$http_port || $cgi == $http_port) {
                            $self->{TCPort} = $mysqlport;
                            $self->{Script} = $scriptname;
                            $identify++;
                            last;
                        }
                    }
                } 
                &dropDead($self,"Invalid port combination:\n$scriptname:$mysqlport:$http_port") if !$identify;
            }
            else {
# $self->environment;  possibly test PWD here   
                &dropDead($self,"Missing script identifier: can't verify production or development use");
            }
        }
	else {
            &dropDead($self,"Undefined MySQL port number");
	}

        if ($self->{server}) {
# check if the database is alive
            &ping_MySQL($self,$url[0],$mysqlport,1);       
# check whether the driver is available
            my @drivers = DBI->available_drivers;
# print "\nDrivers : @drivers\n\n";
            my $i = 0;
            while (($i < @drivers) && ($driver ne $drivers[$i])) {
               $i++;
            }
            &dropDead($self,"Driver syntax incorrect or Driver $driver is not installed") if ($i >= @drivers);
# build the data source name
            my $dsn = "DBI:".$driver.":".$db_name.":".$url[0];
# and open up the connection
            $eraise = 1 if !defined($eraise);
            $self->{handle} = DBI->connect($dsn, $username, $password, {RaiseError => $eraise}) 
                              or &dropDead($self,"Failed to access $db_name: (dsn: $dsn)",1); 
# okay, here the database has been properly opened on host/port $self->{server};
        }
        elsif ($ENV{HTTP_HOST}) {
            &dropDead($self,"Invalid database server specified: $ENV{HTTP_HOST}");
        }
        else {
            &dropDead($self,"Can't determine database server host name");
        }
    }
    else {
        &dropDead($self,"Can't open the database: missing or inaccessible configuration data");
    }

# open the ORGANISMS table in the arcturus database

    $self->{mother} = new ArcturusTable($self->{handle},'ORGANISMS','arcturus',1,'dbasename');
# if !dieOnNoTable : use self->instance afterwards to test existence of instance
print "options $options{dieOnNoTable} \n" if $debug;
    if ($self->{mother}->{errors} && $options{dieOnNoTable}) {
        &dropDead($self,"Failed to access table ORGANISMS on $self->{server}");
    }
}

#*******************************************************************************

sub importOptions {
# private function 
    my $options = shift;
    my $hash    = shift;

    my $status = 0;
    if (ref($options) eq 'HASH' && ref($hash) eq 'HASH') {
        foreach my $option (keys %$hash) {
            $options->{$option} = $hash->{$option};
        }
        $status = 1;
    }

    $status;
}

#*******************************************************************************

sub ping {
# test if the current database is alive
    my $self = shift;

    my $alive = 1;

    $alive = 0 if (!$self->{handle} || !$self->{handle}->ping);

    return $alive;
}

#*******************************************************************************

sub instance {
# test the existence of an arcturus instance on the current server
    my $self = shift;

    return 0 if $self->{mother}->{errors};

    return $self->{mother};
}

#*******************************************************************************

sub whereAmI {
# return a string with information about the instance accessed
    my $self = shift;
    my $nmbr = shift; # if True: return 0 for development, 1 for production server

    my $server = $self->{server};
    my $script = $self->{Script};

    my $text;
    if ($nmbr) {
        $text = 0 if ($script =~ /\bdev\b/);
        $text = 1 if ($script =~ /\bprod\b/);
    }
    elsif (!$server || !$script) {
        $text  = "don't know where I am:";
        $text .= " undefined server " if !$server;
        $text .= " undefined script " if !$script;
    }
    else {
        $server =~ s/^.*(babel|pcs3).*$/$1/;
        $text = "development" if ($script =~ /\bdev\b/);
        $text = "production"  if ($script =~ /\bprod\b\//);
        $text .= " database on $server";
    }
    return $text;
}

#*******************************************************************************
# dbHandle : (Arcturus specific) test if the arcturus database $database is
#            present under the current database incarnation (on this server)
#*******************************************************************************

sub dbHandle {
    my $self     = shift; 
    my $database = shift; # name of arcturus database to be probed
    my $hash     = shift; 

    print "GateKeeper enter dbHandle $debug" if $debug;

    my %options = (undefinedDatabase => 0, defaultRedirect => 1, returnTableHandle => 0);
    &importOptions(\%options, $hash);

    my $dbh = $self->{handle}; # may be replace below
    &dropDead($self,"No database handle available") if !$dbh;
    my $server = $self->{server};

    my $organisms = $self->{mother};
    &dropDead($self,"Inaccessible table 'ORGANISMS' on $server") if !$organisms;
    $dbh = $organisms if $options{returnTableHandle};

# if database specified as arcturus, just return the database handle

    if ($database && $database eq 'arcturus') {
        $self->{database} = 'arcturus';
        return $dbh;
    }
# if database not specified, use default arcturus, or abort
    elsif (!$database) { 
        &dropDead($self,"Undefined database name") if !$options{undefinedDatabase};
        $self->{database} = 'arcturus';
        return $dbh;
    }

# test if the requested organism database is available on this server; open ORGANISMS

    undef my %residence;
    undef my %available;

    if (my $hashrefs  = $organisms->associate('hashrefs')) {
        foreach my $hash (@$hashrefs) {
# TEMPORARY fix: pcs3 cluster is not visible as pcs3.sanger.ac.uk but as pcs3 only
            $hash->{residence} =~ s/pcs3\.sanger\.ac\.uk/pcs3/;
            $residence{$hash->{dbasename}} = $hash->{residence};
            $available{$hash->{dbasename}} = $hash->{available};
        }
    }
    else {
        &dropDead($self,"Empty table 'ORGANISMS' on $server");
    }

# prepare 'server' for comparison: strip out sanger part and put in wildcard
# is required because residence can come both with or without the 'sanger' bit

    $server =~ s/\.sanger\.ac\.uk//;
    $server =~ s/\:/\\S*:/;

# see if the arcturus database is on this server, else redirect

    my $cgi = $self->{cgi};
    undef $self->{database};
    if ($database && !$residence{$database}) {
        &dropDead($self,"Unknown arcturus database $database at server $server");
    } 
    elsif ($database && $residence{$database} !~ /$server/) {
# to be removed later:  redirection diagnostics
        if ($options{redirectTest}) {
            &dropDead($self,"redirecting $database ($residence{$database}) server:$server");
        }
# the requested database is somewhere else; redirect if in CGI mode
        if (!&cgiHandle($self,1) || !$options{defaultRedirect}) {
# if defaultRedirect <= 1 always abort; else, i.e. in batch mode, switch to specified server
            &report($self,"Database $database resides on $residence{$database}");
	    &dropDead($self,"Access to $database denied") if ($options{defaultRedirect} <= 1);
# close the current connection and open new one on the proper server 
            &disconnect($self);
# get the server and TCP port to redirect to
            my ($host,$port) = split ':',$residence{$database};
            my $pmaps = $self->{config}->get("port_maps",1);
            foreach my $map (@$pmaps) {
                $port = $1 if ($map =~ /\:(\d+)\:$port/);
            }
# open the new connection and repaet the setting up of the database/table handle
            $self->opendb_MySQL_unchecked("$host:$port",{defaultOpenNew => 1});
            delete $options{defaultRedirect};
            $dbh = $self->dbHandle($database,\%options);
        }
        elsif ($available{$database} ne 'off-line') {
            $self->disconnect();
            my $redirect = "http://$residence{$database}$ENV{REQUEST_URI}";
            $redirect .= $cgi->postToGet if $cgi->MethodPost;
            print redirect(-location=>$redirect);
            exit 0;
        }
        else {
            &dropDead($self,"Database $database is off-line");
        }
    }
    elsif ($available{$database} eq 'off-line') {
        &dropDead($self,"Database $database is off-line");
    }

    $self->{database} = $database;
    
    return $dbh;
}

#*******************************************************************************

sub tableHandle {
    my $self     = shift;
    my $database = shift;
    my $options  = shift;

    undef my %options;
    $options = \%options if !$options;
    $options->{returnTableHandle} = 1;

    return $self->dbHandle($database,$options);
}

#*******************************************************************************

sub focus {
    my $self = shift;
    my $fail = shift;

    my %options = (dieOnError => 0, useDatabase => $self->{database});
    $options{dieOnError} = $fail if (ref($fail) ne 'HASH');
    &importOptions(\%options, $fail); # if $fail's a hash

    if ((my $mother = $self->{mother}) && $options{useDatabase}) {
        $mother->query("use $options{useDatabase}");
    }
    elsif ($options{dieOnError}) {
        &dropDead($self,"Can't change focus: no database information");
    }
}

#*******************************************************************************

sub isAvailable {

    my $self     = shift;
    my $database = shift || $self->{database};

    my $accessible = 0;
    my $organisms = $self->{mother};

    &dropDead($self,"Can't access ORGANISMS table") if !$organisms;
    &dropDead($self,"Can't test availability: undefined database name") if !$database;

    my $available = $organisms->associate('available',$database,'dbasename');
    $accessible = 1 if ($available eq 'on line');

    return $accessible;
}

#############################################################################
# authorization
#############################################################################

sub authorize {
# authorisation method
    my $self = shift;
    my $code = shift;
    my $hash = shift;

# process possible hash input 

    my %options = ( testSession  => 1, # default test session number, else test username, password
                    makeSession  => 1, # default issue session number if in CGI mode (2 for always)
                    userSession  => 'oper', # uses default testSession => 1 for this user only
                    closeSession => 1, # default close existing session if outside specified windows
                    interim      => 1, # default submit interim form if CGI and no output page active
                    noConfirm    => 0, # default assign CONFIRM to returned submit button value 
                    noGUI        => 0, # default standard Arcturus GUI; else contents only
                    finalize     => 0, # default return after adding password query to existing form
                    noprompt     => 1, # default no prompt for username and/or password if missing & !CGI 
                    silently     => 1, # do everything quietly
                    dieOnError   => 0, # default do not abort on error, else die, except on closed session  
                    ageWindow    => 30, # acceptance window (minutes) for previously opened session
                    returnPath   => 0, # default return to same script
                    identify     => 0, # username (for possible usage in non-CGI mode)
                    password     => 0, # password (for possible usage in non-CGI mode)
                    session      => 0, # session ID (for possible usage in non-CGI mode)
                    diagnosis    => 0  # default off
		  );
    &importOptions(\%options, $hash);

# start by defining session, password, identify

    print "GateKeeper enter authorize $debug" if $debug;

    undef my ($cgi, $session, $password, $identify);

    if ($cgi = $self->cgiHandle(1)) {
# in CGI mode; any of these parameters may be absent from cgi input
        $session  = $cgi->parameter('session' ,0) || 0;
        $password = $cgi->parameter('password',0);
        $cgi->transpose('password') if $password; # remove from CGI input
        $identify = $cgi->parameter('identify',0);
        $cgi->transpose('identify') if $identify; # remove from CGI input
    }
    else {
        $cgi = $self->{cgi}; # the module handle
        $identify = $options{identify};
        $password = $options{password};
        $session  = $options{session};
    }
# recover USER from input info, if any ('identify' takes precedence over 'session' if both are present)
    if ($identify) {
        $self->{USER} = $identify;
    }
    elsif ($session) {
        $self->{SESSION} = $session;
        my @sdata = split ':',$session;
        $self->{USER} = $sdata[0];
# here we put an override for a specific user on 'testSession' and 'makeSession'
# this allows a different behaviour for the specified user from all others
        if ($options{userSession} && $self->{USER} eq $options{userSession}) {
            $options{testSession} = 1; # overrides input definition
        }
    }

    my $mother = $self->{mother};

    undef my ($priviledges,$seniority,$attributes);

    undef $self->{report};
    if ($session && $options{testSession}) {
# a session  number is defined
        $self->{report} = "Check existing sessions number $session";
        my $sessions = $mother->spawn('SESSIONS','self',0,1); # 0,0 later ?
        if ($self->{error} = $sessions->{errors}) {
            &dropDead($self,$sessions->{errors}) if $options{dieOnError};
	    return 0;
        }
# before testing the session number itself, we check the implied username 
       ($identify, my $code) = split ':',$session;
        my $users = $mother->spawn('USERS','self',0,1);
        if (my $hashref = $users->associate('hashref',$identify,'userid')) {
            $priviledges = $hashref->{priviledges} || 0;
            $seniority   = $hashref->{seniority}   || 0;
            $attributes  = $hashref->{attributes}  || 0;
            my $seed = &compoundName($identify,'arcturus',8);
            if (!$cgi->VerifyEncrypt($seed,$code)) { # check integrity 
                $self->{report} .= "! Corrupted session number $session";
                &dropDead($self,$self->{report}) if $options{dieOnError};
                $session = 0; # force (new) prompt for password 
            }
        }
        else {
            $self->{report} .= "! User $identify is not registered on this server";
            $session = 0;
        }
# test if session for this user still open; if not, force new request for password and username
        if (my $hashref = $sessions->associate('hashref',$session,'session')) {
            if ($hashref->{timeclose}) {
                $self->{report} .= "Arcturus session $session is already closed";
                &dropDead($self,$self->{report}) if ($options{dieOnError} > 1);
                return 0 if $options{dieOnError}; # "abort" option
                $session = 0; # force prompt for password 
	    }
            else {		
                $sessions->counter('session',$session,1,'access');
	    }
        }
# there is no such session number on the current server (e.g. after switching servers)
        elsif ($self->instance) {
# try if the session is on another server
            my $found = 0;
            my $instances = $self->{config}->get("mysql_ports",'insist unique array');
            my $this_host = $self->{server};
            $this_host =~ s/\.sanger\.ac\.uk|\:\d+//g;
            $this_host .= ':'.$self->{TCPort};
            $self->{report} .= "! Specified Arcturus session $session does not ";
            $self->{report} .= "exist on this server ($this_host)";
            foreach my $instance (@$instances) {
                if ($instance ne $this_host) {
                    if (my $dbh = &opendb_MySQL_unchecked ($self,$instance)) {
                        $self->{report} .= " .. opened $instance:";
                        if ($dbh->do("select * from SESSIONS where session = '$session'") > 0) {
# the session is found on another server: copy to the current server
                            $self->{report} .= "session $session found .. ";
                            if ($sessions->newrow('session',$session)) {
                                $sessions->signature(0,'session',$session,0,'timebegin');
                                $found = 1;
                            }
                            else {
                                $self->{report} .= "copy failed: $sessions->{qerror} ..";
                            }
                        }
                        $dbh->disconnect();
                    }
                }                
                last if $found;
            }
            $session = 0 if !$found; # force prompt for password
        }
        $cgi->delete('session') if (!$session && $self->cgiHandle(1)); # remove from CGI input
#??        &dropDead($self,$self->{report}) if $options{dieOnError};
        &report($self) if !$options{silently};
        undef $self->{report};
    }

    if (!$session || !$options{testSession}) {
# test if a user identification and password are provided
        my $users = $mother->spawn('USERS','self',0,1);
        if (!$password || !$identify) {
# add request for username and  password; abort in non-CGI mode
            if (!$self->cgiHandle(1) && $options{noprompt} > 1) {
                &dropDead($self,"Missing username or password");
            }
            elsif (!$self->cgiHandle(1) && $options{noprompt}) {
                return 0; # authorisation failed
            }
            elsif (!$self->cgiHandle(1)) {
# issue a prompt for password info on the command line
     &report($self,"Prompt for user name and password from STDIN (to be developed)");

	    }
# if interim set or no page exists pop up an intermediate authorisation form
            elsif ($options{interim} || !$cgi->pageExists) {
                $self->cgiHeader(2); # if not already done
                my $script = $self->currentScript;
                $script .= $options{returnPath} if $options{returnPath};
                my $page = $self->GUI("ARCTURUS authorisation");
                $page->frameborder(100,25) if $options{noGUI}; # display form only
                $page->form($script); # return to same url
                $page->sectionheader("ARCTURUS authorisation",3,1);
                $page->sectionheader("The requested ARCTURUS operation requires authorisation",4,0);
                my $text = ''; my $size = 8;
		if (!$self->instance || $users->{errors} || $identify && $identify eq 'oper') {
                    $text = " the Database"; $size = 14; 
	        }
                $page->sectionheader("Please provide your User Identification and${text} Password",4,0);
                $page->identify('10',$size,1);
                $page->confirmbuttonbar(0,0);
                $page->ingestCGI();
                $page->substitute('CONFIRM',$options{noConfirm}) if $options{noConfirm};
                $page->form(0); # end form
                $page->PrintVariables(0) if $options{diagnosis};
                $page->flush;
                &dropDead($self);
            }
    # there is an active form
            else {
                $cgi->sectionheader("Please provide your User Identification and Password",4,0);
                $cgi->identify('10',8,1); # add password request bar
                if ($options{finalize}) {
                    $cgi->submitbuttonbar(1,0);
                    $cgi->form(0);
                    $cgi->flush;
                    &dropDead($self);
                }
                else {
                    return 2; # complete/submit form in calling script
                }
	    }
        }

# a username and password are provided: verify identification and issue session number

        undef $self->{error};
        if (!$self->instance || $users->{errors}) {
# there is no (valid) user information: default to priviledged usernames and database password
            my $allowed = $self->{config}->get("devserver_access",'insist unique array');
            my $string  = join ' ',@$allowed;
            if (!$identify || !$password) {
                $self->{error} = "Missing username or database password";
            }
            elsif ($string !~ /\b$identify\b/) {
                $self->{error} = "User $identify has no database priviledges on this server";
            }
            elsif ($password ne $self->{config}->get('mysql_password')) {
                $self->{error} = "Invalid database password provided for user $identify";
            }
            $priviledges = $code; # forces acceptance
        }
        elsif (my $hash = $users->associate('hashref',$identify,'userid')) {
            $priviledges = $hash->{priviledges} || 0;
            $seniority   = $hash->{seniority}   || 0;
# superuser 'oper' has a special status; accounts defined on start-up have to be initialize by 'oper'
# print "identify '$identify'  hash '$hash->{password}'  passwd '$password' <br>";
            if ($hash->{password} eq 'arcturus' && $identify eq 'oper') {
# there are two possible passwords allowed: either 'arcturus' (unencrypted after startup) or the database password
# print "passage 1 priv: $priviledges<br>";
                if ($password ne 'arcturus' && $password ne $self->{config}->get('mysql_password')) {
                    $self->{error}  = "Invalid password !\nInitialize the operations account ";
                    $self->{error} .= "by\n defining a new password (MODIFY users)";
                }
            }
            elsif ($hash->{password} eq 'arcturus' && $identify ne 'oper') {
# occurs only on those accounts defined at installation of the USERS table (see 'arc_create' script)
                $self->{error}  = "Invalid password !\n\nThe \"$identify\" account has to be initialized";
                $self->{error} .= "by\nsuperuser \"oper\" (use MODIFY users)";
            }
            elsif (!$cgi->VerifyEncrypt($password,$hash->{password})) {
                $self->{error} = "Invalid password provided for user $identify";
            }
            elsif (!$priviledges) {
                $self->{error} = "User $identify has no priviledges set";
            }
# print "passage 5  error $self->{error}<br>";
        }
        elsif (!($self->{error} = $users->{errors})) {
            $self->{error} = "Unknown user: $identify";
        }

        &dropDead($self,$self->{error}) if ($self->{error} && ($options{dieOnError} || !$self->cgiHandle(1)));
        return 0 if $self->{error};

# okay, here the user has been identified: if CGI, issue a session number 

        if ($options{makeSession} > 1 || $options{makeSession} && $self->cgiHandle(1)) {
            $session = 0;
            my $sessions = $mother->spawn('SESSIONS','self',0,0);
            if ($sessions->{errors}) {
                &dropDead($self,$sessions->{error}) if $options{dieOnError};
	        return $sessions->{errors};
            }
# cleanup the sessions table (delete after 1 month, close yesterday if still open)
            my $interval = "timebegin < DATE_SUB(CURRENT_DATE, interval 1 MONTH)";
            $sessions->do("delete from <self> where $interval");
            $interval =~ s/MONTH/DAY/;
            $interval .= ' and (closed_by is NULL or timeclose is NULL)';
            $sessions->signature('oper','where',$interval,'closed_by','timeclose');
# test if a previous session for this user is still open; if so, how old is it?
            my $query = "select session, timebegin, (UNIX_TIMESTAMP(NOW())+0)-";
            $query .= "(UNIX_TIMESTAMP(timebegin)+0) AS age from <self> where ";
            $query .= "session like '$identify%' AND closed_by is NULL";
            my $array = $sessions->query($query,0,0);
            if ($array && ref($array) eq 'ARRAY' && $options{closeSession}) {
                my $ageOfSession = $array->[0]->{age};
                my $openSession = $array->[0]->{session};
                $self->{report} = "There is an existing active session $openSession; "; 
                if (defined($ageOfSession) && $ageOfSession/60 <= $options{ageWindow}) {
                    $self->{report} .= "Previous session $openSession will be continued ";
                    $self->{report} .= "(window $options{ageWindow} minutes $ageOfSession)";
                    $sessions->counter('session',$openSession,1,'access'); # update access counter
                    $session = $openSession;
                }
                elsif (defined($openSession)) {
                    $self->{report} .= "Previous session $openSession will be closed. ";
                    $sessions->signature('oper','session',$openSession,'closed_by','timeclose');
                }
                else {
                    $self->{report} .= "Possibly corrupted SESSIONS table: inconsistent data for $identify. ";
                }
            }
            &report($self) if !$options{silently};
            undef $self->{report};

# open a new session number if no one defined

            my $attempt = 9;
            while (!$session && $attempt > 0) {
                $session = &newSessionNumber ($self,$identify);
                if ($sessions->newrow('session',$session)) {
                    $sessions->signature(0,'session',$session,0,'timebegin');
                    $self->{report} .= "user ID verified, new session number $session";
                }
                else {
                    $session = 0;
                    $attempt--;
                    sleep 1;
                }
            }
            if ($session) {
                $cgi->replace('session',$session) if $self->cgiHandle(1); # add to CGI buffer
                $self->{SESSION} = $session;
            }
            else {
                $self->{report} .= "! Failed to issue an new session number after 9 trials";
                return 0 if $options{dieOnError};
	    }
        }    
    }

    &report($self) if !$options{silently};
    undef $self->{report};

# here priviledges should be defined; test priviledge(s) sought

    my $mask = $code;
    if (ref($code) eq 'HASH') {
        $mask = $code->{mask};
        if (my $user = $code->{user}) {
            my $users = $mother->spawn('USERS','self',0,1);
            if ($user eq $identify && $code->{notOnSelf}) {
                $self->{error} = "You can't <do this to> yourself"; # note the place holder
                return 0;
            }
            elsif ($user eq $identify) {
                $mask = 0; # actions on myself need no further test 
            }   
# test the seniority of the user mentioned against the one of $identify
            elsif ($seniority < 6 && $seniority <= $users->associate('seniority',$user,'userid')) {
                $self->{error} = "User $identify has no priviledge for this operation";
                $self->{error} .= ": insufficient seniority";
                return 0;
            }        
        }
    }

# does the user have access to this database?

    if ($attributes) {
        
    }

# test if the required priviledge matches the 

    if ($mask) {
# &report ($self,"code $code  mask $mask priviledges $priviledges");
        if (!$priviledges || $mask != ($mask & $priviledges)) {
            $self->{error} = "User $identify has insufficient priviledge for this operation";
	    $self->{error} .= "(pr: $priviledges mask $mask)";
            return 0;
        }
    }

    return 1; # authorization granted
}

#############################################################################

sub allowServerAccess {
# authorize for special case when user not (yet) registered
    my $self = shift;
    my $user = shift;

# limit access to development server to names listed in 'devserver_access'
# access ALWAYS granted on production server! 
# use ONLY for registration purposes

    if (!$self->whereAmI(1)) {
        my $allowed = $self->{config}->get('devserver_access','insist unique array');
        my $string = join ' ',@$allowed;
        if ($string !~ /\b$user\b/) {
            $self->{error} = "User '$user' has no priviledges on the development servers";
            return 0;
        }
    }

    return 1; # authorization granted
}

#############################################################################

sub newSessionNumber {
    my $self = shift;
    my $user = shift;

    my $seed = &compoundName($user,'arcturus',8);
    my $encrypt = $self->{cgi}->ShortEncrypt($seed,$user);
    my $session = "$user:$encrypt"; # name folowed by some 'random' sequence

    return $session;
}

#############################################################################

sub compoundName {
# scramble an input name with a radix string
    my $name = shift || 'n';
    my $radx = shift || 's';
    my $nmbr = shift ||  8 ; # length of output string 

    my @name = split //,$name;
    my @radx = split //,$radx;

    undef my $output;
    my $i = 0; my $j = 0;
    while (!defined($output) || length($output) < $nmbr) {
        $i = 0 if ($i >= @name);
        $j = 0 if ($j >= @radx);
        $output .= $name[$i++];
        $output .= $radx[$j++] if (length($output) < $nmbr);
    }
    return $output;
}

#############################################################################

sub closeSession {
# close the current session number
    my $self    = shift;
    my $session = shift || $self->{SESSION} || return;

    my $sessions = $self->{mother}->spawn('SESSIONS','self',0,0);

    $sessions->signature('self','session',$session,'closed_by','timeclose');
}

#*******************************************************************************
# arcturus CGI interface
#*******************************************************************************

sub GUI {
# standard Arcturus GUI form with full set of cross links between databases
    my $self  = shift;
    my $title = shift || 'No Title';
    my $modes = shift; # (optional) hash with some control parameters

    my %options = (defaultScript => '/cgi-bin/arcturus', doTransport => 1);
    &importOptions(\%options,$modes); 

    print "GateKeeper enter GUI $debug" if $debug;

# test if in CGI mode; else abort

    my $cgi = &cgiHandle($self,1);
    print "\n$title \n" if (!$cgi && $title);
    return 0 if !$cgi;

    my $script = $self->currentScript;
    $script .=  $self->currentOptions if $options{doTransport}; # ? a good idea?
    my @exclude = ('USER','redirect');
    my $postToGet = $cgi->postToGet(0,@exclude); # include 'database' but not USER

    my $connection = &whereAmI($self); # production or development

# get other servers, either on the same host or all of them

    my $config = $self->{config};
    my $full = 1; # include all servers
    my @url = split /\:|\./,$self->{server};
    my $hosts =$config->get('mysql_hosts','insist unique array');
    my $pmaps =$config->get('port_maps'  ,'insist unique array');
    undef my @alternates;
    undef my %altertypes;
    foreach my $server (@$hosts) {
# find server with the same host name but different port
        if ($full || $server =~ /\b$url[0]\b/ && $server !~ /\b$url[$#url]\b/) {
            $server =~ s/\.sanger\.ac\.uk//;
            push @alternates, $server;
            foreach my $map (@$pmaps) {
                my @ports = split ':',$map;
                $altertypes{$server} = $ports[0] if ($server =~ /\b$ports[2]\b/); 
            }
            $altertypes{$server} = 'C' if ($server =~ /\b$url[0]\b\S+\b$url[$#url]\b/);
	}
    }

# get other databases

    undef my @databases;
    undef my @offliners;
    my $mother = $self->{mother};
    my $hashes = $mother->associate('hashrefs');
    foreach my $hash (@$hashes) {
        if ($hash->{available} ne 'off-line') {
            push @databases, $hash->{dbasename};
        }
        else {
            push @offliners, $hash->{dbasename};
        }
    }

# get the default database if appropriate

    my $database;
    if (@databases == 1) {
        $database = $databases[0];
        $cgi->replace('database',$database); # make it the default database
    }
    elsif ($self->instance) {
        $database = $cgi->parameter('database',0) || $cgi->parameter('organism',0);
    }
    $database = 'arcturus' if !$database;

# colour palet

    my $gray = 'CCCCCC';
    my $purp = 'E2E2FF';
    my $yell = 'FAFAD2';
    my $cell = "bgcolor=$yell nowrap align=center";

# okay, now compose the page

    $self->cgiHeader(2); # in case not yet done
    my $page = $cgi->openPage("ARCTURUS $title");
    my $width = '10%';
    my $height = 50;
    $page->arcturusGUI($height,$width,$yell);
    my $smail = $config->get('signature_mail');
    my $sname = $config->get('signature_name');
    $page->address($smail,$sname,0,12);
# substitute values for standard place holders
    my $href = "href=\"/Arcturus.html\"";
    my $capt = "onMouseOver=\"window.status='About Arcturus'; return true\"";
    my $imageformat = "width=\"$width\" height=$height vspace=1";
    $page->{layout} =~ s/ARCTURUSLOGO/<A $href $capt><IMG SRC="\/icons\/bootes.jpg $imageformat"><\/A>/;
    $page->{layout} =~ s/SANGERLOGO/<IMG SRC="\/icons\/helix.gif $imageformat">/;

# compose the top bar (partition 2)

    $page->partition(2); $page->center(1);
    $connection =~ s/\b(dev\w+)\b/<font size=+1 color=red>$1<\/font>/;
    $connection =~ s/\b(pro\w+)\b/<font size=+1 color=blue>$1<\/font>/;
    my $banner = "You are connected to the ARCTURUS $connection";
    $banner =~ s/ARCTURUS/$database/ if ($database ne 'arcturus');
    $page->add($banner,0,0,"size=+1");
    
# compose the link lists on left- and right-hand sides

    my $emptyrow = "<TR><TD $cell>&nbsp</TD></TR>";

# compose the left-side link table  (dev/prod database functions; partitions 3,5)
# transfer to same script on different server; requires to omit database specification

    $page->partition(3);
    push @exclude, 'database';
    push @exclude, 'organism';
    my $defaultScript = $options{defaultScript};
    $defaultScript .= $cgi->postToGet(1,'session'); # if any
    if ($options{doTransport}) {
        $script .= $cgi->postToGet(0,@exclude);
    }
    else {
        $script = $defaultScript; # overrides
    }
    my $tablelayout = "cellpadding=2 border=0 cellspacing=0 width=$width align=center";
    my $table = "<table $tablelayout>";
    if (@alternates) {
        $table .= "<tr><th colspan=2 bgcolor='$purp' width=100%> Servers </th></tr>";
        foreach my $server (@alternates) {
            my @url = split /\:|\./,$server; $url[0] = uc($url[0]);
            my $type = uc($altertypes{$server}); $type =~ s/^(\w)\w*$/$1/;
            my %s = (D => 'DEVELOPMENT', P => 'PRODUCTION' , C => 'CURRENT');
            my $link = "$url[0]";
            my $title = "GO TO THE $s{$type} SERVER ON $url[0]";
            my $alt = "onMouseOver=\"window.status='$title'; return true\"";
            $link = "<a href=\"http://$server$script\" $alt> $link </a>" if ($type ne 'C');
            my $bgc = $cell; $bgc =~ s/$yell/yellow/ if ($type eq 'C');
#            $type = "&nbsp" if ($type eq 'C');
            $title .= " WITH DEFAULT USER INTERFACE" if ($type ne 'C');
            $title = "RESTORE DEFAULT USER INTERFACE THIS SERVER" if ($type eq 'C');;
            $alt = "onMouseOver=\"window.status='$title'; return true\"";
            $type = "<a href=\"http://$server$defaultScript\" $alt> $type </a>";
            $table .= "<tr><td $bgc width=87.5%>$link</td><td $cell width=12.5%>$type</td></tr>";
        }
    }
    $table .= "<tr><td $cell colspan=2> </td></tr>";
    $table .= "</table>";
    $page->space;
    $page->add($table);   
    $page->space;

# compose the database table for chosing a different database

    $page->partition(5);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> Databases </th></tr>";
    if (@databases) {
        my $current = $cgi->parameter('database',0);
        foreach my $database (sort @databases) {
            my $target = $script;
            $target =~ s/(database|organism|dbasename)\=\w+/$1=$database/;
            $target .= "\&database=$database" if ($target !~ /\b$database\b/);
      	    $target =~ s/\&/?/ if ($target !~ /\?/); # replace first & by ?
            my $link = $database; my $ulink = uc($link);
            my $alt = "onMouseOver=\"window.status='SELECT THE $ulink DATABASE'; return true\"";
            my $override = 0; $override = 1 if ($self->currentScript =~ /\bcreate\b/); 
            $link = "<a href=\"$target\" $alt> $link </a>" if (!$current || $current ne $link || $override);
            $table .= "<tr><td $cell width=100%>$link</td></tr>";
        }
    }
    $table .= $emptyrow;
    $table .= "</table>";
    $page->add($table); 
    $page->space(5-@databases); 

# the other table require the input database specification  

    my @include = ('database','organism','dbasename','session');

    my $target = &currentHost($self).&currentPort($self);
    $target = "target=\"${target}input\""; # e.g. 'babel19090input'
    $target = '' if !$cgi->parameter('session',0);

# compose the 'create' table: include assemblies and projects only if database is defined

    $page->partition(7);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> CREATE </th></tr>";
    my $label = "Database";
    if ($self->instance) {
        $title = "CREATE A NEW DATABASE";
    }
    else {
        $title = "CREATE A NEW ARCTURUS INSTANCE";
        $label = "arcturus";
    }
    my $alt = "onMouseOver=\"window.status='$title'; return true\""; 
    my $create = "/cgi-bin/create/organism/getform".$cgi->postToGet(1,'session');
#    my $create = "/cgi-bin/create/organism/getform".$cgi->postToGet(1,'session');
    $table .= "<tr><td $cell><a href=\"$create\" $alt> $label </a></td></tr>";
    if ($database && $database ne 'arcturus') {
        my $title = "CREATE A NEW ASSEMBLY FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $create = "/cgi-bin/amanager/specify/assembly".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$create\" $alt $target> Assembly </a></td></tr>";
        $title = "CREATE A NEW PROJECT FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $create = "/cgi-bin/amanager/specify/project" .$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$create\" $alt $target> Project </a></td></tr>";
    }
    elsif ($self->instance && @databases) {
        my $title = "CREATE A NEW ASSEMBLY";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $create = "/cgi-bin/amanager/preselect/assembly".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$create\" $alt $target> Assembly </a></td></tr>";
        $title = "CREATE A NEW PROJECT";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $create = "/cgi-bin/amanager/preselect/project" .$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$create\" $alt $target> Project </a></td></tr>";
    }
    if ($self->instance) {
        my $title = "REGISTER A NEW USER";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $create = "/cgi-bin/umanager/getform".$cgi->postToGet(1,'session');
        $table .= "<tr><td $cell><a href=\"$create\" $alt> User </a></td></tr>";
    }
    $table .= "<tr><td $cell>&nbsp </td></tr>";
    $table .= "</table>";
    $page->add($table);

# compose the update table

    $page->partition(6);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> Assign </th></tr>";
    if ($database && $database ne 'arcturus') {
        $title = "ALLOCATE USERS TO A PROJECT OF ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $update = "/cgi-bin/amanager/specify/users".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$update\" $alt target='userframe'> Users </a></td></tr>";
        $title =~ s/USERS/CONTIGS/;
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $update = "/cgi-bin/amanager/specify/contigs".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$update\" $alt target='userframe'> Contigs </a></td></tr>";
    }
    $table .= "</table>";
    $page->add($table);   
    $page->space(2-@databases); 
    $page->space(1);   
# and the TEST menu on the same partion
    $page->partition(6);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> TESTS </th></tr>";
    if ($database && $database ne 'arcturus') {
        $title = "RUN SELECTED TEST(S) ON THE ".uc($database)." CONTENTS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $update = "/cgi-bin/emanager/getmenu".$cgi->postToGet(1,@include); # other URL
        $table .= "<tr><td $cell><a href=\"$update\" $alt> Menu </a></td></tr>";
        $title = "DO ALL STANDARD TESTS ON THE ".uc($database)." CONTENTS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $update = "/cgi-bin/emanager/runtest/all".$cgi->postToGet(1,@include); # other URL
        $table .= "<tr><td $cell><a href=\"$update\" $alt target='workframe'> All </a></td></tr>";
    }
    $table .= "</table>";
    $page->add($table);
    $page->space(2-@databases); 
    $page->space(1);   
 
# compose the input table (direct to new window if session defined)

    $page->partition(4);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> INPUT </th></tr>";
    if ($self->instance && @databases) {
        $title = "ENTER READS"; 
        $title .= " FOR ".uc($database) if ($database && $database ne 'arcturus');
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $input = "/cgi-bin/rloader/arcturus/getform".$cgi->postToGet(1,@include);
        $input =~ s/getform/specify/ if ($database && $database ne 'arcturus');
        $table .= "<tr><td $cell><a href=\"$input\" $alt $target> READS </a></td></tr>";
        $title =~ s/READS/CONTIGS/;
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $input = "/cgi-bin/cloader/arcturus/getform".$cgi->postToGet(1,@include);
        $input =~ s/getform/specify/ if ($database && $database ne 'arcturus');
        $table .= "<tr><td $cell><a href=\"$input\" $alt $target> CONTIGS </a></td></tr>";
    }
    if ($database && $database ne 'arcturus') {
        $title = "LOAD TAG INFORMATION FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $input = "/cgi-bin/create/existing/process".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$input\&tablename=STSTAGS\" $alt $target> TAGS </a></td></tr>";
        $title = "LOAD MAPPING INFORMATION FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$input\&tablename=CLONEMAP\" $alt $target> MAPS </a></td></tr>";
    }
    else {
        $table .= $emptyrow;
        $table .= $emptyrow;
    }
    $table .= "</table>";
    $page->space;
    $page->add($table);   
    $page->space;

# compose the links for edit scripts 

    $page->partition(8);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100% nowrap> MODIFY </th></tr>";
    if ($database && $database ne 'arcturus') {
# $title = "LOAD TAG INFORMATION FOR ".uc($database);
# $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $update = "/cgi-bin/create/existing/getform".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$update\"> $database </a></td></tr>";
        $update = "/cgi-bin/amanager/specify/assembly".$cgi->postToGet(1,@include); # other URL
        $table .= "<tr><td $cell><a href=\"$update\" target='workframe'> Assembly </a></td></tr>";
        $update = "/cgi-bin/pmanager/specify/project".$cgi->postToGet(1,@include);  # other URL
        $table .= "<tr><td $cell><a href=\"$update\" target='workframe'> Project </a></td></tr>";
    }
    if ($self->instance) {
        my $update = "/cgi-bin/umanager/getmenu".$cgi->postToGet(1,'session');
        $table .= "<tr><td $cell><a href=\"$update\"> Users </a></td></tr>";
#    $update = "/cgi-bin/update/newform".$cgi->postToGet(1,'session');
        $update = "/cgi-bin/create/arebuild".$cgi->postToGet(1,'session');
        $table .= "<tr><td $cell><a href=\"$update\"> arcturus </a></td></tr>";
    }
    $table .= "<tr><td $cell> </td></tr>";
    $table .= "</table>";
    $page->add($table);
    $page->space(3-@databases); 

# add the query options (always direct to 'querywindow')

    $page->partition(9);
    my $querywindow =  "target=\"querywindow\"";

    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> QUERY </th></tr>";
    if ($database && $database ne 'arcturus') {
        $title = "QUERY THE ".uc($database)." CONTENTS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $query = "/cgi-bin/query/overview?database=$database";
        $table .= "<tr><td $cell><a href=\"$query\" $alt $querywindow>$database</a></td></tr>";
    }
    if ($self->instance) {
        $title = "COMMON DATABASE CONTENTS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $query = "/cgi-bin/query/overview?database=arcturus";
        $table .= "<tr><td $cell><a href=\"$query\" $alt $querywindow>arcturus</a></td></tr>";
        $title = "USER INFORMATION";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $query = "/cgi-bin/umanager/locate".$cgi->postToGet();
        $table .= "<tr><td $cell><a href=\"$query\" $alt $querywindow>users</a></td></tr>";
    }
    $table .= "</table>";
    $page->add($table); 
    $page->space(3-@databases); 

# add the help and exit buttons

    $page->partition(10);
    $table = "<table $tablelayout>";
    $title = "WOT YOU ZINK??";
    $title = ' ';
    $alt = "onMouseOver=\"window.status='$title'; return true\""; 
    my $query = "/cgi-bin/query/help?script=$script";
    $cell = "bgcolor='yellow' nowrap align=center";
    $table .= "<tr><td $cell><a href=\"$query\" $alt $querywindow>HELP</a></td></tr>";
     
    if ($self->instance && $cgi->parameter('session',0)) {
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $query = "/cgi-bin/arcturus/signoff".$cgi->postToGet(1,@include);
        $cell = "bgcolor='lightgreen' nowrap align=center";
        $table .= "<tr><td $cell><a href=\"$query\" $alt>SIGN OFF</a></td></tr>";
    }
    elsif ($self->instance) {
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $query = "/cgi-bin/arcturus/signon".$cgi->postToGet(1,@include);
        $cell = "bgcolor='lightblue' nowrap align=center";
        $table .= "<tr><td $cell><a href=\"$query\" $alt>SIGN ON</a></td></tr>";
    }
    $table .= "</table>";
    $page->add($table); 


# go back to the main section

    $page->partition(1);
    $page->center(1);

    print "GateKeeper GUI exit $debug" if $debug;

    return $page;
}

#*******************************************************************************
# current server and script data
#*******************************************************************************

sub currentScript {
    my $self = shift;

    my $script = $self->{Script};
    $script =~ s?^.*cgi-bin?/cgi-bin?;

    return $script;
}

#*******************************************************************************

sub currentScriptRoot {
    my $self = shift;

    my $scriptroot = $ENV{SCRIPT_FILENAME};
    $scriptroot =~ s?^(.*cgi-bin)/\S*$?$1?;

    return $scriptroot;
}
#*******************************************************************************

sub currentOptions {
# return any additional path_info after script name
    my $self = shift;

    my $options = $self->origin(@_);
    $options = '' if ($options !~ /\S/); # defined but 'false'

    return $options;
}

#*******************************************************************************

sub currentHost {
    my $self = shift;

    my @hostinfo = split /\.|\:/,$self->{server};

    return $hostinfo[0];
}

#*******************************************************************************

sub currentPort {
    my $self = shift;

    my @hostinfo = split /\.|\:/,$self->{server};

    return $hostinfo[$#hostinfo];
}

#*******************************************************************************

sub currentServer {
    my $self = shift;

    return $self->{server}; # the internal name used for the server URL
}
 
#*******************************************************************************

sub currentUser {
# return the current(ly authorized) user
    my $self = shift;

    return $self->{USER} || '';
}
 
#*******************************************************************************

sub currentSession {
# return the current(ly authorized) user
    my $self = shift;

    return $self->{cgi}->parameter('session',0) || '';
}

#*******************************************************************************
# error processing and reporting
#*******************************************************************************

sub dropDead {
# disconnect and abort with message
    my $self = shift;
    my $text = shift;
    my $edbi = shift; # reserve for DBI error

    if ($text) {
        $text = "! $text" if $text;
        if ($edbi && $DBI::errstr) {
            $text .= ": $DBI::errstr";
        }
        elsif ($edbi) {
            $text .= " (No DBI error reported)";
        }
        $self->disconnect($text);
    }
    else {
        $self->disconnect();
    }

    exit 0;
}

#*******************************************************************************

sub transfer {
# redirect command; must come before any other output of a script
    my $self = shift;
    my $link = shift;

    print "GateKeeper enter transfer $debug" if $debug;

    $self->disconnect();
    print redirect({-location=>$link});
    exit 0;
}

#*******************************************************************************

sub disconnect {
# disconnect with message
    my $self = shift;
    my $text = shift;

    &report($self,$text) if $text;

    $self->{handle}->disconnect if $self->{handle};
}

#*******************************************************************************

sub report {
# print message with check on return header status (i.e. current page or STDOUT)
    my $self = shift;
    my $text = shift;

    my $tag = "\n";
    if ($self->{cgi} && $self->{cgi}->{status}) {
        $self->{cgi}->PrintHeader(1) if !$self->{cgi}->{'header'}; # plain text
        $tag = "<br>" if ($self->{cgi}->{'header'} == 1);
        $text = $self->{report} if ! $text;
        $text =~ s/\n/$tag/g if $text;
    }

    if ((my $page = $self->{cgi}) && $self->{cgi}->pageExists) {
        $page->add($text.$tag);
    }
    else {
        print STDOUT "$tag$text$tag\n" if $text;
    }
}

#############################################################################

sub environment {
    my $self = shift;

    my $text = "Environment variables: \n";

    foreach my $key (keys %ENV) {
        $text .= "key $key  = $ENV{$key}\n";
    }

    $text .= $self->{cgi}->PrintVariables if $self->{cgi};

    $text .= "\nARGV: @ARGV\n" if @ARGV;

    &report($self,$text);
}

#############################################################################

sub prepareFork {
# redefine environment variables to fork execution of another script (under CGI)  
    my $self = shift;
    my $name = shift; # name of script to be executed

    my $csroot = $self->currentScriptRoot;
    $ENV{SCRIPT_FILENAME} = "$csroot/$name"; # absolute
    $ENV{SCRIPT_NAME}    = "/cgi-bin/$name"; # relative to cgi-bin
    delete $ENV{PATH_INFO};

    return $csroot;
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>              81 ,
        version =>             1.0 ,
        updated =>    "09 Sep 2002",
        date    =>    "26 Jun 2002",
    };
}

#############################################################################

1;
