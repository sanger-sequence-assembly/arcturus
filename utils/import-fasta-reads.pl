#!/usr/local/bin/perl -w

use strict;

use FileHandle;

use ArcturusDatabase;

use Read;

use ContigFactory::ContigFactory;

use TagFactory::TagFactory;

use Logging;

#----------------------------------------------------------------
# variable definitions
#----------------------------------------------------------------

my ($organism,$instance);

my ($project,$assembly);

my ($file,$fofn,$update,$nf,$noextension,$quality,$limit);

my ($attributes,$tagtype,$tagcomment,$tagsequencename);

$tagcomment = "consensus sequence"; # default
$tagtype = 'CONS';                  # default

my ($verbose, $debug, $confirm, $preview);

my $validKeys  = "organism|o|instance|i|"
               . "assembly|a|project|p|"
               . "file|read|forn|fofn|update|asis|noextension|ne|quality|qf|"
               . "attributes|af|"
               . "tagcomment|tc|tagtype|tt|notag|nt|tagsequencename|tsn|"
               . "limit|confirm|preview|verbose|debug|help|h";

while (my $nextword = shift @ARGV) {

    if ($nextword !~ /\-($validKeys)\b/) {
        &showUsage("Invalid keyword '$nextword'");
    }
    if ($nextword eq '-instance' || $nextword eq '-i') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define instance" if $instance;
        $instance = shift @ARGV;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
# the next statement prevents redefinition when used with e.g. a wrapper script
        die "You can't re-define organism" if $organism;
        $organism  = shift @ARGV;
    }

    if ($nextword eq '-project'  || $nextword eq '-p') {
        $project   = shift @ARGV;
    }

    if ($nextword eq '-assembly'   || $nextword eq '-a') {
        $assembly  = shift @ARGV;
    }

    if ($nextword eq '-ne' || $nextword eq '-noextension') {
        $noextension = 1;
    }

    if ($nextword eq '-tagcomment' || $nextword eq '-tc') {
        $tagcomment = shift @ARGV;  
    }

    if ($nextword eq '-tagtype'    || $nextword eq '-tt') {
        $tagtype    = shift @ARGV;  
    }

    if ($nextword eq '-notag'    || $nextword eq '-nt') {
        $tagcomment = 0;
        $tagtype    = 0;  
    }

    if ($nextword eq '-tagsequencename' || $nextword eq '-tsn') {
        $tagsequencename = shift @ARGV; # use read sequence as tag sequence
    }

    if ($nextword eq '-fofn'  || $nextword eq '-forn') {
        $fofn       = shift @ARGV;
    }

    if ($nextword eq '-read'  || $nextword eq '-file') {
        $file       = shift @ARGV;
    }

    if ($nextword eq '-qf'    || $nextword eq '-quality') {
        $quality    = shift @ARGV;
        $tagtype    = '';
        $tagcomment = '';
    }

    if ($nextword eq '-af'    || $nextword eq '-attributes') {
        $attributes = shift @ARGV;
        $tagtype    = '';
        $tagcomment = '';
    }

    $limit         = shift @ARGV  if ($nextword eq '-limit');

    $update        = 1            if ($nextword eq '-update');
    $nf            = 1            if ($nextword eq '-asis');

    $confirm       = 1            if ($nextword eq '-confirm');

    $confirm       = 0            if ($nextword eq '-preview');
    $preview       = 1            if ($nextword eq '-preview');

    $verbose       = 1            if ($nextword eq '-verbose'); # fine
    $verbose       = 2            if ($nextword eq '-info');    # info
    $debug         = 1            if ($nextword eq '-debug');

    &showUsage(0) if ($nextword eq '-help' || $nextword eq '-h');
}

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------

my $logger = new Logging();

$logger->setStandardFilter($verbose) if $verbose; # reporting level

$logger->setBlock('debug',unblock=>1) if $debug;

#----------------------------------------------------------------
# get the database connection
#----------------------------------------------------------------

if ($organism && $organism eq 'default' ||
    $instance && $instance eq 'default') {
    undef $organism;
    undef $instance;
}

my $adb = new ArcturusDatabase (-instance => $instance,
                                -organism => $organism);

if (!$adb || $adb->errorStatus()) {
# abort with error message

    &showUsage("Missing organism database") unless $organism;

    &showUsage("Missing database instance") unless $instance;

    &showUsage("Organism '$organism' not found on server '$instance'");
}

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection

#-----------------------------------------------------------------------------
# get reads; include list from a FOFN (replace name by array reference)
#-----------------------------------------------------------------------------

my @reads;

$fofn = &getNamesFromFile($fofn) if $fofn;

$attributes = &getReadAttributes($attributes) if $attributes;
$attributes = {}  unless defined $attributes;

