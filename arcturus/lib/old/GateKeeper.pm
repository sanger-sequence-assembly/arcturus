package GateKeeper;

use strict;

use DBI;
use CGI qw(:standard);
#use MyCGI;
use NewHTML;
use ArcturusTable;
use ConfigReader;

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

    bless ($self, $class);

# open and parse the configuration file

    &configure(0,$self);

# open the CGI input handler if in CGI mode

    &cginput(0,$self,$usecgi);

# open the database

    &opendb_MySQL(0,$self,$eraise) if ($engine && $engine =~ /^mysql$/i);

#    &opendb_Oracle(0,$self,$eraise) if ($engine && $engine =~ /^oracle$/i); # or similar later

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

#    $self->{cgi} = MyCGI->new(0);
    $self->{cgi} = NewHTML->new(0);

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
    $cgi = 0 if ($test && $cgi && !$cgi->{status});

    return $cgi;
}

#*******************************************************************************

sub cgiHeader {
    my $self = shift;
    my $type = shift; # 1 for plain, 2 for html, else nothing

    $self->{cgi}->PrintHeader(1) if ($self->{cgi} && $type == 1);
    $self->{cgi}->PrintHeader(0) if ($self->{cgi} && $type == 2);
}

#*******************************************************************************

sub origin {

    undef my $origin;
    if ($ENV{'GATEWAY_INTERFACE'}) {
        $origin = $ENV{'PATH_INFO'} || ' ';
    }

# either path_info or blank (under CGI, both 'true') OR undef (not CGI, 'false')

    return $origin;
}

#*******************************************************************************
# open the MySQL database on the current host
#*******************************************************************************

sub ping_MySQL {
# test if the required database is alive
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
# open mysql directly with any checks
    my $self = shift;
    my $host = shift; # hostname:TCPport
    my $look = shift;

# test against default server, if $look; else open a new connection

    if ($look && $self->{handle}) {
        &dropDead($self,"Missing TCP port specification in host $host") if ($host !~ /\:/);
        my ($name,$port) = split ':',$host;
        return $self->{handle} if ($self->{server} =~ /$name/ && $self->{TCPort} == $port);
    }

# build the data source name

    my $dsn = "DBI:mysql:arcturus:host=$host";

# get authorization

    my $config = $self->{config};

    my $username  = $config->get("mysql_username",'insist');
    my $password  = $config->get("mysql_password",'insist');
# test configuration data input status
    my $status    = $config->probe(1);
    &dropDead($self,"Missing or Invalid information on configuration file:\n$status") if $status;

# and open up the connection

    my $handle = DBI->connect($dsn, $username, $password, {RaiseError => 1}) 
    or &dropDead($self,"Failed to access arcturus on host $host ($DBI::errstr)");           

# okay, here the database has been properly opened on host/port $self->{server};

    return $handle;
}

#*******************************************************************************

