#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

my ($organism,$instance);

my $project = 'ALL';

my $vectordb = 'repeats.dbs'; # default

my $minscore;

my $tagid = 'REPT';

my $confirm;

my $noexport;

my $nomatch;

my $report;

my $validKeys  = "organism|o|instance|i|project|p|vector|v|minscore|m|tag|t|"
               . "confirm|noexport|ne|nomatch|nm|report|help|h";

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
        $organism = shift @ARGV;
    }

    if ($nextword eq '-project' || $nextword eq '-p') {
        $project      = shift @ARGV;
    }

    if ($nextword eq '-vector'  || $nextword eq '-v') {
        $vectordb     = shift @ARGV;
    }

    if ($nextword eq '-minscore' || $nextword eq '-m') {
        $minscore     = shift @ARGV;
    }

    if ($nextword eq '-tagid'   || $nextword eq '-t') {
        $tagid        = shift @ARGV;
    }

    if ($nextword eq '-noexport' || $nextword eq '-ne') {
        $noexport     = 1;
    }

    if ($nextword eq '-nomatch'  || $nextword eq '-nm') {
        $nomatch      = 1;
    }

    $report  = 1 if ($nextword eq '-report'); 

    $confirm = 1 if ($nextword eq '-confirm'); 

    &showUsage() if ($nextword eq '-help'); 
    &showUsage() if ($nextword eq '-h'); 
}

#----------------------------------------------------------------
# get the database connection to test its existence
#----------------------------------------------------------------

if ($organism eq 'default' || $instance eq 'default') {
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

$adb->disconnect();

#----------------------------------------------------------------

my $expfile = "/tmp/".lc($organism)."-$project.depad.exp.caf";
my $impfile = "/tmp/".lc($organism)."-$project.depad.imp.caf";

my $export = "/software/arcturus/utils/project-export "
           . "-instance $instance -organism $organism "
           . "-project $project -ignore problems,trash "
           . "-caf $expfile -gap4name";

# test stuff
# my $alter  =  "/nfs/team81/ejz/arcturus/utils/new-contig-export.pl "
#            . "-instance $instance -organism $organism "
#            . "-project $project -confirm "
#           . "-project $project -ignore problems,trash "
#           . "-caf $expfile -notags";

print STDOUT "\nexporting from Arcturus:\n$export\n";
print STDOUT "Using previously exported file $expfile\n\n" if $noexport;

system($export) unless $noexport;
system("grep REPT $expfile");
system("grep REPT $expfile | wc");

my $caftag = "caftagfeature -tagid $tagid -vector $vectordb" .
    (defined($minscore) ? " -minscore $minscore" : "") . 
    " < $expfile  > $impfile";

print STDOUT "tagging caf file:\n$caftag\n\n";
print STDOUT "Using previously tagged file $impfile\n\n" if $nomatch;

system($caftag) unless $nomatch;
system("grep REPT $impfile") if $report;
system("grep REPT $impfile | wc");

my $import = "/software/arcturus/utils/new-contig-loader "
           . "-instance $instance -organism $organism "
           . "-caf $impfile -noload -lrt -lct";

print STDOUT "re-importing tags: $import\n";
print STDOUT "repeat with -confirm switch\n" unless $confirm;

system($import) if $confirm; 

exit 0;


sub showUsage {
    my $text = shift;

    print STDERR "$text\n\n" if $text;

    print STDERR "\nUsage:\n\n$0 -o [organism] -i [instance] -p [project:ALL]"
                ."-v [vectors:repeats.dbs] -t [tagid:REPT] -m [minscore] "
                ."[-noexport:use existing export] [-nomatch:skip tagging] "
                ."[-report] [-confirm:import result]";
    exit 0;
}