push @reads,@$fofn if $fofn;

if ($file) {
    push @reads,split /\,|\;/,$file if $file =~ /\,|\;/;
    push @reads, $file unless $file =~ /\,|\;/;
}

&showUsage("Missing read specification") unless @reads;

#-----------------------------------------------------------------------------
# get assembly specification, if applicable
#-----------------------------------------------------------------------------

if (defined($assembly) || defined($project)) {
    my %aoptions;
    if (defined($project)) {
       $aoptions{project_id}   = $project  if ($project !~ /\D/); # number
       $aoptions{projectname}  = $project  if ($project =~ /\D/); # a name
    }
    if (defined($assembly)) {
       $aoptions{assembly_id}  = $assembly if ($assembly !~ /\D/); # a number
       $aoptions{assemblyname} = $assembly if ($assembly =~ /\D/); # a name
    }

   (my $assemblys,$assembly) = $adb->getAssembly(%aoptions);

    if ($assemblys && @$assemblys && @$assemblys > 1) {
        $logger->error("ambiguous project or assembly specification");
        exit 0;
    }
    unless ($assembly) {
        $logger->error("unknown project or assembly");
        exit 0;
    }
    $logger->info("assembly ".$assembly->getAssemblyName() ." confirmed");
}

#------------------------------------------------------------------------------
# convert fasta files into caf file and load read
#------------------------------------------------------------------------------

my $caf = '/tmp/consensusreads.caf';

my $CAF = new FileHandle($caf,'w');

&showUsage("Can't open temporary file") unless $CAF;

my @Reads;
foreach my $fasta (@reads) {

    $fasta =~ s?.*/??; # remove leading directories

    $fasta .= '.fas' unless ($nf || $file =~ /\./); # unless extension specified

# read the fasta file into a contig structure

    my %options = (format => 'fasta');
    $options{quality} = $quality if $quality;
    $options{limit}   = $limit   if $limit;

    my $contigs = ContigFactory->getContigs($fasta,%options);

    unless ($contigs && @$contigs) {
        print STDOUT "Could not parse consensus file $fasta\n";
        next;
    }

# make the contig content into a read

    foreach my $contig (@$contigs) {
        my $sequence = $contig->getSequence();
        my $length = length($sequence);
        my $taglen = $length;

        my $quality = $contig->getBaseQuality() || [];
        my @quality = @$quality; # copy

        unless (@quality) {
            while ($length--) {
                push @quality,1;
            }
	}

        my $readname = $contig->getContigName();
        unless ($readname) {
            $readname = $fasta; # default
            $readname =~ s/\.[^\.]+$// if ($readname =~ /^contig/); # consensus 
            $readname =~ s/\.[^\.]+$// if $noextension;
        }

        my $read = new Read($readname);
        $read->setSequence($sequence);
        $read->setBaseQuality([@quality]);
        $read->setStrand('Forward'); # unless reverse ?

        if (my $data = $attributes->{$readname}) {
            my @items = ('Template','Chemistry','Ligation','Primer','Clone','Strand',
                         'InsertSize','BaseCaller','ProcessStatus','AspedDate');
            foreach my $item (@items) {
                my $dataitem = $data->{lc($item)};
                next unless defined $dataitem;
                eval "\$read->set$item(\$dataitem)";
	    }
	}
# generate a default template, primer, chemistry, etc.. if not yet defined
        my $template = $fasta; $template =~ s/(.*)\..*/$1/;
        $read->setTemplate($template)     unless $read->getTemplate();
# generate chemistry
        $read->setPrimer("Custom_Primer") unless $read->getPrimer();
        $read->setChemistry("Dye_primer") unless $read->getChemistry();

# test/generate quality clipping; test the note field for 

        if (my $extrainfo = $contig->getContigNote()) {
# cleanup the info to prepare split on blanks
            $extrainfo =~ s/^\s+|\s+$//g;
            $extrainfo =~ s/\s*\=\s*/=/g;
            my @extrainfo = split /\s+/,$extrainfo;
            foreach my $info (@extrainfo) {
                my @info = split /\=/,$info;
                $read->setLowQualityLeft ($info[1]) if ($info[0] eq 'QL');
                $read->setLowQualityRight($info[1]) if ($info[0] eq 'QR');
	    }
	}
        
        unless ($read->getLowQualityLeft() || $read->getLowQualityRight()) {
            $read->qualityClip();
	}

        if ($tagtype) {
            my $tag = TagFactory->makeReadTag($tagtype,1,$taglen,
                                              TagComment=>$tagcomment);
            if ($tagsequencename) {
                $tag->setTagSequenceName($tagsequencename);
                $tag->setDNA($sequence);
 	    }
            $read->addTag($tag);
	}

        $read->writeToCaf($CAF);

        push @Reads,$read if ($tagsequencename || $assembly); # use later for update
    }
}

