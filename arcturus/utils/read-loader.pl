#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use ReadFactory::CAFReadFactory;
use ReadFactory::OracleReadFactory;
use ReadFactory::ExpFileReadFactory;
use ReadFactory::TraceServerReadFactory;

use FileHandle;
use Logging;
use PathogenRepository;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my $instance;
my $organism;

my $source; # name of factory type

my $noexclude = 0;         # re: suppresses check against already loaded reads
my $noloading = 0;         # re: test mode without read loading

my $skipaspedcheck = 0;
my $skipqualityclipcheck = 0;
my $consensus_read = 0;
my $acceptlikeyeast = 0;

my $onlyloadtags;          # Exp files only

my $outputFile;            # default STDOUT
my $logLevel;              # default log warnings and errors only

my $readstoload;
my $readstoskip;

my $validKeys = "organism|instance|caf|cafdefault|fofn|forn|out|"
              . "limit|filter|source|exclude|info|help|asped|"
              . "filter|readnamelike|rootdir|"
              . "subdir|verbose|schema|projid|aspedafter|aspedbefore|"
              . "minreadid|maxreadid|skipaspedcheck|isconsensusread|icr|"
              . "noload|noexclude|acceptlikeyeast|aly|onlyloadtags|olt|test|"
              . "group|skipqualityclipcheck";

my %PARS;

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }

    if ($nextword eq '-instance') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance     = shift @ARGV;
    }

    if ($nextword eq '-organism') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism     = shift @ARGV;
    }  
   
    if ($nextword eq '-source') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $source;
        $source       = lc(shift @ARGV);
    }

# exclude defines if reads already loaded are to be ignored (default = Y) 

    $noexclude        = 1            if ($nextword eq '-noexclude');

    $noloading        = 1            if ($nextword eq '-noload');
    $noloading        = 2            if ($nextword eq '-test');

# Do not check Read objects for the presence of an Asped date. This allows
# us to load external reads, which lack this information.

    $skipaspedcheck   = 1            if ($nextword eq '-skipaspedcheck');

# Do not check Read objects for the presence of quality clipping.  This allows
# us to load reads which have been resurrected by zombie.

    $skipqualityclipcheck = 1        if ($nextword eq '-skipqualityclipcheck');

    $consensus_read   = 1            if ($nextword eq '-isconsensusread');
    $consensus_read   = 1            if ($nextword eq '-icr');

    $acceptlikeyeast  = 1            if ($nextword eq '-acceptlikeyeast');
    $acceptlikeyeast  = 1            if ($nextword eq '-aly');

# special mode for tagloading only

    if ($nextword eq '-onlyloadtags' || $nextword eq '-olt') {
        $noexclude    = 1;
        $onlyloadtags = 1;
    }

# logging

    $outputFile       = shift @ARGV  if ($nextword eq '-out');

    $logLevel         = 0            if ($nextword eq '-verbose');
    $logLevel         = 2            if ($nextword eq '-info'); 

# source specific entries are imported in a hash

    $PARS{caf}          = shift @ARGV  if ($nextword eq '-caf');
    $PARS{caf}          = 'default'    if ($nextword eq '-cafdefault');

    $readstoload        = shift @ARGV  if ($nextword eq '-fofn');
    $readstoload        = shift @ARGV  if ($nextword eq '-forn');

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

    $PARS{group}        = shift @ARGV  if ($nextword eq '-group');

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

&showUsage("Undefined data source") unless $source;

if ($source ne 'caf' && $source ne 'oracle' && $source ne 'expfiles' && $source ne 'traceserver') {
    &showUsage("Invalid data source '$source'");
}

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

&showUsage("Missing organism database") unless $organism;

&showUsage("Missing database instance") unless $instance;

