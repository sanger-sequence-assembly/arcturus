import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.scaffold.*;

import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.zip.DataFormatException;

import javax.naming.Context;

public class TestScaffoldBuilder implements ScaffoldBuilderListener {
    private long lasttime;
    private Runtime runtime = Runtime.getRuntime();
   
    private String instance = null;
    private String organism = null;

    private int flags = ArcturusDatabase.CONTIG_BASIC_DATA | ArcturusDatabase.CONTIG_TAGS;

    private boolean debug = false;
    private boolean lowmem = false;
    private boolean quiet = false;

    private int seedcontigid = -1;
    private int minlen = -1;
    private int puclimit = -1;
    private int minbridges = 2;

    protected ArcturusDatabase adb = null;

    public static void main(String args[]) {
	TestScaffoldBuilder ds = new TestScaffoldBuilder();
	ds.execute(args);
    }

    public void execute(String args[]) {
	lasttime = System.currentTimeMillis();

	System.err.println("TestScaffoldBuilder");
	System.err.println("===================");
	System.err.println();

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase("-instance"))
		instance = args[++i];

	    if (args[i].equalsIgnoreCase("-organism"))
		organism = args[++i];

	    if (args[i].equalsIgnoreCase("-minlen"))
		minlen = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-puclimit"))
		puclimit = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-minbridges"))
		minbridges = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-contig"))
		seedcontigid = Integer.parseInt(args[++i]);

	    if (args[i].equalsIgnoreCase("-debug"))
		debug = true;

	    if (args[i].equalsIgnoreCase("-lowmem"))
		lowmem = true;

	    if (args[i].equalsIgnoreCase("-quiet"))
		quiet = true;
	}

	if (instance == null || organism == null || seedcontigid == 0) {
	    printUsage(System.err);
	    System.exit(1);
	}

	try {
	    System.err.println("Creating an ArcturusInstance for " + instance);
	    System.err.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.err.println("Creating an ArcturusDatabase for " + organism);
	    System.err.println();

	    adb = ai.findArcturusDatabase(organism);

	    if (lowmem)
		adb.getSequenceManager().setCacheing(false);

	    ScaffoldBuilder sb = new ScaffoldBuilder(adb);

	    if (minlen >= 0)
		sb.setMinimumLength(minlen);

	    if (puclimit >= 0)
		sb.setPucLimit(puclimit);

	    if (minbridges > 0)
		sb.setMinimumBridges(minbridges);

	    Set bs = sb.createScaffold(seedcontigid, this);

	    System.out.println("Bridge Set:" + bs);
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }

    public void scaffoldUpdate(ScaffoldEvent event) {
	System.err.println("ScaffoldEvent[mode=" + event.getMode() + ", description=" +
			   event.getDescription() + "]");
    }

    protected void printUsage(PrintStream ps) {
	ps.println("MANDATORY PARAMETERS:");
	ps.println("\t-instance\tName of instance");
	ps.println("\t-organism\tName of organism");
	ps.println("\t-contig\t\tContig ID");
	ps.println();
	ps.println("OPTIONAL PARAMETERS");
	ps.println("\t-minlen\t\tMinimum contig length");
	ps.println("\t-puclimit\tAssumed maximum pUC insert size");
	ps.println("\t-minbridges\tMinimum number of pUC bridges for a valid link");
	ps.println();
	ps.println("OPTIONS");
	String[] options = {"-debug", "-lowmem", "-quiet"};
	for (int i = 0; i < options.length; i++)
	    ps.println("\t" + options[i]);
    }
}
