#!/usr/local/bin/perl -w

use strict;

use ArcturusDatabase;

use Contig;

use ContigFactory::ContigFactory;

use TagFactory::TagFactory;

use Logging;

my $DEBUG = 0;

#----------------------------------------------------------------
# ingest command line parameters
#----------------------------------------------------------------

my ($organism,$instance);

my ($project,$fopn, $contig,$focn,$fofn,$assembly);

my $noscaffold;

my ($minsize,$minread,$maxread);
#my $ignoreblocked = 0;

my $format; # caf,fasta,embl,maf
my $preset;
my $filename;
my $quality; # only with fasta 

my $verbose;
my $filter;
my $preview = 1;
my $debug;

my $gap4name;
my $reverse;
my $padded;
my $readsonly = 0;
my $noreads;

my $notags;      # overrides all other tag specification 
my $includetags; # comma-separated list of tag types to include
my $excludetags; # comma-separated list tag types to exclude and/or
                 # string(s), which if matching tag comment excludes 
my $splittags;   # comma-separated list of tag types which may be split ?

my $masking;
my $msymbol;

my $metadataonly = 1; # ??

my $cliplowquality; # delete high quality pads
my $clipthreshold = 20;
my $marklowquality;
my $lqsymbol = '*';
my $lqthreshold;
my $lqminimum;
my $lqhqpm;
my $lqwindow;

my $trimendregion;
my $removelowqualityreads;
my $undoreadedits;
my $removeinvalidreads;
my $restoremaskedreads;

my $clipsymbol;    # ?

my $endregiononly;
my $centralfill; # default
my $fillsymbol;
my $fillquality;

# scan the command line parameters

my $marklqkeys  = "marklowquality|mlq";
my $cliplqkeys  = "cliplowquality|clq";
my $lqkeys      = "lowqualitysymbol|lqs|clipthreshold|cth";
my $endclipkeys = "trimendregion|ter";
my $tagkeys     = "notags|nt|includetags|it|excludetags|et|splittags|st";
my $endonlykeys = "extractendregion|eer";
my $paddedkeys  = "padded|P";
my $screenkeys  = "undoedit|ue|removelowqualityreads|rlqr|removeinvalidreads|rir"
                . "restoremaskedreads|rmr";

my $validkeys  = "organism|o|instance|i|"                               # dbase
               . "contig|c|focn|fofn|project|p|fopn|assembly|a|accept|" # dataset
               . "ignoreblocked|noscaffold|ns|" # project status (of contigs)
               . "minlen|minsize|ms|minreads|min|maxreads|max|"  # constraints
               . "format|caf|baf|maf|fasta|embl|reverse|"               # output format
#   .|mask|symbol|shrink|"
               . "confirm|info|verbose|debug|help";                     # reporting

#------------------------------ parameter parsing --------------------------------

