#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase::ADBRead;

use CAFReadFactory;
use OracleReadFactory;
use ExpFileReadFactory;

use FileHandle;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;
my $assembly;

my $source; # name of factory type

my $noexclude = 0; # re: suppresses chack against already loaded reads
my $noloading = 0; # re: test mode without read loading

my $skipaspedcheck = 0;

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $validKeys  = "organism|instance|assembly|caf|cafdefault|fofn|out|";
   $validKeys .= "limit|filter|source|exclude|info|help|asped|";
   $validKeys .= "readnames|include|filter|readnamelike|rootdir|";
   $validKeys .= "subdir|verbose|schema|projid|aspedafter|aspedbefore|";
   $validKeys .= "minreadid|maxreadid|skipaspedcheck|noload|noexclude";

my %PARS;

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage(0,"Invalid keyword '$nextword'");
    }

    $instance         = shift @ARGV  if ($nextword eq '-instance');

    $organism         = shift @ARGV  if ($nextword eq '-organism');

    $assembly         = shift @ARGV  if ($nextword eq '-assembly');

    $source           = shift @ARGV  if ($nextword eq '-source');

# exclude defines if reads already loaded are to be ignored (default = Y) 

    $noexclude        = 1            if ($nextword eq '-noexclude');

    $noloading        = 1            if ($nextword eq '-noload');

# Do not check Read objects for the presence of an Asped date. This allows
# us to load external reads, which lack this information.

    $skipaspedcheck   = 1 if ($nextword eq '-skipaspedcheck');

# logging

    $outputFile       = shift @ARGV  if ($nextword eq '-out');

    $logLevel         = 0            if ($nextword eq '-verbose');
 
    $logLevel         = 2            if ($nextword eq '-info'); 

# source specific entries are imported in a hash

    $PARS{caf}          = shift @ARGV  if ($nextword eq '-caf');
    $PARS{caf}          = 'default'    if ($nextword eq '-cafdefault');

    $PARS{include}      = shift @ARGV  if ($nextword eq '-fofn');
    $PARS{include}      = shift @ARGV  if ($nextword eq '-readnames');
    $PARS{include}      = shift @ARGV  if ($nextword eq '-include');

    $PARS{aspedafter}   = shift @ARGV  if ($nextword eq '-aspedafter');
    $PARS{aspedbefore}  = shift @ARGV  if ($nextword eq '-aspedbefore');

    $PARS{schema}       = shift @ARGV  if ($nextword eq '-schema');
    $PARS{projid}       = shift @ARGV  if ($nextword eq '-projid');

    $PARS{readnamelike} = shift @ARGV  if ($nextword eq '-filter');
    $PARS{readnamelike} = shift @ARGV  if ($nextword eq '-readnamelike');

    $PARS{minreadid}    = shift @ARGV  if ($nextword eq '-minreadid');
    $PARS{maxreadid}    = shift @ARGV  if ($nextword eq '-maxreadid');

    $PARS{root}         = shift @ARGV  if ($nextword eq '-rootdir');
    $PARS{subdir}       = shift @ARGV  if ($nextword eq '-subdir');
    $PARS{limit}        = shift @ARGV  if ($nextword eq '-limit');    

    &showUsage(0) if ($nextword eq '-help');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging($outputFile);

$logger->setFilter($logLevel) if defined $logLevel; # set reporting level

#----------------------------------------------------------------
# check the data source
#----------------------------------------------------------------

&showUsage(0,"Undefined data source") unless $source;

if ($source ne 'CAF' && $source ne 'Oracle' && $source ne 'Expfiles') {
    &showUsage(0,"Invalid data source '$source'");
}

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

$instance = 'prod' unless defined($instance);

&showUsage(0,"Missing organism database") unless $organism;

my $adb = new ADBRead (-instance => $instance,
		       -organism => $organism);

if ($adb->errorStatus()) {
# abort with error message
    &showUsage(0,"Invalid organism '$organism' on server '$instance'");
}
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

#----------------------------------------------------------------
# Populate the dictionaries and statement handles for loading reads
#----------------------------------------------------------------

$logger->info("building dictionaries");

$adb->populateLoadingDictionaries();

#----------------------------------------------------------------
# get an include list from a FOFN (replace name by array reference)
#----------------------------------------------------------------

$PARS{include} = &readNamesFromFile($PARS{include}) if $PARS{include};

#----------------------------------------------------------------
# if assembly not defined, use default assembly
#----------------------------------------------------------------

if (!$assembly) {
# to be completed: get info for a name from the assembly
# return an Assembly object from the database, which must have a default
# project name
# what if an assembly is defined? what if not?
}

#----------------------------------------------------------------
# ignore already loaded reads? then get them from the database
#----------------------------------------------------------------

if (!$noexclude) {

    $logger->info("Collecting existing readnames");

    $PARS{exclude} = $adb->getListOfReadNames; # array reference

    my $nr = scalar(@{$PARS{exclude}});

    $logger->info("$nr readnames found in database $organism");
}

#----------------------------------------------------------------
# Build the ReadFactory instance.
#----------------------------------------------------------------

my $factory;

if ($source eq 'CAF') {

# test CAF filename and open it

    &showUsage(1,"Missing CAF file name") unless $PARS{caf};

    if ($PARS{caf} eq 'default') {
# use the default assembly caf file in the assembly repository
        my $PR = new PathogenRepository();
        $PARS{caf} = $PR->getDefaultAssemblyCafFile($organism);
        $logger->info("Default CAF file used: $PARS{caf}") if $PARS{caf};
    }

    &showUsage(1,"File $PARS{caf} does not exist") unless (-e $PARS{caf});

    $PARS{caf} = new FileHandle($PARS{caf},"r"); # replace by file handle

    &showUsage(1,"Cannot access file $PARS{caf}") unless $PARS{caf};

# add logger to input PARS

    $PARS{log} = $logger;

# test for excess baggage; abort if present (force correct input)

    my @valid = ('caf','include','exclude','log');
    &showUsage(1) if &testForExcessInput(\%PARS,\@valid);

    $factory = new CAFReadFactory(%PARS);
}