close $CAF;

# finally, load into arcturus using CAF file read loader

if ($preview) {
    &mySystem("cat $caf");
}
elsif ($confirm) {
    my $command = "/software/arcturus/utils/read-loader "
                . "-instance $instance -organism $organism -source CAF "
                . "-icr -skipqualityclipcheck -caf $caf ";
    $command   .= "-assembly $assembly " if $assembly;
    $command   .= "-update" if $update;
    &mySystem($command);

    exit 0 unless @Reads;

    foreach my $read (@Reads) {
	my $readname = $read->getReadName();
        if (defined($assembly)) {
        $logger->warning("updating read $readname");
            my ($success,$errmsg) = $adb->updateRead($read,assembly->$assembly);
            unless ($success) {
                $logger->error("Failed to assign read to assembly $assembly");
                $logger->error("read $readname : $errmsg");
	    }
        }
    }
        
    if (defined($tagsequencename)) {
        my $success = $adb->putTagsForReads(\@Reads,autoload=>1,synchronise=>1);
        $logger->info("update read tags : success = $success");
    }
}
else {
    $logger->warning("consensus reads assembled:");
    &mySystem("grep Sequence $caf");
    $logger->warning("to view : repeat command with -preview");
    $logger->warning("to load : repeat command with -confirm");
}

exit 0;

#------------------------------------------------------------------------------

sub mySystem {
     my ($cmd) = @_;

     my $res = 0xffff & system($cmd);
     return 0 if ($res == 0);

     printf STDERR "system(%s) returned %#04x: ", $cmd, $res;

     if ($res == 0xff00) {
         print STDERR "command failed: $!\n";
         return 1;
     }
     elsif ($res > 0x80) {
         $res = 8;
         print STDERR "exited with non-zero status $res\n";
     }
     else {
         my $sig = $res & 0x7f;
         print STDERR "exited through signal $sig";
         if ($res & 0x80) {print STDERR " (core dumped)"; }
         print STDERR "\n";
     }
     exit 1;
}

sub getNamesFromFile {
    my $file = shift; # file name

    &showUsage(0,"File $file does not exist") unless (-e $file);

    my $FILE = new FileHandle($file,"r");

    &showUsage(0,"Can't access $file for reading") unless $FILE;

    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        push @list, $name;
    }

    close $FILE;

    return [@list];
}

sub getReadAttributes {
# parse the attributes file and build a hash keyed on readname
    my $filename = shift;

    my $DATA = new FileHandle($filename,"r");

    return undef unless $DATA;

    while (my $record = <$DATA>) {
# to be completed
    }

    my $attributehash = {};

    return $attributehash;
}

#------------------------------------------------------------------------------

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Load consensus read(s) in fasta format into Arcturus in two steps\n";
    print STDERR "\n";
    print STDERR "> convert fasta-formatted read(s) into a caf file\n";
    print STDERR "> load read(s) from the caf file using the standard readloader\n";
    print STDERR "\n";
    print STDERR "the intermediate caf read(s) is in '/tmp/consensusreads.caf'\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus organism database\n" unless $organism;
        print STDERR "-instance\tArcturus database instance\n" unless $instance;
        print STDERR "\n";
    }
    unless ($file && $fofn) {
        print STDERR "MANDATORY AT LEAST ONE OF PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-read\t\tread (fasta) file or comma-separated list of names\n";
        print STDERR "-fofn\t\tfile of read fasta filenames\n";
        print STDERR "\t\tdefault file type assumed is .fas (override with '-asis')\n";
        print STDERR "\n";
    }
    print STDERR "OPTIONAL PARAMETERS\n";
    print STDERR "\n";
    print STDERR "-asis\t\tuse filenames as given (overrides default '.fas')\n";
    print STDERR "\n";
    print STDERR "-tc\t\t(tagcomment) default : 'consensus sequence'\n";
    print STDERR "-tt\t\t(tagtype)    default : 'CONS'\n";
    print STDERR "-nt\t\t(notag)\n";
    print STDERR "-tsn\t\t(tagsequencename) use read sequence (also) as tagsequence"
               . " with name\n";
    print STDERR "\n";
#    print STDERR "-assembly\tfor which the reads are entered\n";
    print STDERR "-project\tfor which the reads are entered (implicitly defines "
               . "assembly)\n";
#    print STDERR "\n";
#    print STDERR "-update\tupdate existing read info\n";
    print STDERR "\n";
    print STDERR "-preview\tlist the CAF formatted read(s)\n";
    print STDERR "-confirm\tcommit the read(s) to the database\n";
    print STDERR "\n";
    print STDERR "-verbose\n";
    print STDERR "\n";

    exit 1;
}