while (my $nextword = shift @ARGV) {
print STDERR "$nextword validkeys '$validkeys' \n" if $verbose;
    if ($nextword !~ /\-($validkeys)\b/) {
        &showUsage("Invalid keyword '$nextword' or parameter cannot be redefined");
    }
elsif ($nextword =~ /\-($validkeys)\b/) {
print STDERR "$nextword  matches  '$1'\n" if $verbose;
}


# ** define database instance


    if ($nextword eq '-instance' || $nextword eq '-i') {
        $instance  = shift @ARGV;
# remove key from list to prevent redefinition when used with e.g. a wrapper script
        $validkeys =~ s/instance\|i\|//;
	next;
    }

    if ($nextword eq '-organism' || $nextword eq '-o') {
        $organism  = shift @ARGV;
# the next statement prevents redefinition when used with e.g. a wrapper script
        $validkeys =~ s/organism\|o\|//;
	next;
    }  


# ** define what data to export


    if ($nextword eq '-accept') {
# allows preselection of export type
        $validkeys =~ s/accept\|//;
        my $accept = shift @ARGV;
        if ($accept eq 'contig') {
            $validkeys =~ s/project\|p\|fopn\|//;
            $validkeys =~ s/assembly\|a\|//;
	}
        elsif ($accept eq 'project') {
            $validkeys =~ s/contig\|c\|focn\|//;
# still allows for specification of assembly 
	}
	elsif ($accept eq 'assembly') {
            $validkeys =~ s/contig\|c\|focn\|//;
            $validkeys =~ s/project\|p\|fopn\|//;
	}
	else {
            &showUsage("Invalid specification of export type");
	}
	next;
    }

    if ($nextword =~ /^\-(contig|c|focn|fofn|project|p|fopn|assembly|a)$/) {
# remove type definition from valid keys
        $validkeys =~ s/contig\|c\|focn\|//;
        $validkeys =~ s/project\|p\|fopn\|//;
        $validkeys =~ s/fofn\|//;

        if ($nextword =~ /^\-(c|contig|focn|fofn)$/) {
            $contig  = shift @ARGV  if ($nextword =~ /^\-(c|contig)/); # name or ID, or list
            $focn    = shift @ARGV  if ($nextword =~ /^\-(focn|fofn)/); # file of names/IDs
            $validkeys =~ s/assembly\|a\|//;
	    next;
        }

        if ($nextword =~ /^\-(p|project|fopn|fofn)$/) {
            $project = shift @ARGV  if ($nextword =~ /^\-(p|project)/); # name, ID, or list
            $fopn    = shift @ARGV  if ($nextword =~ /^\-(fopn|fofn)/); # file of names/IDs
	    next;
        }

        if ($nextword =~ /^\-(a|assembly)$/) {
            $assembly = shift @ARGV if ($nextword =~ /^\-(a|assembly)/); # name, ID, or list
#            $foan     = shift @ARGV if ($nextword =~ /^\-(foan|fofn)/); # file of names/IDs
            $validkeys =~ s/assembly\|a\|//;
	    next;
	}
    }

# constraints

    if ($nextword eq '-minlen' ||$nextword eq '-minsize' || $nextword eq '-ms') {
        $minsize   = shift @ARGV;
    }

    if ($nextword eq '-minreads' || $nextword eq '-min') {
        $minread   = shift @ARGV;
    }

    if ($nextword eq '-maxreads' || $nextword eq '-max') {
        $maxread   = shift @ARGV;
    }


# ** define output format 

    if ($nextword eq '-format') {
        $preset = shift @ARGV;
        unless ($preset =~ /^(caf|baf|maf|fasta|embl)$/) {
            &showUsage("Invalid output format $format");
        }
# replace options by selected format and add 'file' option
        $validkeys =~ s/caf\|maf\|fasta\|embl/$preset|file/; 
        $validkeys =~ s/format\|//;
    }

    if ($nextword =~ /^\-(caf|baf|maf|fasta|embl|file)$/) {
        $format = $1;
        $format = $preset if ($format eq 'file');
        $validkeys =~ s/caf\|baf\|maf\|fasta\|embl\|/$format\|/;
        $validkeys =~ s/file\|//; # presence implies previous 'format' key
# read the filename
        $filename  = shift @ARGV;
        unless (defined($filename) && $filename !~ /^\-/) {
            &showUsage("Invalid or missing filename ($filename)");
        }
# setup the valid keys for each data type
        if ($format eq 'caf') {
            $validkeys .= "|noreads|nr|gap4name|g4n|readsonly|ro|"
                       .  $tagkeys.'|'.$marklqkeys.'|'.$endclipkeys.'|'
                       .  $paddedkeys.'|'.$screenkeys;
	}
        if ($format eq 'baf') {
            $validkeys .= "|noreads|nr|gap4name|g4n|readsonly|ro|"
                       .  $tagkeys.'|'.$marklqkeys.'|'.$endclipkeys.'|'
                       .  $paddedkeys.'|'.$screenkeys;
	}
        elsif ($format eq 'fasta') {
            $validkeys .= "quality|q|readsonly|ro|gap4name|g4n|"
		       .   $endonlykeys."|mask|symbol|shrink|"
                       .   $cliplqkeys.'|'.$marklqkeys.'|'.$endclipkeys
                       .   '|'.$paddedkeys.'|'.$screenkeys;
# shrink|" ?
#               . "|mask|symbol|"
        }
	elsif ($format eq 'embl') {
	    $validkeys .= $marklqkeys.'|'.$cliplqkeys.'|'
                        . $tagkeys.'|'.$paddedkeys;
	}
	elsif ($format eq 'maf'){
            $validkeys .= "runlengthsubstitute|rls|";
	}
	else {
	}
        next;
    }

    if ($nextword eq '-quality' || $nextword eq '-q') {
# quality key implies fasta format
        $quality  = shift @ARGV;
        unless (defined($quality) && $quality !~ /$\-/) {
            &showUsage("Invalid or missing filename ($quality)");
        }
	next;
    }

# ** output options

    if ($nextword eq '-minerva' || $nextword eq '-m') {
#        $minerva = '#MINERVA ';;
	next;
    }  

    if ($nextword eq '-reverse' || $nextword eq '-r') {
        $reverse  = 1;
    }

    if ($nextword eq '-padded' || $nextword eq '-P') {
        $padded   = 1;
    }
         
    if ($nextword eq '-undoedits' || $nextword eq '-ue') {
	$undoreadedits = 1;
    }

    if ($nextword eq '-removelowqualityreads' || $nextword eq '-rbr') {
	$removelowqualityreads = 1;
    }

    if ($nextword eq '-removeinvalidreads' || $nextword eq '-rir') {
        $removeinvalidreads = 1;
    }
 
    if ($nextword eq '-restoremaskedreads' || $nextword eq '-rmr') {
        $restoremaskedreads = 1;
    }
        
    if ($nextword eq '-gap4name'  || $nextword eq '-g4n') {
        $gap4name  = 1;
    }

    if ($nextword eq '-readsonly' || $nextword eq '-ro') {
        
        $readsonly = 1; # implies fasta
    }           

    if ($nextword eq '-noreads'   || $nextword eq '-nr') {
        $noreads   = 1; # implies CAF
    }            



    if ($nextword eq '-notags'    || $nextword eq '-nt') {
        $notags    = 1;
    }            

    if ($nextword eq '-includetags'    || $nextword eq '-it') {
        $includetags = shift @ARGV;
    }            

    if ($nextword eq '-excludetags'    || $nextword eq '-et') {
        $excludetags = shift @ARGV;
    }            

    if ($nextword eq '-splittags'      || $nextword eq '-st') {
        $splittags = shift @ARGV;
    }            

#    $ignblocked   = 1            if ($nextword eq '-ignoreblocked');

    if ($nextword eq '-noscaffold'     || $nextword eq '-ns') {
        $noscaffold = 1;
    }            

# low quality treatment

    if ($nextword eq '-marklowquality' || $nextword eq '-mlq') {
        $validkeys =~ s/$cliplqkeys//; # ?
        $validkeys .= $lqkeys;
        $marklowquality = 1;
    }

    if ($nextword eq '-cliplowquality' || $nextword eq '-clq') {
        $validkeys =~ s/$marklqkeys//; # ?
        $validkeys .= $lqkeys;
        $cliplowquality = 1;
    }

    if ($nextword eq '-lowqualitysymbol' || $nextword eq '-lqs') {
        $lqsymbol = shift @ARGV;
    }
    if ($nextword eq '-clipthreshold' || $nextword eq '-csh') {
        $lqthreshold = shift @ARGV;
# minimum, hqpm ?
    }

    if ($nextword eq '-trimendregion' || $nextword eq '-ter') {
        $trimendregion = shift @ARGV; # quality threshold used for trimming
    }
 

# replacing low quality

#    $masking       = shift @ARGV  if ($nextword eq '-mask');

#    $msymbol       = shift @ARGV  if ($nextword eq '-symbol');

#    $mshrink       = shift @ARGV  if ($nextword eq '-shrink');


# extract end regions only

    if ($nextword eq '-extractendregion' || $nextword eq '-eer') {
        $validkeys .= "|centralfill|cf|fillsymbol|fs|fillquality|fq";
        $endregiononly = shift @ARGV || 500;
        &testnumeric($endregiononly);
        $centralfill = 100;
        $fillsymbol = 'X';
	$fillquality = 50;
    }
    if ($nextword eq '-centralfill' || $nextword eq '-cf') {
        $centralfill = shift @ARGV;
        &testnumeric($centralfill);
    }
    if ($nextword eq '-fillsymbol' || $nextword eq '-fs') {
        $fillsymbol = shift @ARGV;
    }
    if ($nextword eq '-fillquality' || $nextword eq '-fq') {
        $fillquality = shift @ARGV;
        &testnumeric($fillquality);
    }

    $preview = 0           if ($nextword eq '-confirm');

# ** logging

    $filter = 1            if ($nextword eq '-verbose');

    $filter = 2            if ($nextword eq '-info');

    $debug  = 1            if ($nextword eq '-debug');

    &showUsage(0) if ($nextword eq '-help');
}
 