elsif ($source eq 'Oracle') {

    &showUsage(2,"Missing Oracle schema") unless $PARS{schema};

    my @valid = ('schema','projid','aspedafter','aspedbefore',
		 'readnamelike','include','exclude','minreadid','maxreadid');

    &showUsage(2) if &testForExcessInput(\%PARS,\@valid);

    $factory = new OracleReadFactory(%PARS);
}

elsif ($source eq 'Expfiles') {
# takes the root directory and optionally a subdir filter
    if (!$PARS{root}) {
        $logger->info("Finding repository root directory");
        my $PR = new PathogenRepository();
        $PARS{root} = $PR->getAssemblyDirectory($organism);
        if ($PARS{root}) {
            $PARS{root} =~ s?/assembly??;
            $logger->info("Repository found at: $PARS{root}");
        }
        else {
            $logger->severe("Failed to determine root directory .. ");
        }
    }
    &showUsage(3,"No repository defined for $organism") unless $PARS{root};
# add logger to input PARS
    $PARS{log} = $logger;

    my @valid = ('readnamelike','root','subdir','limit','include','exclude','log');
    &showUsage(3) if &testForExcessInput(\%PARS,\@valid);

    $factory = new ExpFileReadFactory(%PARS);

    my $rejects = $factory->getRejectedFiles();
    print "REJECTED files: @$rejects\n\n" if $rejects;
}

&showUsage(0,"Unable to build a ReadFactory instance") unless $factory;

$factory->setLogging($logger);

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $processed = 0;

my $loadoptions = {};
$loadoptions->{skipaspedcheck} = 1 if $skipaspedcheck;

while (my $readname = $factory->getNextReadName()) {

    next if (!$noloading && $adb->hasRead($readname));

    my $read = $factory->getNextRead();

    next if !defined($read); # do error listing inside factory

    $logger->info("Storing $readname (".$read->getReadName.")");

    if ($noloading) {

        $read->writeToCaf(*STDOUT);

        next;
    }

    my ($success,$errmsg) = $adb->putRead($read, $loadoptions);

    $logger->severe("Unable to put read $readname: $errmsg") unless $success;

    $adb->putTraceArchiveIdentifierForRead($read) if $success;
}

$adb->disconnect();

$logger->close();

exit;

#------------------------------------------------------------------------
# test routine to signal excess or incomplete input
#------------------------------------------------------------------------

sub testForExcessInput {
    my $hash = shift;
    my $list = shift;

# check if each key in the hash is in the input list

    my $errors = 0;
    foreach my $key (keys %$hash) {
# test if the key is defined
        if (!defined($hash->{$key})) {
            $logger->warning("Undefined input key: $key");
            $hash->{$key} = 'UNDEFINED';
            $errors++;
        }
# identify the key in the list
        my $found = 0;
        foreach my $name (@$list) {
            $found = 1 if ($name eq $key);
        }
        next if $found;
        $logger->warning("Excess input: $key $hash->{$key}");
        $errors++;
    }
    return $errors;
}

#------------------------------------------------------------------------
# read a list of names from a file and return an array
#------------------------------------------------------------------------

sub readNamesFromFile {
    my $file = shift; # file name

    &showUsage(0,"File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage(0,"Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $mode = shift || 0; 
    my $code = shift || 0;

    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    print STDERR "MANDATORY PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-organism\tArcturus database name\n";
    print STDERR "-source\t\tEither 'CAF',' Oracle' or 'Expfiles'\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-instance\teither 'prod' (default) or 'dev'\n";
#    print STDERR "-assembly\tassembly name\n";
    print STDERR "-fofn\t\tfilename with list of readnames to be included\n";
    print STDERR "-include\t  idem\n";
    print STDERR "-filter\t\tprocess only those readnames matching pattern or substring\n";
    print STDERR "-readnamelike\t  idem\n";
    print STDERR "-noexclude\t(no value) override default exclusion of reads already loaded\n";
    print STDERR "-noload\t(no value) do not load the read(s) found (test mode)\n";    
    print STDERR "\n";
    print STDERR "-out\t\toutput file, default STDOUT\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "-verbose\t(no value)\n";
    print STDERR "\n";
    if ($mode == 0 || $mode == 1) {
	print STDERR "Source-specific parameters for CAF input:\n";
	print STDERR "\n";
	print STDERR "-caf\t\tcaf file name OR as alternative\n";
	print STDERR "-cafdefault\t use the default caf file name\n";
	print STDERR "\n";
    }
    if ($mode == 0 || $mode == 2) {
	print STDERR "Source-specific parameters for Oracle input:\n";
	print STDERR "\n";
	print STDERR "-schema\t(MANDATORY) Oracle schema\n";
	print STDERR "-projid\t(MANDATORY) Oracle project ID\n";
	print STDERR "-aspedbefore\tasped date guillotine\n";
	print STDERR "-aspedafter\tasped date guillotine\n";
	print STDERR "\n";
    }
    if ($mode == 0 || $mode == 3) {
	print STDERR "Source-specific parameters for Expfiles input:\n";
	print STDERR "\n";
	print STDERR "-root\t\troot directory of data repository\n";
	print STDERR "-sub\t\tsub-directory filter\n";
	print STDERR "-limit\t\tlargest number of reads to be loaded\n";
	print STDERR "\n";
    }

    $code ? exit(1) : exit(0);
}
