package GateKeeper;

use strict;

use DBI;               # database interface
use MyHTML;            # my CGI input and HTML output formatter
use ArcturusTable;     # ARCTURUS database table interface
use ConfigReader;      # confuration data input

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

my %instances; # class variable

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
    undef $self->{available};
    undef $self->{config};
    undef $self->{cgi};
    $self->{ARGV} = [];
    undef $self->{USER};
    undef $self->{taccess};

    bless ($self, $class);

# get options

    my %options = (eraiseMySQL    => 0,  # open (MySQL) with RaiseError =0 
                   dieOnNoTable   => 1,  # die if ORGANISMS table not found/ opened
                   insistOnCgi    => 0,  # default alow command-line access
                   HostAndPort    => '', # (H:P) default use current server; define e.g. in non-CGI mode
                   writeAccess    => 0,  # default ... to be changed
                   bufferedOutput => 0,  # default use unbuffered output
                   errorToNull    => 0,  # default redirect STDERR to STDOUT
                   standardBuild  => 1,  # don't touch: special provision for spawn method
                   diagnosticsOn  => 0); # set to 1 for some progress information

    if ($eraise && ref($eraise) eq 'HASH') {
        &importOptions(\%options,$eraise);
        $debug =  "\n"  if ($options{diagnosticsOn} == 1);
        $debug = "<br>" if ($options{diagnosticsOn} == 2);
    }
    else { # accommodate deprecated older usage
        $options{eraiseMySQL} = $eraise if $eraise;
        $options{insistOnCGI} = $usecgi if $usecgi;
    }


    if ($options{standardBuild}) {

# buffering

        &setUnbufferedOutput($self,$options{errorToNull}) if !$options{bufferedOutput};

# check on command-line input

        &clinput(0,$self);

# open the CGI input handler if in CGI mode

        &cginput(0,$self,$options{insistOnCGI});

# produce return string for diagnostic purposes, if specified

        &cgiHeader($self,$options{diagnosticsOn}) if $options{diagnosticsOn};
    }

# open and parse the configuration file

    &configure(0,$self);

# open the database

    &opendb_MySQL(0,$self,\%options) if ($engine && $engine =~ /^mysql$/i);

# &opendb_Oracle(0,$self,$eraise) if ($engine && $engine =~ /^oracle$/i); # or similar later

    &dropDead($self,"Invalid database engine $engine") if ($engine && !$self->{handle});

    $self->{engine} = $engine;

# okay, add the (residence of this) GateKeeper to the list

    my $residence = $self->currentResidence;
$self->report("NEW GATEKEEPER on current residence $residence") if $debug;
    $instances{$residence} = $self if !$instances{$residence}; # only on first occasion

    return $self;
}

#*******************************************************************************
# unbuffered output
#*******************************************************************************

sub setUnbufferedOutput {
# redirect errors to standard output and make unbuffered
    my $self = shift; # &report($self,"Set Unbuffered");
    my $null = shift; # if true, redirect STDERR to NULL

    if ($null) {
        open(STDERR,">&/dev/null");
    }
    else {
        open(STDERR,">&STDOUT") || die "Can't dump to STDOUT: $!\n";
    }
    select(STDERR); $| = 1; # Make unbuffered.
    select(STDOUT); $| = 1; # Make unbuffered.
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

# the next block handles redirection debugging; remove later

  if ($self->lookup("EJZREDIRECT",0)) {
    $debug = 1;
    $self->cgiHeader(2);
    $self->report("Redirected");
    $self->{cgi}->PrintEnvironment(1);
    $self->{cgi}->delete("EJZREDIRECT");
    $self->{cgi}->PrintVariables(1);
  }
}

#*******************************************************************************