#----------------------------------------------------------------
# test input specification for completeness
#----------------------------------------------------------------

unless ($contig || $focn || $project || $fopn || $assembly) {
    &showUsage("Missing contig, project or assembly name or ID");
}

&showUsage("Missing output format specification") unless $format;

#----------------------------------------------------------------
# open file handle for output via a Reporter module
#----------------------------------------------------------------
                                                                               
my $logger = new Logging();
 
$logger->setStandardFilter($filter) if defined($filter); # reporting level

$logger->setBlock('debug',unblock=>1) if $debug;

#$logger->setSpecialStream('some logfile');
$logger->special("Special stream active");

Contig->setLogger($logger);

TagFactory->setLogger($logger);
 
#----------------------------------------------------------------
# get the database connection
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

$organism = $adb->getOrganism(); # taken from the actual connection
$instance = $adb->getInstance(); # taken from the actual connection
 
my $URL = $adb->getURL;

$logger->info("Database $URL opened succesfully");

$adb->setLogger($logger);

Contig->setLogger($logger);
 
#----------------------------------------------------------------
# get a list of contigs or projects to be exported
#----------------------------------------------------------------

my ($contigs,$projects) = &getcontigsandprojects($contig,$focn,
                                                 $project,$fopn,
                                                 $assembly);

# require for any request except single projects the provision of a temporary  
# gap4database or name to be created in the main project directory ?? 

unless (@$contigs || @$projects) {
    $logger->severe("No valid contig(s) or project(s) specified");
    $adb->disconnect();
    exit;
}

#----------------------------------------------------------------
# get file handles
#----------------------------------------------------------------

my ($fhDNA, $fhQTY, $fhRDS);

unless ($preview) {
   ($fhDNA, $fhQTY, $fhRDS) = &getfilehandles($format,$filename,$quality);
    exit 1 unless $fhDNA;
}

my %woptions; #  = (blankline => 0); 

#----------------------------------------------------------------
# MAIN
#----------------------------------------------------------------

my $errorcount = 0;
my $exportcount = 0;
my $ignorecount = 0;

my %contighash;
my %projecthash;

my %eoptions;
$eoptions{noscaffold} = 1 if $noscaffold;

