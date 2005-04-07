import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;
import java.io.*;

import javax.naming.Context;

public class TestContigManager {
    private static long lasttime;

    public static void main(String args[]) {
	lasttime = System.currentTimeMillis();

	boolean verbose = Boolean.getBoolean("verbose");
	String mappingOptionString = System.getProperty("mappingOption");
	String consensusOptionString = System.getProperty("consensusOption");
	String logfile = System.getProperty("logfile");
	boolean displayContig = Boolean.getBoolean("displayContig");

	int mappingOption = ArcturusDatabase.CONTIG_NO_MAPPING;

	if (mappingOptionString == null) {
	    mappingOptionString = "noMapping";
	} else {
	    if (mappingOptionString.equalsIgnoreCase("basicMapping"))
		mappingOption = ArcturusDatabase.CONTIG_BASIC_MAPPING;

	    if (mappingOptionString.equalsIgnoreCase("fullMapping"))
		mappingOption = ArcturusDatabase.CONTIG_FULL_MAPPING;
	}

	int consensusOption = ArcturusDatabase.CONTIG_NO_CONSENSUS;

	if (consensusOptionString == null) {
	    consensusOptionString = "noConsensus";
	} else {
	    if (consensusOptionString.equalsIgnoreCase("consensus"))
		consensusOption = ArcturusDatabase.CONTIG_CONSENSUS;
	}

	System.out.println("TestContigManager");
	System.out.println("=================");
	System.out.println();

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	String separator = "                    --------------------                    ";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	String instance = null;
	String organism = null;
	String contiglist = null;
	String projectname = null;

	String objectname = null;

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-instance"))
		instance = args[++i];

	    if (args[i].equalsIgnoreCase("-organism"))
		organism = args[++i];

	    if (args[i].equalsIgnoreCase("-contigs"))
		contiglist = args[++i];

	    if (args[i].equalsIgnoreCase("-project"))
		projectname = args[++i];
	}

	if (instance == null || organism == null) {
	    printUsage(System.err);
	    System.exit(1);
	}

	try {
	    System.out.println("Creating an ArcturusInstance for " + instance);
	    System.out.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.out.println("Creating an ArcturusDatabase for " + organism);
	    System.out.println();

	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	    PrintStream logger = null;

	    if (logfile != null) {
		logger = new PrintStream(new FileOutputStream(logfile));
		if (logger != null)
		    adb.setLogger(logger);
	    }

	    System.out.println("Contig mapping mode is   " + mappingOptionString);
	    System.out.println("Contig consensus mode is " + consensusOptionString);
	    System.out.println();

	    report();

	    if (Boolean.getBoolean("preloadClones")) {
		System.out.println("Pre-loading all clones");
		System.out.println();
		adb.preloadAllClones();
		report();
	    }

	    if (Boolean.getBoolean("preloadLigations")) {
		System.out.println("Pre-loading all ligations");
		System.out.println();
		adb.preloadAllLigations();
		report();
	    }

	    if (Boolean.getBoolean("preloadTemplates")) {
		System.out.println("Pre-loading all templates");
		System.out.println();
		adb.preloadAllTemplates();
		report();
	    }

	    if (Boolean.getBoolean("preloadReads")) {
		System.out.println("Pre-loading all reads");
		System.out.println();
		adb.preloadAllReads();
		report();
	    }

	    if (contiglist != null) {
		System.out.println("Looking up contigs by ID");
		System.out.println();

		int ranges[][] = parseRanges(contiglist);

		for (int i = 0; i < ranges.length; i++) {
		    int firstid = ranges[i][0];
		    int lastid = ranges[i][1];

		    try {
			for (int id = firstid; id <= lastid; id++) {
			    if (verbose) {
				System.out.println();
				System.out.println("LOOKING UP CONTIG[" + id + "]");
			    }
			    
			    Contig contig = adb.getContigByID(id, consensusOption, mappingOption);
			    
			    if (verbose) {
				if (contig == null)
				    System.out.println("*** FAILED ***");
				else {
				    System.out.println(contig);
				    System.out.println("  LENGTH:  " + contig.getLength());
				    System.out.println("  READS:   " + contig.getReadCount());
				    System.out.println("  UPDATED: " + contig.getUpdated());
				}
			    }
			    
			    if (displayContig)
				dumpContig(System.out, contig);
			}
		    }
		    catch (NumberFormatException nfe) {
			System.err.println("Error parsing \"" + args[i] + "\" as an integer.");
		    }
		}

		report();
	    }

	    if (projectname != null) {
		System.out.println("Looking up contigs by project");
		System.out.println();

		int project_id = Integer.parseInt(projectname);

		Contig[] contigs = adb.getContigsByProject(project_id, consensusOption, mappingOption);

		if (contigs != null && contigs.length > 0) {
		    int totlength = 0;
		    int totreads = 0;

		    for (int i = 0; i < contigs.length; i++) {
			Contig contig = contigs[i];

			totlength += contig.getLength();
			totreads += contig.getReadCount();

			if (verbose) {
			    System.out.println(contig);
			    System.out.println("  LENGTH:  " + contig.getLength());
			    System.out.println("  READS:   " + contig.getReadCount());
			    System.out.println("  UPDATED: " + contig.getUpdated());
			}
		    }

		    System.out.println("Found " + contigs.length + " contigs, containing " + totreads +
				       " reads and " + totlength + " bp");
		} else {
		    System.out.println("No contigs were found in project " + project_id);
		}

		report();
	    }
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    public static int[][] parseRanges(String str) {
	int nranges = 1;

	for (int i = 0; i < str.length(); i++)
	    if (str.charAt(i) == ',')
		nranges++;

	int[][] ranges = new int[nranges][2];

	int offset = 0;

	for (int i = 0; i < nranges; i++) {
	    int nextcomma = str.indexOf(',', offset);
	    int nextdash = str.indexOf('-', offset);

	    if (nextcomma < 0)
		nextcomma = str.length();

	    if (nextdash > 0 && nextdash < nextcomma) {
		ranges[i][0] = Integer.parseInt(str.substring(offset, nextdash));
		ranges[i][1] = Integer.parseInt(str.substring(nextdash+1, nextcomma));
	    } else {
		ranges[i][0] = ranges[i][1] = Integer.parseInt(str.substring(offset, nextcomma));
	    }

	    offset = nextcomma + 1;
	}

	return ranges;
    }

    public static void report() {
	long timenow = System.currentTimeMillis();

	System.out.println("******************** REPORT ********************");
	System.out.println("Time: " + (timenow - lasttime));

	lasttime = timenow;

	Runtime runtime = Runtime.getRuntime();

	System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()/1024 + "/" + runtime.totalMemory()/1024);
	System.out.println("************************************************");
	System.out.println();
    }

