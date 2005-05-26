import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import org.apache.log4j.*;

import java.util.*;
import java.io.*;

import javax.naming.Context;

public class TestContigManager2 {
    private static long lasttime;
    private static Runtime runtime = Runtime.getRuntime();

    public static void main(String args[]) {
	lasttime = System.currentTimeMillis();

	System.err.println("Creating a logger ...");
	Logger logger = Logger.getLogger(TestContigManager.class);
	logger.setLevel(Level.DEBUG);
	System.err.println("Logger is class=" + logger.getClass().getName() + ", name=" + logger.getName() +
			   ", level=" + logger.getLevel());

	System.out.println("TestContigManager2");
	System.out.println("==================");
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

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-instance"))
		instance = args[++i];

	    if (args[i].equalsIgnoreCase("-organism"))
		organism = args[++i];
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

	    adb.setLogger(logger);

	    report();

	    BufferedReader stdin = new BufferedReader(new InputStreamReader(System.in));

	    String line = null;

	    while (true) {
		System.out.print(">");

		line = stdin.readLine();

		if (line == null)
		    System.exit(0);

		String[] words = tokenise(line);

		if (words.length == 0)
		    continue;

		lasttime = System.currentTimeMillis();

		String verb = words[0];

		if (verb.equalsIgnoreCase("preload")) {
		    if (words.length < 2) {
			System.out.println("The preload command requires one or more objects");
		    } else {
			for (int i = 1; i < words.length; i++) {
			    if (words[i].equalsIgnoreCase("clones")) {
				adb.preloadAllClones();
				report();
			    } else if (words[i].equalsIgnoreCase("ligations")) {
				adb.preloadAllLigations();
				report();
			    } else if (words[i].equalsIgnoreCase("templates")) {
				adb.preloadAllTemplates();
				report();
			    } else if (words[i].equalsIgnoreCase("reads")) {
				adb.preloadAllReads();
				report();
			    } else
				System.out.println("Object \"" + words[i] + "\" not recognised");
			}
		    }
		} else if (verb.equalsIgnoreCase("contig")) {
		    if (words.length < 2) {
			System.out.println("The contig command requires at least a contig ID");
		    } else {
			int contig_id = Integer.parseInt(words[1]);

			if (contig_id > 0) {
			    int consensusOption = ArcturusDatabase.CONTIG_NO_CONSENSUS;
			    int mappingOption = ArcturusDatabase.CONTIG_BASIC_MAPPING;

			    for (int i = 2; i < words.length; i++) {
				if (words[i].equalsIgnoreCase("consensus"))
				    consensusOption = ArcturusDatabase.CONTIG_CONSENSUS;
				else if (words[i].equalsIgnoreCase("nomapping"))
				    mappingOption = ArcturusDatabase.CONTIG_NO_MAPPING;
				else if (words[i].equalsIgnoreCase("fullmapping"))
				    mappingOption = ArcturusDatabase.CONTIG_FULL_MAPPING;
				else
				    System.out.println("Unknown option: \"" + words[i] + "\"");
			    }

			    Contig contig = adb.getContigByID(contig_id, consensusOption, mappingOption);

			    if (contig == null)
				System.out.println("*** FAILED ***");
			    else {
				System.out.println(contig);
				System.out.println("  LENGTH:  " + contig.getLength());
				System.out.println("  READS:   " + contig.getReadCount());
				java.util.Date updated = contig.getUpdated();
				System.out.println("  UPDATED: " + updated);
			    }
			} else {
			    System.out.println("Invalid contig ID: \"" + words[1] + "\"");
			}

			report();
		    }
		} else if (verb.equalsIgnoreCase("quit") || verb.equalsIgnoreCase("exit"))
		    System.exit(0);
	    }
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    public static String[] tokenise(String str) {
	StringTokenizer tok = new StringTokenizer(str);

	int ntokens = tok.countTokens();

	String[] tokens = new String[ntokens];

	for (int i = 0; i < ntokens && tok.hasMoreTokens(); i++)
	    tokens[i] = tok.nextToken();

	return tokens;
    }

    public static void report() {
	long timenow = System.currentTimeMillis();

	System.out.println("******************** REPORT ********************");
	System.out.println("Time: " + (timenow - lasttime));

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

	byte[] dna = contig.getDNA();

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
	} else {
	    ps.println("CONSENSUS WAS NULL");
	}

	byte[] qual = contig.getQuality();

	if (qual != null) {
	    for (int i = 0; i < qual.length; i++)
		ps.print(" " + (int)qual[i]);

	    ps.println();
	} else {
	    ps.println("QUALITY WAS NULL");
	}

	ps.println(">>> ------------------------------------------------------------------ <<<");
    }

    public static void printUsage(PrintStream ps) {
	ps.println("MANDATORY PARAMETERS:");
	ps.println("\t-instance\tName of instance");
	ps.println("\t-organism\tName of organism");
    }
}