while (@$contigs || @$projects) {

    unless (@$contigs) {
# get contigs from the next project
        my $project = shift @$projects;
        my $pid = $project->getProjectID();
        next if $projecthash{$pid}; # protect against duplicate project identifiers 
        my ($contigids,$status) = $project->getContigIDsForExport(%eoptions);
# ?? IGNORE LOCKED should be an option ?
        unless ($contigids && @$contigids) {
	    $logger->error("No contigs found or accessible for project "
                          .$project->getProjectName()." (id=$pid ? may be locked)");
	    $contigids = [];
	}

        my $projectname = $project->getProjectName();
        my $nrofcontigs = $project->getNumberOfContigs() || 0;
        $logger->error("Exporting project $projectname with $nrofcontigs contigs");
# print : exporting project  
        $projecthash{$pid}++;
        unless (scalar(@$contigids) == $nrofcontigs) {
            $logger->error("Inconsistent contig count : actual ".scalar(@$contigids));
            $errorcount++; 
	}
	$contigs = $contigids;
#	@$contigs = sort {$a <=> $b} @$contigids;
        if ($preview) {
            $logger->warning("project $projectname with ".scalar(@$contigs)
                            ." contigs to be exported; repeat with '-confirm'");
            undef @$contigs;
	    next;
	}
    }

    elsif ($preview) {
        $logger->warning(scalar(@$contigs) . " contigs to be exported; repeat with '-confirm'");
        undef @$contigs;
        next;
    }

    foreach my $identifier (@$contigs) {
# test valid identifier
        unless ($identifier) {
            $logger->error("Invalid or missing contig identifier");
            next;
        }
# test for reversal (stripping possible leading - sign from identifier)
        my $reverse = ($identifier =~ s/^\-//) ? 1 : 0;
# protect against duplicate (input) contig identifiers
        if ($contighash{$identifier}) {
            $logger->error("Duplicate identifier $identifier ignored");
            next;
	}

# get the contig from the database

        undef my %coptions;
        $coptions{metaDataOnly} = $metadataonly; # redundent?
        $coptions{withRead}  = $identifier if ($identifier =~ /\D/);
        $coptions{contig_id} = $identifier if ($identifier !~ /\D/);
# $options{ignoreblocked} = 1;

        $logger->info("Getting contig $identifier");
        my $contig = $adb->getContig(%coptions) || 0;
        unless ($contig) {
            $logger->error("Contig $identifier not found ; "
                            ."Blocked or unknown contig");
            $ignorecount++;
            next;
	}
        $logger->info("Contig returned: $contig");
# test again for duplicates
        my $cid = $contig->getContigID();
        my $cnm = $contig->getContigName();
        if ($contighash{$cid} || $contighash{$cnm}) {
            $logger->error("Duplicate identifier $cid or $cnm ignored");
            next;
	}
# register all identifiers 
        $contighash{$identifier}++;
        $contighash{$cid}++;
        $contighash{$cnm}++;

# test for minimum size or minumum number of reads

        my $nreads = $contig->getNumberOfReads() || 0;
        my $length = $contig->getConsensusLength() || 0;
        if ($minsize && $length < $minsize  
         || $minread && $nreads < $minread
         || $maxread && $nreads > $maxread) {
	    $logger->error("Contig $cnm skipped (l: $length  r:$nreads)");
            $ignorecount++;
            next;
	}

        unless ($notags) {
            my $tags = $contig->getTags(1) || [];
            if (($includetags || $excludetags) && !@$tags) {
                 $logger->error("Contig $cnm has no tags");
                 $contig->erase();
                 next;
	    }
	}
  
# check here if these 
#        $contig->getMappings(1);
#        $contig->getStatistics();

# ----------------- data manipulation before export ----------------------

# end-region-only : extract the end regions to create a fixed length "contig" (re: crossmatch)

        if ($endregiononly) {
# extract the end regions into a new "contig" 
            my %eroptions = (endregiononly => $endregiononly);
            $eroptions{maskingsymbol} = $fillsymbol;
            $eroptions{shrink} = $centralfill;
	    $eroptions{qfill} = 50; # quality value in central fill
            $contig = $contig->extractEndRegion(%eroptions);
            unless ($contig) {
	        $logger->info("Failed to mask endregions for $cnm");
                $ignorecount++;
                next;
	    }
        }

# end-region-trim : remove low quality consensus at either end (e.g. for oligo selection)

        if ($trimendregion) {
# if CAF output get contig components before doing the trimming
            my %ertoptions = (cliplevel=>$trimendregion);
            $ertoptions{complete} = 1 unless ($format eq 'fasta');
            my ($clipped,$cstatus) = $contig->endRegionTrim(%ertoptions);
            $logger->warning($cstatus);
            unless ($clipped) {
	        $logger->warning("Failed to trim endregions for $cnm");
                $ignorecount++;
                next;
	    }
print STDOUT "endRegionTrim; $contig  $clipped\n";
            $contig = $clipped;
#	    $contig->getStatistics(1) if ($format ne 'fasta'); # to Helper method
        }

# quality mark : mark high quality pads in consensus

        if ($marklowquality) {
            $logger->info("quality marking");
            my %lqoptions;
            $lqoptions{hqpm} = 0; # mark all "high" quality pads
            $lqoptions{minimum} = 0; # but keep all low quality bases
            $lqoptions{padsymbol} = $lqsymbol if $lqsymbol;
            my ($newcontig,$status) = $contig->replaceLowQualityBases(%lqoptions);
            $contig = $newcontig if $newcontig;
	}

# quality clip : remove high quality pads from consensus (e.g. to approximate "finished")

        if ($cliplowquality) {
            $logger->info("quality clipping");
            my %lqoptions = (exportaschild=>1,components=>0);
#            $lqoptions{hqpm} = 0; # delete all "high" quality pads (and non ACGT)
#            $lqoptions{minimum} = 0; # but keep all low quality bases
# these deal with tags under remapping
            $lqoptions{components} = 1;
#            $lqoptions{breaktags} = $splittags if $splittags;
#            $lqoptions{nomergetaglist} = 'REPT';

            my ($clippedcontig,$status) = $contig->deleteLowQualityBases(%lqoptions);

	    if ($status && $clippedcontig ne $contig) {
                my %tagoptions;
		$tagoptions{finishing} = 'WARN,CSUB,REPT';
                $tagoptions{annotation} = 'ANNO,CDS,CDSM,CHAD';
                $clippedcontig->inheritTags(%tagoptions);
                $contig->erase(); # garbage collection
                $contig = $clippedcontig;
    	    }
	    elsif (!$status) {
		$logger->severe("Failed to clip contig ".$contig->getContigName());
	    }
        }

# cleanup (remove low quality / very short reads) / unedit (replace edited reads by original)

        if ($removelowqualityreads) {
# remove bad/short reads from the assembly
            my ($newcontig,$status) = $contig->deleteLowQualityReads();
            $contig->erase(); # garbage collection
            $contig = $newcontig; # better checks
        }

        if ($undoreadedits) {
# translate edited reads back to the original SCF
            my ($newcontig,$status) = $contig->undoReadEdits();
            $contig->erase(); # garbage collection
            $contig = $newcontig;
	}

# remove invalid readnames

        if ($removeinvalidreads) {
            my ($newcontig,$status) = $contig->removeInvalidReadNames();
	    $logger->warning($status);
        }

# restore masked reads

        if ($restoremaskedreads) {
            my $status = $contig->restoreMaskedReads();
	    $logger->error("number of reads restored: $status");
        }

# padded : replace unpaddedcontig by padded version

        if ($padded || $format eq 'baf') {
$logger->info("padding $contig");
            $contig = $contig->toPadded();
$logger->info("return $contig ".$contig->isPadded() || 'not padded!');
            unless ($contig) {
	        $logger->info("Failed to pad $cnm");
                $ignorecount++;
                next;
	    }
        }

        if ($reverse) {
# TO BE DEVELOPED
            my %roptions = (nonew=>1);
undef %roptions;
#$contig->getMappings(1) unless $roptions{nonew};
            $roptions{complete} = 1 unless ($format eq 'fasta');
            my $newcontig = $contig->reverse(%roptions);

$contig->getMappings(1) unless $roptions{nonew};
$logger->setPrefix("main");
$logger->debug("in: $contig  out: $newcontig");
$logger->debug($contig->toString());
$logger->debug($newcontig->toString());
            my @same = $contig->isEqual($newcontig);
$logger->setPrefix("main->");
$logger->debug("equality test: @same");
            @same = $newcontig->linkToContig($contig);

$logger->setPrefix("main->");
$logger->debug("link test: @same");
            my $c2cmapping = $newcontig->getContigToContigMappings();
$logger->debug($c2cmapping->[0]->toString()) if $c2cmapping;

            @same = $newcontig->linkToContig($contig,new=>1);
$logger->setPrefix("main->");
$logger->debug("newlink test: @same");
            $c2cmapping = $newcontig->getContigToContigMappings();
$logger->debug($c2cmapping->[0]->toString()) if $c2cmapping;

            $contig = $newcontig unless $roptions{nonew};
	}

#------------------------------- output ---------------------------------

        my $err;

        $contig->setContigName($identifier) if ($identifier =~ /\D/);

        if ($format eq 'caf') {
$logger->info("return $contig ".$contig->isPadded() || 'not padded!');
            $woptions{gap4name } = 1 if $gap4name;
            $woptions{noreads}   = 1 if $noreads;
            $woptions{readsonly} = 1 if $readsonly;
#            $woptions{qualitymask} = $masking if $masking;
#            $woptions{qualitymask} = $msymbol if $msymbol; # overrides
            $woptions{notags}      = 1 if $notags;
            $woptions{includetags} = $includetags if $includetags;
            $woptions{excludetags} = $excludetags if $excludetags;
            $err = $contig->writeToCaf($fhDNA,%woptions);
	}

        if ($format eq 'baf') {
$logger->info("return $contig ".($contig->isPadded() ? 'padded' : 'not padded!'));
            $woptions{gap4name } = 1 if $gap4name;
            $woptions{noreads}   = 1 if $noreads;
            $woptions{readsonly} = 1 if $readsonly;
            $woptions{qualitymask} = $masking if $masking;
            $woptions{qualitymask} = $msymbol if $msymbol; # overrides
            $woptions{notags}      = 1 if $notags;
            $err = $contig->writeToBaf($fhDNA,%woptions);
	}

        elsif ($format eq 'fasta') {
            $woptions{gap4name}  = 1 if $gap4name;
            $woptions{readsonly} = 1 if $readsonly;
#            $woptions{qualitymask} = $masking if $masking;
#            $woptions{qualitymask} = $msymbol if $msymbol; # overrides
            $err = $contig->writeToFasta($fhDNA,$fhQTY,%woptions);
	}

        elsif ($format eq 'embl') {
            $woptions{notags}      = 1 if $notags;
            $woptions{includetag} = $includetags if $includetags;
            $woptions{excludetag} = $excludetags if $excludetags;
            $err = $contig->writeToEMBL($fhDNA,0,%woptions);
	}

        elsif ($format eq 'maf') {
            $err = $contig->writeToMaf($fhDNA,$fhQTY,$fhRDS,%woptions) ;
	}

        $exportcount++ unless $err;

        $errorcount++ if $err;

        $contig->erase();
        undef $contig;
    }
    $contigs = []; # undef as an array
}

$adb->disconnect();

# TO BE DONE: message and error testing

$logger->setPrefix("contig-export:");
if (defined($filename) && !$filename) { # i.e. = 0
    $logger->error("$ignorecount contigs have been ignored") if $ignorecount;
    $logger->error("$exportcount contigs have been exported") if $exportcount;
    $logger->error("NO contigs have been exported") unless $exportcount;
    $logger->error("There were no errors") unless $errorcount;
    $logger->error("$errorcount Errors found") if $errorcount;
}
else {
    $logger->warning("$ignorecount contigs have been ignored") if $ignorecount;
    $logger->warning("$exportcount contigs have been exported") if $exportcount;
    $logger->warning("NO contigs have been exported") unless $exportcount;
    $logger->warning("There were no errors") unless $errorcount;
    $logger->warning("$errorcount Errors found") if $errorcount;
}

foreach my $handle ($fhDNA,$fhQTY,$fhRDS) {
    $handle->close() if $handle;
}

$logger->close();

exit;

#------------------------------------------------------------------------
# subs
#------------------------------------------------------------------------

sub getcontigsandprojects {
    my $contig   = shift; # contig, or comma separated list
    my $focn     = shift; # filename, or .agp scaffold file
    my $project  = shift; # project, or comma separated list, name or ID
    my $fopn     = shift; # filename with list of projects
    my $assembly = shift; # assembly name or ID

    my $contigs = [];

# --- contig specification ---

    if ($contig) {
# single ID or comma-separated list
        my $locn = &getNames($contig);
        push @$contigs,@$locn if $locn;
    }

    if ($focn && $focn =~ /\.agp/) {
# contig scaffold provided with agp filename; return list of contigs
        my $clist = ContigFactory->parseScaffold($focn); # parse file
        push @$contigs,@$clist if ($clist && @$clist);
# (any '-' sign indicates a counter aligned contig)
    }
    elsif ($focn) { # not an .agp file
# file of contig IDs
        $focn = &getNamesFromFile($focn);
        $contigs = $focn if $focn;
    }

# --- project specification ---

    my $projects = []; # or projects

    if ($fopn) {
        $fopn = &getNamesFromFile($fopn);
        $projects = $fopn if $fopn;
    }

    if ($project) {
        my $lopn = &getNames($project);
        push @$projects,@$lopn if $lopn;
    }
   
# if projects specified, identify them in the data base

    if (@$projects || $assembly) {
        $projects = &getProjects($adb,$projects,$assembly);
    }

    return $contigs,$projects;
}

sub getNamesFromFile {
    my $file = shift; # file name
                                                                                
    &showUsage("File $file does not exist") unless (-e $file);
 
    my $FILE = new FileHandle($file,"r");
 
    &showUsage("Can't access $file for reading") unless $FILE;
 
    my @list;
    while (defined (my $name = <$FILE>)) {
        $name =~ s/^\s+|\s+$//g;
        my $names = &getNames($name);
        push @list, @$names if $names;
    }
 
    return [@list];
}

sub getNames {
# decode a (list of) names in an input field
    my $input = shift;

    my @names = split /[\s\,\:]+/,$input;

    return [@names];
}

sub getProjects {
    my $adb = shift;
    my $identifiers = shift;
    my $assembly = shift;
# now collect all projects for the given identifiers

    my @projects;

    my %selectoptions;
    if (defined($assembly)) {
        $selectoptions{assembly_id}  = $assembly if ($assembly !~ /\D/);
        $selectoptions{assemblyname} = $assembly if ($assembly =~ /\D/);
    }

    unless (@$identifiers) {
# no project name or ID is defined: get all project for specified assembly
         my ($projects,$message) = $adb->getProject(%selectoptions);
# more than one project can be returned
         if ($projects && @$projects) {
             push @projects, @$projects;
         }
#         elsif (!$batch) {
#             $logger->warning("No projects found ($message)");
#        }
    }

    foreach my $identifier (@$identifiers) {

        $selectoptions{project_id}  = $identifier if ($identifier !~ /\D/);
        $selectoptions{projectname} = $identifier if ($identifier =~ /\D/);

        my ($projects,$message) = $adb->getProject(%selectoptions);

        if ($projects && @$projects) {
            push @projects, @$projects;
        }
#    elsif (!$batch) {
#        $logger->warning("Unknown project $identifier");
#    }
    }

# okay, here we have collected all projects to be exported
     
    return [@projects];
}

#----------------------------------------------------------------------------
# file handles
#----------------------------------------------------------------------------

sub getfilehandles {
# returns a number of file handles for requested format, or undef
    my $format = shift;
    my $filename = shift;
    my $quality = shift;

    my ($fhDNA, $fhQLT, $fhRDS);

# CAF format

    if ($format eq 'caf' && $filename) {
        $filename .= '.caf' unless ($filename =~ /\.caf$|null/);
        $fhDNA = new FileHandle($filename, "w");
        &showUsage("Failed to create CAF output file \"$filename\"") unless $fhDNA;
    }
    elsif ($format eq 'caf' && defined($filename)) { # = 0
        $fhDNA = *STDOUT;
    }

# BAF format

    if ($format eq 'baf' && $filename) {
        $filename .= '.baf' unless ($filename =~ /\.baf$|null/);
        $fhDNA = new FileHandle($filename, "w");
        &showUsage("Failed to create CAF output file \"$filename\"") unless $fhDNA;
    }
    elsif ($format eq 'baf' && defined($filename)) { # = 0
        $fhDNA = *STDOUT;
    }

# FASTA format

    if ($format eq 'fasta' && $filename) {
        $filename .= '.fas' unless ($filename =~ /\.fas$|null/);
        $fhDNA = new FileHandle($filename, "w");
        unless ($fhDNA) {
            $logger->error("Failed to create FASTA sequence output file \"$filename\"");
            $adb->disconnect();
	    return undef;
	}
        if (defined($quality)) {
            $fhQTY = new FileHandle($quality, "w"); 
            unless ($fhQTY) {
  	        $logger->error("Failed to create FASTA quality output file \"$quality\"");
                $adb->disconnect();
	        return undef;
	    }
        }
        elsif ($filename eq '/dev/null') {
            $fhQTY = $fhDNA;
        }
    }
    elsif ($format eq 'fasta' && defined($filename)) { # = 0
        $fhDNA = *STDOUT;
    }

# EMBL format

    if ($format eq 'embl' && $filename) {
        $filename .= '.embl' unless ($filename =~ /\.embl$|null/);
        $fhDNA = new FileHandle($filename, "w");
        unless ($fhDNA) {
            $logger->error("Failed to create EMBL output file \"$filename\"");
            $adb->disconnect();
	    return undef;
	}
    }
    elsif ($format eq 'embl' && defined($filename)) {
        $fhDNA = *STDOUT;
    }

# MAF (Phusion assembler) format

    if ($format eq 'maf' && $filename) { # 0 not allowed
        my $file = "$filename.contigs.bases";
        $fhDNA = new FileHandle($file,"w");
        unless ($fhDNA) {
            $logger->error("Failed to create MAF output file \"$file\"");
            $adb->disconnect();
	    return undef;
	}
        $file = "$filename.contigs.quals";
        $fhQTY = new FileHandle($file,"w");
        unless ($fhQTY) {
            $logger->error("Failed to create MAF output file \"$file\"");
            $adb->disconnect();
	    return undef;
	}
        $file = "$filename.reads.placed";
        $fhRDS = new FileHandle($file,"w");
        unless ($fhRDS) {
            $logger->error("Failed to create MAF output file \"$file\"");
            $adb->disconnect();
	    return undef;
	}
    }

    elsif ($format eq 'maf' && defined($filename)) { # = 0
        $fhDNA = *STDOUT;
        $fhQTY = $fhDNA;
        $fhRDS = $fhDNA;
    }

    return ($fhDNA,$fhQTY,$fhRDS);
}

#------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------

sub testnumeric {
    my $value = shift;
    unless ($value =~ /\d/ && $value !~ /[^\d\.]/) {
	&showUsage("non-numerical value $value given where number expected");
    }
}

sub showUsage {
    my $code = shift || 0;

    print STDERR "\n";
    print STDERR "Export contigs by contig ID/name(s) or by project ID/name(s)\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
    unless ($organism && $instance) {
        print STDERR "MANDATORY PARAMETERS:\n";
        print STDERR "\n";
        print STDERR "-organism\tArcturus database name\n" unless $organism;
        print STDERR "-instance\t'prod','dev','test'\n"    unless $instance;
        print STDERR "\n";
    }
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    unless ($format && $format eq 'caf') {
        print STDERR "-caf\t\tCAF output file name ('0' for STDOUT)\n";
    }
    unless ($format && $format eq 'fasta') {
        print STDERR "-fasta\t\tFASTA sequence output file name ('0' for STDOUT)\n";
    }
    unless ($format && $format eq 'embl') {
        print STDERR "-embl\t\tEMBL output file name ('0' for STDOUT)\n";
    }
    unless ($format && $format eq 'maf') {
        print STDERR "-maf\t\tMAF output file name root (not '0')\n";
    }
    unless ($format) {
        print STDERR "\t\t***** CHOOSE AN OUTPUT FORMAT *****\n";
    }
    print STDERR "\n";



    print STDERR "\n";
    print STDERR "MANDATORY NON-EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-contig\t\tcontig name or ID, or comma-separated list of "
               . "names or IDs\n";
    print STDERR "-fofn \t\t(focn) name of file with list of Contig IDs\n";
#    print STDERR "-ignoreblock\t(no value) include contigs from blocked projects\n";
    print STDERR "\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for CAF export:\n";
    print STDERR "\n";
    print STDERR "-mask\t\tmask low quality data in reads by this symbol\n";
#    print STDERR "-padded\t\t(no value) export contig & reads in padded format\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS for fasta export:\n";
    print STDERR "\n"; 
    print STDERR "-quality\toutput file name for fasta quality data\n";
    print STDERR "-readsonly\t'-fasta' exports only the reads (no consensus); in "
               . "this case\n\t\tonly the '-mask' option applies and acts as for "
               . "'-caf' export\n";
    print STDERR "\n"; 
    print STDERR "-mask\t\tlength of end regions of contig(s) to be exported, while "
               . "the\n\t\tbases in the central part thereof will be replaced by a "
               . "masking\n\t\tsymbol (to be specified separately)\n";
    print STDERR "-symbol\t\tthe symbol used for the masking (default 'X')\n";

    print STDERR "-shrink\t\tif specified, the size of the masked central part will "
               . "be\n\t\ttruncated to size 'shrink'; longer contigs are then "
               . "clipped\n\t\tto size '2*mask+shrink'; shrink values "
               . "smaller than 'mask'\n\t\twill be reset to 'mask'\n";
#    print STDERR "-padded\t\t(no value) export padded consensus sequence only\n";
    print STDERR "\n";
    print STDERR "-endregiontrim\ttrim low quality endregions at level\n";
    print STDERR "\n";
    print STDERR "-cliplowquality\tRemove low quality pads (default '*')\n";
    print STDERR "-qclipsymbol\tuse specified symbol as low quality pad\n";
    print STDERR "-qclipthreshold\tclip those quality values below threshold\n";
    print STDERR "\n";
    print STDERR "-gap4name\tadd the gap4name (lefthand read) to the identifier\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";

    $code ? exit(1) : exit(0);
    print STDERR "\n";
    print STDERR "MANDATORY EXCLUSIVE PARAMETERS:\n\n";
    print STDERR "-project\tProject ID or name; specify 'all' for everything\n";
    print STDERR "-fopn\t\tname of file with list of project IDs or names\n";
    print STDERR "\n";
    print STDERR "OPTIONAL PARAMETERS:\n";
    print STDERR "\n";
    if ($preview) {
        print STDERR "-confirm\t(no value) go ahead\n";
    }
    else {
        print STDERR "-preview\t(no value) show what's going to happen\n";
    }
    print STDERR "\n";
    print STDERR "-quality\tFASTA quality output file name\n";
#    print STDERR "-padded\t\t(no value) export contigs in padded (caf) format\n";
    print STDERR "-readsonly\t(no value) export only reads in fasta output\n";
    print STDERR "\n";
    print STDERR "-gap4name\tadd the gap4name (lefthand read) to the identifier\n";
    print STDERR "\n";
    print STDERR "Default setting exports all contigs in project\n";
    print STDERR "When using a lock check, only those projects are exported ";
    print STDERR "which either\n are unlocked or are owned by the user running "
               . "this script, while those\nproject(s) will have their lock "
               . "status switched to 'locked'\n";
    print STDERR "\n";
    print STDERR "-lock\t\t(no value) acquire a lock on the project and , if "
                . "successful,\n\t\t\t   export its contigs\n";
    print STDERR "\n"; 
    print STDERR "-mask\t\tlength of end regions of contig(s) to be exported, while "
               . "the\n\t\tbases in the central part thereof will be replaced by a "
               . "masking\n\t\tsymbol (to be specified separately)\n";
    print STDERR "-symbol\t\tthe symbol used for the masking (default 'X')\n";

    print STDERR "-shrink\t\tif specified, the size of the masked central part will "
               . "be\n\t\ttruncated to size 'shrink'; longer contigs are then "
               . "clipped\n\t\tto size '2*mask+shrink'; shrink values "
               . "smaller than 'mask'\n\t\twill be reset to 'mask'\n";
#    print STDERR "-padded\t\t(no value) export padded consensus sequence only\n";
    print STDERR "\n";
    print STDERR "-endregiontrim\ttrim low quality endregions at level\n";
    print STDERR "\n";
    print STDERR "-deletelowquality\tRemove low quality pads (default '*')\n";
    print STDERR "-qclipsymbol\t(qcs) use specified symbol as low quality pad\n";
    print STDERR "-qclipthreshold\t(qct) clip quality values below threshold\n";
    print STDERR "\n";
    print STDERR "-minNX\t\treplace runs of at least minNX 'N's by 'X'-es\n";
    print STDERR "\n";
    print STDERR "-verbose\t(no value) for some progress info\n";
    print STDERR "\n";
    print STDERR "\nParameter input ERROR: $code \n" if $code; 
    print STDERR "\n";
}