sub cgiHandle {
# return a handle to the cgi input hash, if any
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

sub lookup {
# find the value of a named item
    my $self = shift;
    my $name = shift;
    my $mode = shift; # || 1; # re: cgi input
 
# scan the Config data first, then if not found CGI input data and then GateKeeper hash

    undef my $value;

    if (my $cfh = $self->configHandle) {
        $value = $cfh->get("$name");
        return $value if defined($value);
    }

    if (my $cgi = $self->cgiHandle(1)) {
        $value = $cgi->parameter("$name",$mode); # note possible additional input
        return $value if (defined($value) || $mode);
    }

    $value = $self->{$name};

# $self->report("lookup in GateKeeper module $name : $value") if defined($value);
        
    return $value;
}

#*******************************************************************************

sub cgiError {
# returns true if errors are found on cgi parameter input, else 0
    my $self = shift;
    my $list = shift; # add message to output stream

    my $error = $self->{cgi}->{und_error} || 0;

    $self->report("Please define all input fields: $error") if ($error && $list);

    return $error;
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

    if (!$alive) {
# if specified in in local/bin try to recover with bin 
        $mysqladmin =~ s/\/local//;

       `$mysqladmin -h $host -P $port -u ping ping >/dev/null 2>&1`;

        $alive = ($? == 0);
    }


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

    my %options = (defaultOpenNew    => 0, # force a new connection with 1
                   defaultInstall    => 1, # adopt new values for server, TCPort, etc
                   dieOnNoTable      => 0, # default continue even if ORGANISMS table not accessible 
                   dieOnError        => 1, 
                   writeAccess       => 0, # default no write access
                   returnTableHandle => 0, # default return database handle
                   RaiseError        => 0);
    &importOptions(\%options,$hash);

# test against default server, else open a new connection

    my ($server,$port) = split ':',$host;
    if (!$options{defaultOpenNew} && $self->{handle}) { # the current handle!
        &dropDead($self,"Invalid host:TCP port specification in host $host") if ($host !~ /\:/);
        return $self->{handle} if ($self->{server} =~ /$server/ && $self->{TCPort} == $port);
    }

# build the data source name

    my $dsn = "DBI:mysql:arcturus:host=$host";

# get database authorization

    my $config = $self->{config};

    my $username = $config->get("mysql_ro_username",'insist');
    my $password = $config->get("mysql_ro_password",'insist');
# writeAccess option overrides default username
    if ($options{writeAccess}) {
        $username = $config->get("mysql_username",'insist');
        $password = $config->get("mysql_password",'insist');
    }
# test configuration data input status
    if (my $status = $config->probe(1)) {
        &dropDead($self,"Missing or Invalid information on configuration file:\n$status") if $options{dieOnError};
        return 0;
    }

# and open up the connection

    my $handle = DBI->connect($dsn, $username, $password, $options{RaiseError});

    if (!$handle) {          
        &dropDead($self,"Failed to access arcturus on host $host",1) if $options{dieOnError};
        return 0;
    }

# okay, here the database has been properly opened on host/port $host;

    my $mother = new ArcturusTable($handle,'ORGANISMS','arcturus',1,'dbasename');

    if ($mother->{errors} && $options{dieOnNoTable}) {
        &dropDead($self,"Failed to access table ORGANISMS on $host");
    }


    if ($options{defaultInstall}) {
# adopt the (until now) transient connection data TO BE DEVELOPED
        my $residence = $self->currentResidence;
# here, delete the current instance from this connection, if any
# NOTE: this may muck up the counters in case of multiple connection to the same instance; should be improved

        $self->{server} = $server;
$self->{open} .= "opendb_MySQL_unchecked: defining self->server: $server <br>";
        $self->{TCPort} = $port;
        $self->{handle} = $handle;
        $self->{mother} = $mother;

# register instance on this port (only on first occasion)
# NOTE: this may muck up the counters in case of multiple connection to the same instance; should be improved

        $residence = $self->currentResidence;
$self->report("NEW GATEKEEPER on current residence $residence server:$self->{server}") if $debug;
        $instances{$residence} = $self if !$instances{$residence};
    }

    $handle = $mother if ($options{returnTableHandle});

    return $handle;
}

#*******************************************************************************

# The HTTP_HOST environment variable is not to be trusted. It is set to
# whatever the HTTP client specified in the request, and can therefore
# be spoofed. The SERVER_NAME and SERVER_PORT variables, on the other
# hand, are set by Apache and are the true name and port for the virtual
# server.

sub getHostAndPort {
# from apache-set environment
    my $servername = $ENV{'SERVER_NAME'};
    my $serverport = $ENV{'SERVER_PORT'};
    my $http_host  = $ENV{'HTTP_HOST'};

    if (defined($servername) && defined($serverport)) {
	return "$servername:$serverport";
    }
    elsif ($http_host) {
        return $http_host;
    }
    else {
	return 0;
    }
}

#*******************************************************************************

sub opendb_MySQL {
# create database handle on the current server and port
    my $lock = shift;
    my $self = shift;
    my $hash = shift;

    my %options = (RaiseError   => 0,   # default do NOT die on error
                   dieOnNoTable => 1,   # default die on ORGANISMS table error
                   writeAccess  => 0,   # default no write access
                   HostAndPort  => ''); # define e.g. in non-CGI mode

    &importOptions(\%options,$hash);
    my $eraise = $options{RaiseError} || 0;

    print "GateKeeper enter opendb_MySQL $debug" if $debug;

    &dropDead($self,"You're not supposed to access this method") if $lock;

    undef $self->{server};
    undef $self->{handle};

# we now test if the specified database is installed on the current CGI server

#$debug = 1;
print "config $self->{config}\n" if $debug;

    if (my $config = $self->{config}) {
# get database parameters
        my $driver    = $config->get("db_driver",'insist');
        my $username  = $config->get("mysql_ro_username",'insist');
        my $password  = $config->get("mysql_ro_password",'insist');
# write access option overrides userinfo
        if ($options{writeAccess}) {
            $username = $config->get("mysql_username",'insist');
            $password = $config->get("mysql_password",'insist');
        }
        my $db_name   = $config->get("mysql_database");
        $db_name = 'arcturus' if !$db_name; # default
        my $base_url  = $config->get("mysql_base_url");
        my $hosts     = $config->get("mysql_hosts",'insist unique array');
        my $port_maps = $config->get("port_maps"  ,'insist unique array');
# test configuration data input status
        my $status    = $config->probe(1);
        &dropDead($self,"Missing or Invalid information on configuration file:\n$status") if $status;

$self->report("test combinations: @$port_maps") if $debug;

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

        my @url;
        my $http_port = 0;
        undef my $mysqlport;
        if (&getHostAndPort() && !$options{HostAndPort}) {
            my $HTTP_HOST = &getHostAndPort();
$self->report("HTTP_HOST: $HTTP_HOST") if $debug;
            $HTTP_HOST =~ s/internal\.//; # for connections from outside Sanger
            $HTTP_HOST =~ s/\:/.${base_url}:/ if ($base_url && $HTTP_HOST !~ /\.|$base_url/);
            foreach my $host (@$hosts) {
                $host =~ s/\:/.${base_url}:/ if ($base_url && $host !~ /\.|$base_url/);
                if ($host eq $HTTP_HOST) {
$self->{open} .= "opendb_MySQL: HTTP_HOST define self->server as $host <br>";
                    $self->{server} = $host;
                    @url = split /\.|\:/,$host;
                    $http_port = $url[$#url];
                }
            }
        }
# HTTP_POST not defined, i.e. no CGI: test if the host/port combination option is defined
        elsif ($options{HostAndPort}) {
$self->{open} .= "opendb_MySQL: HostAndPort define self->server as $options{HostAndPort} <br>";
           ($self->{server}, $mysqlport) = split /\:/,$options{HostAndPort};
$self->report("NON CGI HostAndPort host:$self->{server}, port: $mysqlport") if $debug;
            $self->{TCPort} = $mysqlport;
            delete $ENV{MYSQL_TCP_PORT}; # override
	    $url[0] = $self->{server};
        }
# try local host or default
        else {
            my $name = `echo \$HOST`;
            chomp $name;
            $name =~ s/pcs3\w*/pcs3/;
            $name =~ s/pcs2\w*/babel/;
$self->report("host from echo HOST: $name") if $debug;
            foreach my $host (@$hosts) {
                @url = split /\.|\:/,$host;
#$self->{open} .= "opendb_MySQL: from local host define self->server as $url[0] <br>";
                $self->{server} = $url[0] if ($name eq $url[0]);
            }
#$self->{open} .= "opendb_MySQL: from default_host define self->server as $url[0] <br>" if !$self->{server};
            $self->{server} = $config->get("default_host") if !$self->{server}; # default
$self->dropDead("server $self->{server}") if $debug;
#$self->report("server $self->{server}");
        }

# TEMPORARY fix:this line is added because the pcs3 cluster is not visible as pcs3.sanger.ac.uk
        $self->{server} =~ s/pcs3\.sanger\.ac\.uk/pcs3/;
#        $self->{server} =~ s/pcs3/pcs3.internal/ if ($self->{server} !~ /internal/);

# check the MySQL port against the CGI port and/or the scriptname

        if (defined($ENV{MYSQL_TCP_PORT})) {
# get the port and script names
            $mysqlport = $ENV{MYSQL_TCP_PORT}; 
            if (my $scriptname = $ENV{SCRIPT_FILENAME}) {
# test the MySQL port and script name combination; get cgi port
                my $identify = 0;
$self->report("test combinations: @$port_maps") if $debug;
                foreach my $combination (@$port_maps) {
                    my ($script, $tcp, $cgi) = split /\:/,$combination;
$self->report("combination $combination MSQLPORT $ENV{MYSQL_TCP_PORT} $scriptname $script") if $debug;
	            if ($tcp eq $ENV{MYSQL_TCP_PORT} && $scriptname =~ /^.*\b($script)\b.*$/) {
# MySQL port and script directory verified; finally test the cgi port (if any)
$self->report("http_port $http_port   cgi $cgi") if $debug;
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
                &dropDead($self,"Missing script identifier: can't verify production or development use");
            }
        }
	elsif (!$mysqlport) {
            &dropDead($self,"Undefined MySQL port number");
	}

        if ($self->{server}) {
# check if the database is alive
            &ping_MySQL($self,$url[0],$mysqlport,1);       
# check whether the driver is available
            my @drivers = DBI->available_drivers;
# $self->report("\nDrivers : @drivers\n");
            my $i = 0;
            while (($i < @drivers) && ($driver ne $drivers[$i])) {
               $i++;
            }
            &dropDead($self,"Driver syntax incorrect or Driver $driver is not installed") if ($i >= @drivers);
# build the data source name
            my $dsn = "DBI:".$driver.":".$db_name.":".$url[0];
            $dsn .= ":$mysqlport" if $mysqlport;
$self->report("DSN : $dsn  selserver $self->{server}") if $debug;
# and open up the connection
            $eraise = 1 if !defined($eraise);
            $self->{handle} = DBI->connect($dsn, $username, $password, {RaiseError => $eraise}) 
                              or &dropDead($self,"Failed to access $db_name: (dsn: $dsn)",1); 
# okay, here the database has been properly opened on host/port $self->{server};
        }
        elsif (&getHostAndPort()) {
            &dropDead($self,"Invalid database server specified: " . &getHostAndPort());
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
$self->report("options $options{dieOnNoTable} ") if $debug;
    if ($self->{mother}->{errors} && $options{dieOnNoTable}) {
        &dropDead($self,"Failed to access table ORGANISMS on $self->{server}");
    }
}

#*******************************************************************************

sub importOptions {
# private function : override options hash with input hash
    my $options = shift;
    my $hash    = shift;

    my $status = 0;
    if (ref($options) eq 'HASH' && ref($hash) eq 'HASH') {
# put or replace options entries by input hash entries
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
#print "Where Am I: server = $server <br>\n";
        $server =~ s/^.*(babel|pcs3).*$/$1/;
        $text = "development" if ($script =~ /\bdev\b/);
        $text = "production"  if ($script =~ /\bprod\b\//);
        $text .= " database on $server";
    }
    return $text;
}

#*******************************************************************************
# spawn a new GateKeeper
#*******************************************************************************

sub spawn {
# return a GateKeeper with a connection to the appropriate database port
    my $self      = shift;
    my $database  = shift;
    my $options   = shift;

    my $engine    = $self->{engine};
    my $organisms = $self->{mother};
    my $residence = $organisms->associate('residence',$database,'dbasename');
# set up alternate residence name for the non-cgi case (host:dbport only)
    my $alternate = $residence; $alternate =~ s/(\:\w+)\:\w+/$1/;
 
print "GateKeeper spawn database $database  residence=$residence \n";
my @inst = keys %instances;
print "existing instances on @inst \n\n";

    if ($residence && $instances{$residence}) {
# there is an existing GateKeeper which connects to the correct port
$self->report("Using existing GateKeeper $instances{$residence} \n");
        return $instances{$residence};
    }
    elsif ($residence && $instances{$alternate}) {
# there is an existing GateKeeper which connects to the correct port
$self->report("Using existing GateKeeper $instances{$alternate} \n");
        return $instances{$alternate};
    }
    elsif ($residence) {
# open a connection to the database on this new port by invoking the GateKeeper constructor
        undef my %options;
        &importOptions(\%options,$options);
        $options{standardBuild} = 0;
        $residence =~ s/(\:\w+)\:\w+/$1/; # chop off apache port 
        $options{HostAndPort} = $residence;
$self->report("Spawning new GateKeeper of $self \n");
        my $spawn  = $self->new($engine,\%options);
        if ($spawn) {
# finally copy the CGI configuration and ARGV from the parent
            $spawn->{cgi}    = $self->{cgi};
            $spawn->{config} = $self->{config};
            $spawn->{ARGV}   = $self->{ARGV};
        }
        return $spawn;
    }
    else {
        my $server = $self->currentResidence;
        $self->report("Unkown database $database on $engine instance $server");
        return 0;
    }
        

}

#*******************************************************************************
# dbHandle : (Arcturus specific) test if the arcturus database $database is
#            present under the current database incarnation (on this server)
#*******************************************************************************

sub dbHandle {
    my $self     = shift; 
    my $database = shift; # name of arcturus database to be probed
    my $hash     = shift; 

print "GateKeeper enter dbHandle $database $hash $debug" if $debug;

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
            my $residence = $hash->{residence};
$residence =~ s/pcs3\.sanger\.ac\.uk/pcs3/;
# $residence =~ s/pcs3/pcs3.internal.sanger.ac.uk/;
            $residence =~ s/\:\w+\:/:/; # strip out TCP port to get host:cgiport
            $residence{$hash->{dbasename}} = $residence;
            $available{$hash->{dbasename}} = $hash->{available};
        }
    }
    else {
        &dropDead($self,"Empty table 'ORGANISMS' on $server");
    }

# prepare 'server' for comparison: strip out sanger part and put in wildcard
# is required because residence can come both with or without the 'sanger' bit

    $server =~ s/\.sanger\.ac\.uk//;
    my $serverstring = $server;
    $serverstring =~ s/\:/\\S*:/;

# see if the arcturus database is on this server, else redirect

#$debug = 1;
    my $cgi = $self->{cgi};
    undef $self->{database};
    if ($database && !$residence{$database}) {
# foreach my $key (%residence) {print "$key $residence{$key}\n";}
        &dropDead($self,"Unknown arcturus database $database at server $server");
    } 
    elsif ($database && $residence{$database} !~ /$serverstring/) {
# to be removed later:  redirection diagnostics
#$debug = "\n";
        if ($options{redirectTest}) {
            &dropDead($self,"redirecting $database ($residence{$database}) server:$server");
        }
# the requested database is somewhere else; redirect if in CGI mode
        if (!&cgiHandle($self,1) || !$options{defaultRedirect}) {
# if defaultRedirect <= 1 always abort; else, i.e. in batch mode, switch to specified server
&report($self,"server $self->{server} $serverstring ($residence{$database})") if $debug;
&report($self,"Redirecting: database $database resides on $residence{$database}") if $debug;
	    &dropDead($self,"Access to $database denied (no redirect)") if ($options{defaultRedirect} <= 1);
# close the current connection and open new one on the proper server 
            &disconnect($self);
# get the server and TCP port to redirect to
            my ($host,$port) = split ':',$residence{$database};
            my $pmaps = $self->{config}->get("port_maps",1);
            foreach my $map (@$pmaps) {
                $port = $1 if ($map =~ /\:(\d+)\:$port/);
            }
# remove the current instance if it was the last one registered
            my $residence = $self->currentResidence;
            delete $instances{$residence} if ($instances{$residence} eq $self);
# open the new connection and repeat the setting up of the database/table handle
&report($self,"Opening new connection on $host:$port") if $debug;
            my %uoptions = (defaultInstall => 1, writeAccess => 0, defaultOpenNew => 1);
            $self->opendb_MySQL_unchecked("$host:$port",\%uoptions); # no write access
            delete $options{defaultRedirect};
            $dbh = $self->dbHandle($database,\%options);
        }
        elsif ($available{$database} ne 'off-line') {
# redirect the cgi query to another url
            my $redirect = "http://$residence{$database}$ENV{REQUEST_URI}";
            $self->redirect($redirect);
            exit 0;
        }
        else {
            &dropDead($self,"Database $database is off-line");
        }
    }
    elsif ($available{$database} eq 'off-line') {
        &dropDead($self,"Database $database is off-line");
    }

    $self->{database}  = $database;

    $self->{available} = $available{$database};
    
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
    my $fail = shift; # either 1 for dieOnError or 0, or HASH with parameters

    my %options = (dieOnError => 1, useDatabase => $self->{database});
    $options{dieOnError} = $fail if (ref($fail) ne 'HASH');
    &importOptions(\%options, $fail); # if $fail's a hash

    my $status = 0;
    my $database = $options{useDatabase};
    if ((my $mother = $self->{mother}) && $database) {
# shift focus to database $database
        if ($mother->do("use $database")) {
# verify that the command has executed by probing the default database
            my $readback = $mother->query("select database()");
            if (ref($readback) eq 'ARRAY') {
                $readback = $readback->[0]->{'database()'};
            }
            if ($readback eq $database) {
                $status = 1; # success
            }
            elsif ($options{dieOnError}) {
                $self->dropDead("Can't change focus: command 'use $database' misfired");
            }
        }
        elsif ($options{dieOnError}) {
            $self->dropDead("Can't change focus: command 'use $database' failed");
        }
    }
    elsif ($options{dieOnError}) {
        $self->dropDead("Can't change focus: no database information");
    }

    return $status;
}

#*******************************************************************************

sub redirect {
# redirect command; must come before any other output of a script
    my $self = shift;
    my $link = shift;

    $self->disconnect();

    $self->{cgi}->ReDirect($link) if $self->{cgi};

    $self->dropDead("redirection not possible in non-CGI mode");

    exit 0;
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

# $debug=1;
print "GateKeeper: enter authorize $debug\n" if $debug;

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
                    tableAccess  => '', # require access to named table(s); default ALL
                    session      => 0, # session ID (for possible usage in non-CGI mode)
                    diagnosis    => 0  # default off
		  );
    &importOptions(\%options, $hash, $debug);

# start by defining session, password, identify

    undef my $cgi; undef my $session; undef my $password; undef my $identify;

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
        $session  = $options{session} || $self->{SESSION};
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

print "GateKeeper authorize: $identify $password session $session \n" if $debug;

    my $mother = $self->{mother};

    undef my $privileges; 
    undef my $seniority; 
    undef my $attributes;

    undef $self->{report};
    if ($session && $options{testSession}) {
# a session  number is defined
        $self->{report} = "Check existing session number $session";
        my $sessions = $mother->spawn('SESSIONS','self',0,1); # 0,0 later ?
        if ($self->{error} = $sessions->{errors}) {
            &dropDead($self,$sessions->{errors}) if $options{dieOnError};
	    return 0;
        }
# before testing the session number itself, we check the implied username 
       ($identify, my $code) = split ':',substr($session,0,-2);
        my $users = $mother->spawn('USERS','self',0,1);
        if (my $hashref = $users->associate('hashref',$identify,'userid')) {
            $privileges = $hashref->{privilegea} || 0;
            $seniority  = $hashref->{seniority}  || 0;
            $attributes = $users->unpackAttributes($identify,'userid');
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
# test the SESSIONS of each server in turn
                if ($instance ne $this_host) {
                    my %uoptions = (defaultInstall => 0, writeAccess => 0);
                    if (my $dbh = &opendb_MySQL_unchecked ($self,$instance,\%uoptions)) {
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

print "GateKeeper authorize 1 report $self->{report} \n" if $debug;

    if (!$session || !$options{testSession}) {
# test if a user identification and password are provided
        my $users = $mother->spawn('USERS','self',0,1);
        if (!$password || !$identify) {
# add request for username and  password; abort in non-CGI mode
            if (!$self->cgiHandle(1) && $options{noprompt} > 1) {
                &dropDead($self,"Missing username or password");
            }
            elsif (!$self->cgiHandle(1) && $options{noprompt}) {
                $self->{error} = "Missing username or password";
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

print "GateKeeper authorize 2 report $self->{report} \n" if $debug;

# a username and password are provided: verify identification and issue session number

        undef $self->{error};
        $self->{seniority} = 0;
        if (!$self->instance || $users->{errors}) {
# there is no (valid) user information: default to privileged usernames and database password
            my $allowed = $self->{config}->get("devserver_access",'insist unique array');
            my $string  = join ' ',@$allowed;
            if (!$identify || !$password) {
                $self->{error} = "Missing username or database password";
            }
            elsif ($string !~ /\b$identify\b/) {
                $self->{error} = "User $identify has no database privileges on this server";
            }
            elsif ($password ne $self->{config}->get('mysql_password')) {
                $self->{error} = "Invalid database password provided for user $identify";
            }
            $privileges = $code; # forces acceptance
        }
        elsif (my $hash = $users->associate('hashref',$identify,'userid')) {
            $privileges = $hash->{privilegea} || 0;
            $seniority  = $hash->{seniority}  || 0;
            $attributes = $users->unpackAttributes($identify,'userid');
            $self->{seniority} = $seniority; # for use outside the GateKeeper
# superuser 'oper' has a special status; accounts defined on start-up have to be initialize by 'oper'
print "identify '$identify'  hash '$hash->{password}'  passwd '$password' \n" if $debug;
            if ($hash->{password} eq 'arcturus' && $identify eq 'oper') {
# there are two possible passwords allowed: either 'arcturus' (unencrypted after startup) or the database password
# print "passage 1 priv: $privileges<br>";
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
            elsif (!$privileges) {
                $self->{error} = "User $identify has no privileges set";
            }
print "passage 5  error $self->{error} \n" if $debug;
        }
        elsif (!($self->{error} = $users->{errors})) {
            $self->{error} = "Unknown user: $identify";
        }

print "GateKeeper authorize Test Error\n" if $debug;

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

# here privileges should be defined; test privilege(s) sought

    my $mask = $code;
    if (ref($code) eq 'HASH') {
        $mask = $code->{mask};
        $mask = 65535 if !defined($mask);
# test against data for another named user
        if (my $user = $code->{user}) {
            my $users = $mother->spawn('USERS','self',0,1);
            if ($user eq $identify && $code->{notOnSelf} && $seniority < 6) {
                $self->{error} = "You can't <do this to> yourself"; # note the place holder
                return 0;
            }
            elsif ($user eq $identify) {
                $mask = 0; # actions on myself need no further test 
            }   
# test the seniority of the user mentioned against the one of $identify
            elsif ($seniority < 6 && $seniority <= $users->associate('seniority',$user,'userid')) {
                $self->{error} = "User $identify has no privilege for this operation";
                $self->{error} .= ": insufficient seniority";
                return 0;
            }        
        }
# test seniority
        if ($code->{seniority} && $seniority < $code->{seniority}) {
            $self->{error} = "User $identify has no privilege for this operation: ";
            $self->{error} .= "insufficient seniority ($code->{seniority} required)";
            return 0;
        }
    }

# does the user have (write) access to this database/table?

    if (ref($attributes) eq 'HASH') {
# if database mentioned, access is restricted to these
        my $database = $self->{database} || 'arcturus';
        if ($attributes->{databases} && $attributes->{databases} !~ /\b$database\b/) {
            $self->{error} = "User $identify has no access privilege for $database";
            return 0;
        }
# if tables are mentioned, set-up the $self->{taccess} parameter for processing elsewhere
        $self->{taccess} = $attributes->{tablename};
# test for specific table access
        if (my $tables = $options{allowTable}) {
            my @tables; $tables[0] = $tables;
            $tables = \@tables if (ref($tables) ne 'ARRAY');
            foreach my $table (@$tables) {
                if (!$self->allowTableAccesss($table)) {
                    $self->{error} .= "User $identify has no access privilege for ";
                    $self->{error} .= "database table $table\n";
	        }
            }
            return 0 if $self->{error};
        }
    }

# test if the required privilege matches the 

    if ($mask) {
# &report ($self,"code $code  mask $mask privileges $privileges");
        if (!$privileges || $mask != ($mask & $privileges)) {
            $self->{error} = "User $identify has insufficient privileges for this operation";
	    $self->{error} .= "(pr: $privileges mask $mask)";
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
            $self->{error} = "User '$user' has no privileges on the development servers";
            return 0;
        }
    }

    return 1; # authorization granted
}

#############################################################################

sub allowDatabaseAccess {
# test the available status of the database
    my $self  = shift;
    my $abort = shift;

    if ($self->{available} ne "on-line") {
        $self->{error} .= "Database $self->{database} is inaccessible ";
        $self->{error} .= "because of access status: $self->{available}";
        $self->dropDead($self->{error}) if $abort;
        return 0;
    }
    return 1;
}

#############################################################################

sub allowTableAccess {
# authorize access for a specific table
    my $self  = shift;
    my $table = shift;
    my $abort = shift || 0;

# if you want to protect a table, put a call to this method just before accessing it

    return 0 if !$self->allowDatabaseAccess($abort);
 
# STD standard access to all tables except TAGS and HISTORY
# ALL for all tables in database except HISTORY and GENE2CONTIG
# USERS and ORGANISMS or COMMON for all tables
# (current version rather crude)

    my $allowed = $self->{taccess} || 'ALL'; # defaults to be changed later 
#print "GateKeeper allowTableAccess $table  allowed $self->{taccess} $allowed \n\n";

    my $access = 1;
#    $access = 0 if ($table =~ /GENE2CONTIG/i && $allowed !~ /\bGENE2CONTIG\b/); # ??
    $access = 0 if ($allowed !~ /ALL/i && $allowed !~ /\b$table\b/i);
    
    my $user = $self->{USER} || 'unidentified';
    $self->{error} .= "User '$user' has no access to table $table\n" if !$access;
    $self->dropDead($self->{error}) if (!$access && $abort);

    return $access;  
}

#############################################################################

sub newSessionNumber {
    my $self = shift;
    my $user = shift;

    my $seed = &compoundName($user,'arcturus',8);
    my $encrypt = $self->{cgi}->ShortEncrypt($seed,$user);
    $encrypt .= sprintf("%02d",int(rand(99.99)));
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
    my $origin  = shift; # set true for closing the original session in the file

print "not yet implemented<br>" if $origin;
return if $origin; # temporary stop pending further development

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

    my $session = $self->currentSession;
    if ($session && !$self->{USER}) {
        my @session = split ':',$session;
        $self->{USER} = $session[0];
    }

# open the page

    $self->cgiHeader(2); # in case not yet done
    my $page = $cgi->openPage("ARCTURUS $title");
#  if noGUI specified, default to central page with blank borders 
    if ($self->lookup('noGUI',0)) {
        $page->frameborder();
        return $page;
    }

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
#            $server =~ s/pcs3/pcs3.internal.sanger.ac.uk/; # temporary fix 
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

# $self->cgiHeader(2); # in case not yet done
# my $page = $cgi->openPage("ARCTURUS $title");
    my $width  = 60;
    my $height = 50;
    $page->arcturusGUI($height,$width,$yell);
    my $smail = $config->get('signature_mail');
    my $sname = $config->get('signature_name');
    $page->address($smail,$sname,0,12);
# substitute values for standard place holders
    my $href = "href=\"/Arcturus.html\"";
    my $capt = "onMouseOver=\"window.status='About Arcturus'; return true\"";
    my $imageformat = "width=\"$width\" height=\"$height\" vspace=1";
    $page->{layout} =~ s/ARCTURUSLOGO/<A $href $capt><IMG SRC="\/icons\/bootes.jpg" $imageformat><\/A>/;
    $page->{layout} =~ s/SANGERLOGO/<IMG SRC="\/icons\/helix.gif" $imageformat>/;

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
    push @exclude, 'dbasename';
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
        $table .= "<tr><th colspan=2 bgcolor='$purp' width=100%> SERVERS </th></tr>";
        my @aliases = ('WATSON','CRICK','VENUS','MARS','PLUTO','CHARON','LUNA','TIC'); my $demo =1;
        foreach my $i (0 .. $#alternates) {
            my $server = $alternates[$i];
            my @url = split /\:|\./,$server; $url[0] = uc($url[0]);
            my $type = uc($altertypes{$server}); $type =~ s/^(\w)\w*$/$1/;
            my %s = (D => 'DEVELOPMENT', P => 'PRODUCTION' , C => 'CURRENT');
            my $link = "$url[0]"; $link = $aliases[$i] if $demo;
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
#push @databases,'TEST1','Test2';
    my $column = 1; $column = 2 if (@databases > 7);
    $table .= "<tr><th bgcolor='$purp' colspan=$column width=100%> DATABASE </th>";
    if (@databases) {
        my $current = $cgi->parameter('database',0);
        @databases = sort @databases;
        for (my $i = 0 ; $i < @databases ; $i++) {
#        foreach my $database (@databases) {
            my $database = $databases[$i];
            $table .= "</tr><tr>" if !($i%($column));
            my $target = $script;
            $target =~ s/(database|organism|dbasename)\=\w+/$1=$database/;
            $target .= "\&database=$database" if ($target !~ /\b$database\b/);
      	    $target =~ s/\&/?/ if ($target !~ /\?/); # replace first & by ?
            my $link = $database; my $ulink = uc($link);
            $link = "<font size=-1>$link</font>" if ($column == 2);
            my $alt = "onMouseOver=\"window.status='SELECT THE $ulink DATABASE'; return true\"";
            my $override = 0; $override = 1 if ($self->currentScript =~ /\bcreate\b|drop\b|copy\b/); 
            $link = "<a href=\"$target\" $alt> $link </a>" if (!$current || $current ne $link || $override);
            $table .= "<td $cell width=100%>$link</td>";
        }
        $table .= "</tr>";
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
    $table .= "<tr><th bgcolor='$purp' width=100%> ASSIGN </th></tr>";
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
    $page->space(3-@databases); 
    $page->space(1);   
# and the TEST menu on the same partion
    $page->partition(6);
    $table = "<table $tablelayout>";
    $table .= "<tr><th bgcolor='$purp' width=100%> UPDATE </th></tr>";
    $connection = &whereAmI($self); $connection =~ s/database on.*/SERVER/i;
    $title = "HARMONISE THE CONTENTS OF THE COMMON DATABASES ON THE ".uc($connection);
    $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
    my $update = "/cgi-bin/emanager/harmonize/getform".$cgi->postToGet(1,'session');
    $table .= "<tr><td $cell><a href=\"$update\" $alt> Harmonize </a></td></tr>";
    if ($database && $database ne 'arcturus') {
        $title = "UPDATE PAIRS IN THE ".uc($database)." DATABASE";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $update = "/cgi-bin/emanager/pairstest".$cgi->postToGet(1,@include); # other URL
        $table .= "<tr><td $cell><a href=\"$update\" $alt> Pairs </a></td></tr>";

        $title = "CHANGE DESCRIPTIONS OF ".uc($database)." OR ITS ASSEMBLIES, PROJECTS OR VECTORS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $update = "/cgi-bin/emanager/editor/editmenu".$cgi->postToGet(1,@include); # other URL
        $table .= "<tr><td $cell><a href=\"$update\" $alt> Edits </a></td></tr>";

        $title = "UPDATE OF ".uc($database)." OR ITS ASSEMBLY";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $update = "/cgi-bin/emanager/editor/assembly".$cgi->postToGet(1,@include); # other URL
        $table .= "<tr><td $cell><a href=\"$update\" $alt> Assembly </a></td></tr>";
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
        $target = "target='workframe'";
        $title = "LOAD TAG INFORMATION FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $input = "/cgi-bin/create/existing/process".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$input\&tablename=STSTAGS\" $alt $target> TAGS </a></td></tr>";
        $title = "LOAD MAPPING INFORMATION FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$input\&tablename=CLONEMAP\" $alt $target> Clone MAP </a></td></tr>";
        $title = "LOAD HAPPY MAP INFORMATION FOR ".uc($database);
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$input\&tablename=HAPPYMAP\" $alt $target> Happy MAP </a></td></tr>";
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
        $title = "TEST AND MODIFY TABLES OF THE ".uc($database)." ORGANISM DATABASE";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $update = "/cgi-bin/create/existing/getform".$cgi->postToGet(1,@include);
        $table .= "<tr><td $cell><a href=\"$update\" $alt> $database </a></td></tr>";
#        $update = "/cgi-bin/amanager/modify/assembly".$cgi->postToGet(1,@include); # other URL
#        $table .= "<tr><td $cell><a href=\"$update\" target='workframe'> Assembly </a></td></tr>";
#        $update = "/cgi-bin/pmanager/modify/project".$cgi->postToGet(1,@include);  # other URL
#        $table .= "<tr><td $cell><a href=\"$update\" target='workframe'> Project </a></td></tr>";
    }
    if ($self->instance) {
        $update = "/cgi-bin/create/arebuild".$cgi->postToGet(1,'session');
        $title = "TEST AND MODIFY TABLES OF THE COMMON DATABASE";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$update\" $alt> arcturus </a></td></tr>";
        $update = "/cgi-bin/umanager/getmenu".$cgi->postToGet(1,'session');
        $title = "USER ADMINISTRATION OPERATIONS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$update\" $alt> Users </a></td></tr>";
    }
    if ($database && $database ne 'arcturus' && $self->currentUser eq 'oper') {
# copy database link
        $update = "/cgi-bin/new/newcopy/getform".$cgi->postToGet(1,'session','database');
        $update .= "\&noGUI=1"; # must have no possible links to other databases  
        $title = "COPY THE $database database to another node";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$update\" target='workframe' $alt>";
        $table .= "<font size=-1> COPY $database </font></a></td></tr>";
# drop database link
        $update = "/cgi-bin/drop/process".$cgi->postToGet(1,'session','database');
        $update .= "\&noGUI=1"; # must have no possible links to other databases  
        $title = "DROP THE $database database";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        $table .= "<tr><td $cell><a href=\"$update\" $alt><font size=-1> DROP $database </font></a></td></tr>";
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
        $query .= "\&session=$session" if ($session =~ /\boper\b/);
        $table .= "<tr><td $cell><a href=\"$query\" $alt $querywindow>$database</a></td></tr>";
    }
    if ($self->instance) {
        $title = "COMMON DATABASE CONTENTS";
        $alt = "onMouseOver=\"window.status='$title'; return true\""; 
        my $query = "/cgi-bin/query/overview?database=arcturus";
        $query .= "\&session=$session" if ($session =~ /\boper|ejz\b/);
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

#    $page->add($self->{open});

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
# return the cgi server host
    my $self = shift;

    my @hostinfo = split /\.|\:/,$self->{server};

    return $hostinfo[0];
}

#*******************************************************************************

sub currentServer {
# return the cgi server name
    my $self = shift;

    return $self->{server}; # the internal name used for the server URL
}
 
#*******************************************************************************

sub currentPort {
# return the cgi server port number
    my $self = shift;

# print "\ncurrentPort server: $self->{server}\n";
    my @hostinfo = split /\.|\:/,$self->{server};

#    return $hostinfo[$#hostinfo];
    return $self->currentCgiPort;
}

#*******************************************************************************

sub currentCgiPort {
# return the cgi server port number
    my $self = shift;

    my $cgiPort = 0;
    if ($self->cgiHandle(1) && $self->{server} =~ /\:/) {
        my @hostinfo = split /\.|\:/,$self->{server};
        $cgiPort = $hostinfo[$#hostinfo];
    }
    
    return $cgiPort; 
}

#*******************************************************************************

sub currentDbPort {
# return the database port number
    my $self = shift;

    return $self->{TCPort} || '';
}

#*******************************************************************************

sub currentResidence {
# return the arcturus residence (host:dbport:cgiport)
    my $self = shift;

    my $residence = $self->currentHost;
    $residence .= ':'.$self->currentDbPort;
    $residence .= ':'.$self->currentCgiPort if $self->currentCgiPort;

    return $residence;
}
#*******************************************************************************

sub getMySQLports {
# return a list of all MySQL instances (host:port combinations)
    my $self = shift;
    my $same = shift; # set true if the current host:port is to be included

    my @ports;
    if (my $config = $self->{config}) {

        my $ports = $config->get("mysql_ports",'insist unique array');

        foreach my $port (sort @$ports) {
            my ($h,$p) = split ':',$port;
            next if (!$same && $h eq $self->currentHost && $p eq $self->currentDbPort);
            push @ports, $port;
        }
    }
    return \@ports;
}

#*******************************************************************************

sub findInstance {
# return the full specification of an arcturus instance, give partial info
    my $self = shift;
    my $info = shift;

    my @servers;
    my $pservers = $self->lookup("mysql_prod",'insist unique array');
    push @servers, @$pservers; 
    my $dservers = $self->lookup("mysql_dev" ,'insist unique array');
    push @servers, @$dservers; 
    my $tservers = $self->lookup("mysql_test",'insist unique array');
    push @servers, @$tservers;

    undef my $result;
    $info =~ s/\:/\\b.+\\b/g; # pattern to match
    foreach my $server (@servers) {
        $result = 0       if ( defined($result) && $server =~ /$info/);
        $result = $server if (!defined($result) && $server =~ /$info/);
    }
# returns the full instance specification or 0 for double matches or undef if not found
    return $result;
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

    $self->{cgi}->flush if $self->{cgi}; # flush any existing output page

    exit 0;
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

#*******************************************************************************

sub list {
# list elements of the $self hash
    my $self = shift;

    $self->report("GateKeeper $self status");

    foreach my $key (keys %$self) {
        $self->{$key} = "UNDEFINED" if !defined($self->{$key});
        $self->report("$key = $self->{$key}");
    }

    $self->report("End List");
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
#    delete $ENV{GATEWAY_INTERFACE};
    delete $ENV{PATH_INFO};

    return $csroot;
}

#############################################################################

sub DESTROY {
# force disconnect and close session, if not done previously
    my $self = shift;

# full close down (if the database handle still exists at this point)

    $self->disconnect(0,1);
}

#****************************************************************************

sub disconnect {
# disconnect with message
    my $self = shift;
    my $text = shift;
    my $full = shift || 0;

    &report($self,$text) if $text;

    $self->ping || return; # already disconnected

# controlled close down

    $self->shutdown if $full;

    $self->{handle}->disconnect if $self->{handle};
}

#*******************************************************************************

sub shutdown {
# full shutdown of all open tables
    my $self = shift;

    my $mother = $self->{mother} || return;

    my $userid  = $self->{USER}  || 'oper';
    my $session = $self->{SESSION};

# close current session 

    $self->closeSession($session) if $session;

    $mother->historyUpdate($userid);

    delete $self->{mother};
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>              81 ,
        version =>             1.0 ,
        updated =>    "23 Sep 2003",
        date    =>    "26 Jun 2002",
    };
}

#############################################################################

1;