sub opendb_MySQL {
# create database handle on the current server and port
    my $lock   = shift;
    my $self   = shift;
    my $eraise = shift;

    &dropDead($self,"You're not supposed to access this method") if $lock;

    undef $self->{server};
    undef $self->{handle};

# we now test if the specified database is installed on the current CGI server

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
                foreach my $combination (@$port_maps) {
                    my ($script, $tcp, $cgi) = split /\:/,$combination;
	            if ($tcp eq $ENV{MYSQL_TCP_PORT} && $scriptname =~ /^.*\b($script)\b.*$/) {
# MySQL port and script directory verified; finally test the cgi port (if any)
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
                              or &dropDead($self,"Failed to access $db_name: $DBI::errstr");           
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

    $self->{mother} = new ArcturusTable($self->{handle},'ORGANISMS','arcturus',1);
    if ($self->{mother}->{errors}) {
        &dropDead($self,"Failed to access table ORGANISMS on $self->{server}");
    }
#$self->cgiHeader(1); print "master table opened: $self->{mother}";
}

#*******************************************************************************

sub whereAmI {
# return a string with information about the instance accessed
    my $self = shift;
    my $full = shift;

    my $server = $self->{server};
    my $script = $self->{Script};

    my $text;
    if (!$server || !$script) {
        $text  = "don't know where I am:";
        $text .= " undefined server " if !$server;
        $text .= " undefined script " if !$script;
    }
    elsif ($full) {
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
    my $options  = shift; # hash 

    my $override = 0; # default do not allow undefined database
    my $redirect = 1; # default allow redirection to new URL
    my $dbhandle = 1; # default return database handle
    if (ref($options) eq 'HASH') {
        $override = $options->{'override'} if defined($options->{'override'}); 
        $redirect = $options->{'redirect'} if defined($options->{'redirect'}); 
        $dbhandle = $options->{'dbhandle'} if defined($options->{'dbhandle'}); 
    }

    my $dbh = $self->{handle}; # may be replace below
    &dropDead($self,"No database handle available") if !$dbh;
    my $server = $self->{server};

    my $organisms = $self->{mother};
    &dropDead($self,"Inaccessible table 'ORGANISMS' on $server") if !$organisms;
    $dbh = $organisms if !$dbhandle;

# if database specified as arcturus, just return the database handle

    if ($database && $database eq 'arcturus') {
        $self->{database} = 'arcturus';
        return $dbh;
    }
    elsif (!$database) { 
        &dropDead($self,"Undefined database name") if !$override;
        $self->{database} = 'arcturus';
        return $dbh;
    }

# test if the requested organism database is available on this server; open ORGANISMS

    undef my %residence;
    undef my %available;

    if (my $hashrefs  = $organisms->associate('hashrefs')) {
        foreach my $hash (@$hashrefs) {
#print "$hash $hash->{dbasename} $hash->{residence} $hash->{available}\n";
# TEMPORARY fix:this line is added because the pcs3 cluster is not visible as pcs3.sanger.ac.uk but as pcs3 only
            $hash->{residence} =~ s/pcs3\.sanger\.ac\.uk/pcs3/;
            $residence{$hash->{dbasename}} = $hash->{residence};
            $available{$hash->{dbasename}} = $hash->{available};
        }
    }
    else {
        &dropDead($self,"Empty table 'ORGANISMS' on $server");
    }

# if database undefined, try cgi input

    my $cgi = $self->{cgi};
    $database = $cgi->parameter('database') if ($cgi && !$database && !$override);
    $database = $cgi->parameter('organism') if ($cgi && !$database && !$override);

# see if the arcturus database is on this server, else redirect

    undef $self->{database};
    if ($database && !$residence{$database}) {
        &dropDead($self,"Unknown arcturus database $database at server $server");
    } 
    elsif ($database && $residence{$database} ne $server) {
        $redirect = 1 if !defined($redirect);
        if (!&origin || !$redirect) { # (command-line mode)
            &dropDead($self,"Database $database resides on $residence{$database}");
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
    $options->{dbhandle} = 0;

    return $self->dbHandle($database,$options);
}

#*******************************************************************************

sub focus {
    my $self = shift;
    my $fail = shift;

    if ((my $mother = $self->{mother}) && $self->{database}) {
        $mother->query("use $self->{database}");
    }
    elsif ($fail) {
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

# start by defining session, password, identify

    undef my ($cgi, $session, $password, $identify);

    if ($cgi = $self->{cgi}) {
# any of these parameters may be absent from cgi input
        $session  = $cgi->parameter('session',0) || 0;
        $password = $cgi->parameter('password',0);
        $cgi->transpose('password') if $password; # remove from CGI input
        $identify = $cgi->parameter('identify',0);
        $cgi->transpose('identify','USER') if $identify; # remove identify from CGI input
    }

# process possible hash input 

    my %options = ( nosession  => 0, # default test/generate session number
                    interim    => 1, # default submit interim form if CGI and no output page active
                    finalize   => 0, # default return after adding password query to existing form
                    noprompt   => 1, # default no prompt for username and/or password if missing & !CGI 
                    silently   => 1, # do everything quietly
                    dieOnError => 0, # do not abort on error but return error message
                    ageWindow => 30, # acceptance window (minutes) for previously opened session
		  );

    if (ref($hash) eq 'HASH') {
        foreach my $key (keys %$hash) {
            $options{$key} = $hash->{$key};
#  eval "\$$key = $hash->{$key}";
        }
    }

    my $mother = $self->{mother};
    undef my ($priviledges,$seniority);

    undef $self->{report};
    if ($session && !$options{nosession}) {
# in CGI mode and a session  number is defined
        $self->{report} = "Check existing sessions number $session";
        my $sessions = $mother->spawn('SESSIONS','self',0,1);
        if ($self->{error} = $sessions->{errors}) {
            &dropDead($self,$sessions->{errors}) if $options{dieOnError};
	    return 0;
        }
# test if session for this user still open; if not, force new request for password and username
        if (my $hashref = $sessions->associate('hashref',$session,'session')) {
            if ($hashref->{timeclose}) {
                $self->{report} .= "Arcturus session $session is already closed";
                $session = 0; # force prompt for password 
	    }
            else {
                ($identify, my $code) = split ':',$session;
                $sessions->counter('session',$session,1,'access');
                my $users = $mother->spawn('USERS','self',0,1);
                if ($hashref = $users->associate('hashref',$identify,'userid')) {
                    $priviledges = $hashref->{priviledges} || 0;
                    if (!$cgi->VerifyEncrypt('arcturus',$code)) { # final check integrity 
                        $self->{report} .= "! Corrupted session number $session";
                        $session = 0;
                    }
                }
                else {
                    $self->{report} .= "! User $identify does not exist";
                    $session = 0;
                }
	    }
        }
# there is no such session number (? corrupted input)
        else {
            $self->{report} .= "! Specified Arcturus session $session does not exist";
            $session = 0; # force prompt for password
        }
        &report($self,$self->{report}) if !$options{silently};
        undef $self->{report};
    }

    if (!$session || $options{nosession}) {
# test if a user identification and password are provided
        if (!$password || !$identify) {
# add request for username and  password; abort in non-CGI mode
            if (!$self->cgiHandle(1) && $options{noprompt}) {
                &dropDead($self,"Missing username or password");
            }
            elsif (!$self->cgiHandle(1)) {
# issue a prompt for password info on the command line
     &report($self,"Prompt for user name and password from STDIN (to be developed)");

	    }
# if interim set or no page exists pop up an intermediate authorisation form
            elsif ($options{interim} || !$cgi->pageExists) {
                $self->cgiHeader(2); # if not already done
                my $script = $self->{Script};
                $script =~ s?^.*cgi-bin?/cgi-bin?;
                $cgi->openPage("ARCTURUS authorisation");
                $cgi->frameborder(100,20,'white',20);
                $cgi->center(1);
                $cgi->form($script); # return to same url
                $cgi->sectionheader("ARCTURUS authorisation",3,1);
                $cgi->sectionheader("The requested ARCTURUS operation requires authorisation",4,0);
                $cgi->sectionheader("Please provide your User Identification and Password",4,0);
                $cgi->identify('10',8,1);
                $cgi->submitbuttonbar(1,0);
                $cgi->ingestCGI();
                $cgi->form(0); # end form
                $cgi->flush;
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
        my $users = $mother->spawn('USERS','self',0,1);
        if (my $hash = $users->associate('hashref',$identify,'userid')) {
            $priviledges = $hash->{priviledges};
            $seniority   = $hash->{seniority};
            if (!$cgi->VerifyEncrypt($password,$hash->{password})) {
                $self->{error} = "Invalid password provided for user $identify";
            }
            elsif (!$priviledges) {
                $self->{error} = "User $identify has no priviledges set";
            }
        }
        elsif (!($self->{error} = $users->{errors})) {
            $self->{error} = "Unknown user: $identify";
        }

        &dropDead($self,$self->{error}) if ($self->{error} && ($options{dieOnError} || !$self->cgiHandle(1)));
        return 0 if $self->{error};

# okay, here the user has been identified: if CGI, issue a session number 

        if ($self->cgiHandle(1) && !$options{nosession}) {
            $session = 0;
            my $sessions = $mother->spawn('SESSIONS','self',1);
            if ($sessions->{errors}) {
                &dropDead($self,$sessions->{error}) if $options{dieOnError};
	        return $sessions->{errors};
            }
# test if a previous session for this user is still open; if so, how old is it?
            my $query = "select session, timebegin, UNIX_TIMESTAMP(NOW())-";
            $query .= "UNIX_TIMESTAMP(timebegin) AS age from <self> where ";
            $query .= "session like '$identify%' AND closed_by is NULL";
            my $array = $sessions->query($query,0,0);
            if ($array && ref($array) eq 'ARRAY') {
                my $ageOfSession = $array->[0]->{age};
                my $openSession = $array->[0]->{session};
                $self->{report} = "There is an existing active session $openSession"; 
                if (defined($ageOfSession) && $ageOfSession/60 <= $options{ageWindow}) {
                    $self->{report} .= "Previous session $openSession will be continued";
                    $sessions->counter('session',$openSession,1,'access'); # update access counter
                    $session = $openSession;
                }
                elsif (defined($openSession)) {
                    $self->{report} .= "Previous session $openSession will be closed";
                    $sessions->signature(0,'session',$openSession,0,'timeclose');
                    $sessions->update('closed_by','oper','session',$openSession);
                }
                else {
                    $self->{report} .= "Possibly corrupted SESSIONS table: inconsistent data for $identify";
                }
            }

# open a new session number if no one defined

            my $attempt = 5;
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
                $cgi->replace('session',$session); # add to CGI buffer
            }
            else {
                $self->{report} .= "! Failed to issue an new session number after 5 tries";
	    }
        }    
    }

    &report($self,$self->{report}) if !$options{silently};
    undef $self->{report};

# here priviledges should be defined; test priviledge(s) sought
    
    print "priviledges for user $identify: $priviledges\n";

    my $mask = $code;
    if (ref($code) eq 'HASH') {
        $mask = $code->{mask};
        if (my $user = $code->{user}) {
# test the seniority of the user mentioned against the one of $identify
            my $users = $mother->spawn('USERS','self',0,1);
            if ($seniority <= $users->associate('seniority',$user,'userid')) {
                $self->{error} = "User $identify has no priviledge for this operation";
                return 0;
            }        
        }
    }

    if ($code && $priviledges) {
# &report ($self,"code $code  mask $mask priviledges $priviledges");
        if ($mask != ($mask & $priviledges)) {
            $self->{error} = "User $identify has no priviledge for this operation";
            return 0;
        }
    }

    return 1; # user authorized
}

#############################################################################

sub newSessionNumber {
    my $self = shift;
    my $user = shift;

    my $encrypt = $self->{cgi}->ShortEncrypt('arcturus',$user);
    my $session = "$user:$encrypt"; # name folowed by some 'random' sequence

    return $session;
}

#*******************************************************************************
# error processing and reporting
#*******************************************************************************

sub dropDead {
# disconnect and abort with message
    my $self = shift;
    my $text = shift;

    if ($text) {
        $self->disconnect("! $text");
    }
    else {
        $self->disconnect();
    }

# my $output = $self->{cgi}->PrintVariables;
# &report($self,"$output");

    exit 0;
}

#*******************************************************************************

sub disconnect {
# disconnect with message
    my $self = shift;
    my $text = shift;

    &report($self,$text) if $text;

# ? should be more extensive on which handle to be closed! main or additional ones
    $self->{handle}->disconnect if $self->{handle};
}

#*******************************************************************************

sub report {
# print message with check check on return header status 
    my $self = shift;
    my $text = shift;

    my $tag = "\n";
    if ($self->{cgi} && $self->{cgi}->{status}) {
        $self->{cgi}->PrintHeader(1) if !$self->{cgi}->{'header'}; # plain text
        $tag = "<br>" if ($self->{cgi}->{'header'} == 1);
        $text =~ s/\\n/$tag/g if $text;
    }
    print STDOUT "$tag$text$tag\n" if $text;
}

#############################################################################

sub environment {
    my $self = shift;

    my $text = "Environment variables: \n";

    foreach my $key (keys %ENV) {
        $text .= "key $key  = $ENV{$key}\n";
    }

    &report($self,$text);
}

#############################################################################
#############################################################################

sub colophon {
    return colophon => {
        author  => "E J Zuiderwijk",
        id      =>            "ejz",
        group   =>              81 ,
        version =>             1.0 ,
        updated =>    "08 Apr 2002",
        date    =>    "21 Apr 2002",
    };
}

1;