    public static void dumpContig(PrintStream ps, Contig contig) {
	ps.println(">>> CONTIG " + contig.getID() + "<<<");
	ps.println("");
	ps.println("Length:   " + contig.getLength());
	ps.println("Reads:    " + contig.getReadCount());
	ps.println("Updated:  " + contig.getUpdated());

	Mapping[] mappings = contig.getMappings();

	if (mappings != null) {
	    ps.println();
	    ps.println("Mappings:");
	    ps.println();

	    for (int imap = 0; imap < mappings.length; imap++) {
		Mapping mapping = mappings[imap];

		Sequence sequence = mapping.getSequence();
		Read read = sequence.getRead();

		boolean forward = mapping.isForward();

		ps.println("#" + imap + ": seqid=" + sequence.getID() + ", readid=" + read.getID() + ", readname=" + read.getName());
		byte[] dna = sequence.getDNA();
		if (dna != null)
		    ps.println("  Length: " + dna.length);
		ps.println("  Extent: " + mapping.getContigStart() + " to " + mapping.getContigFinish());
		ps.println("  Sense:  " + (forward ? "Forward" : "Reverse"));

		Segment[] segments = mapping.getSegments();

		if (segments != null) {
		    ps.println();
		    ps.println("  Segments:");
		    ps.println();

		    for (int iseg = 0; iseg < segments.length; iseg++) {
			Segment segment = segments[iseg];

			int cstart = segment.getContigStart();
			int rstart = segment.getReadStart();
			int length = segment.getLength();

			int cfinish = cstart + length - 1;
			int rfinish = forward ? rstart + length - 1 : rstart - length + 1;

			ps.println("    " + cstart + ".." + cfinish + " ---> " + rstart + ".." + rfinish);
		    }
		}

		ps.println();
	    }
	}

	byte[] dna = contig.getConsensus();

	if (dna != null) {
	    String seq = new String(dna);
	    int seqlen = seq.length();

	    ps.println();
	    ps.println("Consensus:");
	    ps.println();

	    for (int i = 0; i < seqlen; i += 50) {
		int j = i + 50;
		ps.println(seq.substring(i, (j < seqlen) ? j : seqlen - 1));
	    }

	    ps.println();

	    ps.println();
	    ps.println("Compisition:");
	    ps.println();

	    int a = 0, c = 0, g = 0, t = 0, n = 0, x = 0;

	    for (int i = 0; i < dna.length; i++) {
		switch (dna[i]) {
		case 'a': case 'A': a++; break;
		case 'c': case 'C': c++; break;
		case 'g': case 'G': g++; break;
		case 't': case 'T': t++; break;
		case 'n': case 'N': n++; break;
		default: x++; break;
		}
	    }

	    ps.println("A: " + a);
	    ps.println("C: " + c);
	    ps.println("G: " + g);
	    ps.println("T: " + t);
	    if (n > 0)
		ps.println("N: " + n);
	    if (x > 0)
		ps.println("X: " + x);

	    ps.println();
	}

	ps.println(">>> ------------------------------------------------------------------ <<<");
    }

    public static void printUsage(PrintStream ps) {
	ps.println("MANDATORY PARAMETERS:");
	ps.println("\t-instance\tName of instance");
	ps.println("\t-organism\tName of organism");
	ps.println();
	ps.println("OPTIONAL PARAMETERS:");
	ps.println("\t-contigs\tDisplay contigs with these IDs");
	ps.println("\t-project\tDisplay contigs from this project");
	ps.println();
	ps.println("JAVA OPTIONS:");
	ps.println("\tverbose\t\tProduce verbose output (boolean, default false)");
	ps.println("\tmappingOption\tOne of noMapping (default), basicMapping or fullMapping");
	ps.println("\tconsensusOption\tOne of noConsensus (default) or consensus");
	ps.println("\tlogfile\t\tName of optional logging file");
	ps.println("\tdisplayContig\tShow full contig info (boolean, default false)");
    }
}
