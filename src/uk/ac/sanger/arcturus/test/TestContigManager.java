import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;
import javax.naming.Context;

public class TestContigManager {
    private static long lasttime;

    public static void main(String args[]) {
	lasttime = System.currentTimeMillis();

	boolean verbose = Boolean.getBoolean("verbose");
	boolean fullSequence = Boolean.getBoolean("fullSequence");
	boolean fullContig = Boolean.getBoolean("fullContig");

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
	String objectname = null;

	if (args.length < 3) {
	    System.out.println("Argument(s) missing: instance organism contigrange(s)");
	    System.exit(1);
	}

	instance = args[0];
	organism = args[1];

	try {
	    System.out.println("Creating an ArcturusInstance for " + instance);
	    System.out.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.out.println("Creating an ArcturusDatabase for " + organism);
	    System.out.println();

	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

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

	    System.out.println("Looking up contigs by ID");
	    System.out.println();

	    int ranges[][] = parseRanges(args[2]);

	    for (int i = 0; i < ranges.length; i++) {
		int firstid = ranges[i][0];
		int lastid = ranges[i][1];

		try {
		    for (int id = firstid; id <= lastid; id++) {
			if (verbose) {
			    System.out.println();
			    System.out.println("LOOKING UP CONTIG[" + id + "]");
			}

			Contig contig = fullContig ?
			    adb.getFullContigByID(id) :
			    adb.getContigByID(id);

			if (verbose) {
			    if (contig == null)
				System.out.println("*** FAILED ***");
			    else {
				System.out.println(contig);
			    }
			}
		    }
		}
		catch (NumberFormatException nfe) {
		    System.err.println("Error parsing \"" + args[i] + "\" as an integer.");
		}
	    }

	    report();
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

	System.out.println("******************** REPORT *******************");
	System.out.println("Time: " + (timenow - lasttime));

	lasttime = timenow;

	Runtime runtime = Runtime.getRuntime();

	System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()/1024 + "/" + runtime.totalMemory()/1024);
	System.out.println("************************************************");
	System.out.println();
    }
}