my $adb = new ArcturusDatabase (-instance => $instance,
		                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message
    &showUsage("Invalid organism '$organism' on server '$instance'");
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

$readstoload = &readNamesFromFile($readstoload) if $readstoload;

#----------------------------------------------------------------
# ignore already loaded reads? then get them from the database
#----------------------------------------------------------------

if (!$noexclude) {

    $logger->info("Collecting existing readnames");

    my $readsloaded = $adb->getListOfReadNames; # array reference

    my $nr = scalar(@{$readsloaded});

    $readstoskip = {};

    foreach my $readname (@{$readsloaded}) {
	$readstoskip->{$readname} = 1;
    }

    $logger->info("$nr readnames found in database $organism");
}

#----------------------------------------------------------------
# Build the ReadFactory instance.
#----------------------------------------------------------------

my $factory;

if ($source eq 'caf') {

# test CAF filename and open it

    &showUsage("Missing CAF file name") unless $PARS{caf};

    if ($PARS{caf} eq 'default') {
# use the default assembly caf file in the assembly repository
        my $PR = new PathogenRepository();
        $PARS{caf} = $PR->getDefaultAssemblyCafFile($organism);
        $logger->info("Default CAF file used: $PARS{caf}") if $PARS{caf};
    }

    &showUsage("File $PARS{caf} does not exist") unless (-e $PARS{caf});

    $PARS{caf} = new FileHandle($PARS{caf},"r"); # replace by file handle

    &showUsage("Cannot access file $PARS{caf}") unless $PARS{caf};

# add logger to input PARS

    $PARS{log} = $logger;

# test for excess baggage; abort if present (force correct input)

    my @valid = ('caf','include','log','readnamelike','filter');
    &showUsage("Invalid parameter(s)") if &testForExcessInput(\%PARS,\@valid);

    $factory = new CAFReadFactory(%PARS);
}

elsif ($source eq 'oracle') {

    &showUsage("Missing Oracle schema") unless $PARS{schema};

    my @valid = ('schema','projid','aspedafter','aspedbefore',
		 'readnamelike','include','minreadid','maxreadid');

    &showUsage("Invalid parameter(s)") if &testForExcessInput(\%PARS,\@valid);

    $logger->info("Searching Oracle database for new reads");

    $factory = new OracleReadFactory(%PARS);
}

elsif ($source eq 'expfiles') {
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
    &showUsage("No repository defined for $organism") unless $PARS{root};
# add logger to input PARS
    $PARS{log} = $logger;

    my @valid = ('readnamelike','root','subdir','limit','include','log');
    &showUsage("Invalid parameter(s)") if &testForExcessInput(\%PARS,\@valid);

    $factory = new ExpFileReadFactory(%PARS);

    my $rejects = $factory->getRejectedFiles();
    print "REJECTED files: @$rejects\n\n" if $rejects;
}

elsif ($source eq 'traceserver') {
    &showUsage("Missing group name for trace server") unless $PARS{group};

    $factory = new TraceServerReadFactory(%PARS);
}

&showUsage("Unable to build a ReadFactory instance") unless $factory;

$factory->setLogging($logger);

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $processed = 0;

my %loadoptions;
$loadoptions{skipaspedcheck}     = 1 if $skipaspedcheck;
$loadoptions{skipaspedcheck}     = 1 if $consensus_read;
$loadoptions{skipligationcheck}  = 1 if $consensus_read;
$loadoptions{skipchemistrycheck} = 1 if $consensus_read;
$loadoptions{acceptlikeyeast}    = 1 if $acceptlikeyeast;
$loadoptions{skipqualityclipcheck} = 1 if $skipqualityclipcheck;

$readstoload = $factory->getReadNamesToLoad() unless defined($readstoload);

foreach my $readname (@{$readstoload}) {

    next if (!$noloading && !$onlyloadtags && $adb->hasRead($readname)); # already stored

    my $read = $factory->getReadByName($readname);

    next if !defined($read); # do error listing inside factory

    if ($onlyloadtags) {
# check if the read exists in the database
        $logger->info("processing read $readname") if ($noloading  > 1); # test
        next unless $read->hasTags();
        my $rtags = $read->getTags();
        my $nrtgs = scalar(@$rtags);
        $logger->info("processing read $readname ($nrtgs tag)") if ($noloading <= 1);
        my $existingread = $adb->getRead(readname=>$readname);
        unless ($existingread) {
            $logger->warning("read $readname is not found in database $organism");
            next;
	}
#        foreach my $tag (@$rtags) {
#            $existingread->addTag($tag);
#	 }
        next if $noloading; # test mode
        $adb->putTagsForReads([($read)]);
        next;
    }

    elsif ($noloading) {

        my $report = $adb->testRead($read,%loadoptions);

        print STDOUT "\n$readname: $report\n";

	$read->writeCafSequence(*STDOUT) if ($noloading > 1);

        next;
    }

    $logger->info("Storing $readname (".$read->getReadName.")");

    my ($success,$errmsg) = $adb->putRead($read, %loadoptions);

    $logger->severe("Unable to put read $readname: $errmsg") unless $success;

    $adb->putTraceArchiveIdentifierForRead($read) if $success;

    $adb->putTagsForReads([($read)]) if $read->hasTags();
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

    &showUsage("File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage("Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g; # clip leading/trailing blanks
        $name =~ s/^.*\///; # remove directory indicators
        push @list, $name;
    }

    return [@list];
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Arcturus read loader from multiple sources\n";
    print STDERR "Arcturus read-tag loader for reads already loaded\n";
    print STDERR "\n";
    print STDERR "Parameter input ERROR: $code \n" if $code;
    unless ($organism && $instance && $source) {
        print STDERR "\n";
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\teither 'prod', 'dev' or 'test'\n" unless $instance;
        print STDERR "-source\t\tEither 'CAF',' Oracle', 'Expfiles' or 'TraceServer'\n" unless $source;
    }
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    print STDERR "-forn\t\t(-fofn) filename with list of readnames to be included\n";
    print STDERR "-filter\t\tprocess only those readnames matching pattern or substring\n";
    print STDERR "-readnamelike\tprocess only those readnames matching pattern or substring\n";
    print STDERR "-noexclude\t(no value) override default exclusion of reads already loaded\n";
    print STDERR "-noload\t\t(no value) do not load the read(s) found (test mode)\n";
    print STDERR "-onlyloadtags\t(-olt, no value) load tags for already loaded read(s)\n";
    print STDERR "\t\t e.g. to load tags from experiment files use:\n";
    print STDERR "\t\t.. -source Expfiles -onlyloadtags -subdir ETC [-verbose -noload]\n";
    print STDERR "\n";
    print STDERR "-skipaspedcheck\t (for reads without asped date)\n";
    print STDERR "-skipqualityclipcheck\t (for reads without quality clipping)\n";
    print STDERR "-isconcensusread (-icr; for artificial reads) \n";
    print STDERR "\n";
    print STDERR "-out\t\toutput file, default STDOUT\n";
    print STDERR "-info\t\t(no value) for some progress info\n";
    print STDERR "-verbose\t(no value)\n";
    print STDERR "\n";

    if (!$source || $source eq 'CAF') {
	print STDERR "Parameters for CAF input:\n";
	print STDERR "\n";
	print STDERR "-caf\t\tcaf file name OR as alternative\n";
	print STDERR "-cafdefault\tuse a default caf file name\n";
	print STDERR "\n";
    }
    if (!$source || $source eq 'Oracle') {
	print STDERR "Parameters for Oracle input:\n";
	print STDERR "\n";
	print STDERR "-schema\t\tMANDATORY: Oracle schema\n";
	print STDERR "-projid\t\tMANDATORY: Oracle project ID\n";
	print STDERR "-aspedbefore\tasped date guillotine\n";
	print STDERR "-aspedafter\tasped date guillotine\n";
	print STDERR "-minreadid\tminimum Oracle read ID\n";
	print STDERR "-maxreadid\tmaximum Oracle read ID\n";
	print STDERR "\n";
    }
    if (!$source || $source eq 'Expfiles') {
	print STDERR "Parameters for Expfiles input:\n";
	print STDERR "\n";
	print STDERR "-rootdir\troot directory of data repository\n";
	print STDERR "-subdir\t\tsub-directory filter\n";
	print STDERR "-limit\t\tlargest number of reads to be loaded\n";
	print STDERR "\n";
    }
    if (!$source || $source eq 'TraceServer') {
	print STDERR "Parameters for TraceServer input:\n";
	print STDERR "\n";
	print STDERR "-group\t\tMANDATORY: name of trace server group to load\n";
	print STDERR "-minreadid\tminimum trace server read ID\n";
	print STDERR "\n";
    }

    print STDERR "Parameter input ERROR: $code\n\n" if $code;
    print STDERR "Define a data source!\n\n"  unless $source;
    
    $code ? exit(1) : exit(0);
}
