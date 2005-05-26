import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;
import java.io.*;

import javax.naming.Context;

public class TestContigManager3 {
    private static long lasttime;
    private static Runtime runtime = Runtime.getRuntime();

    public static void main(String args[]) {
	lasttime = System.currentTimeMillis();

	System.err.println("TestContigManager3");
	System.err.println("==================");
	System.err.println();

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
	    System.err.println("Creating an ArcturusInstance for " + instance);
	    System.err.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.err.println("Creating an ArcturusDatabase for " + organism);
	    System.err.println();

	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	    java.sql.Connection conn = adb.getConnection();

	    Manager manager = new Manager(conn);

	    MyListener listener = new MyListener();

	    manager.addManagerEventListener(listener);

	    BufferedReader stdin = new BufferedReader(new InputStreamReader(System.in));

	    String line = null;
	    Contig contig = null;
	    CAFWriter cafWriter = new CAFWriter(System.out);

	    while (true) {
		System.err.print(">");

		line = stdin.readLine();

		if (line == null)
		    System.exit(0);

		String[] words = tokenise(line);
		
		for (int i = 0; i < words.length; i++) {
		    if (words[i].equalsIgnoreCase("quit") || words[i].equalsIgnoreCase("exit"))
			System.exit(0);

		    if (words[i].equalsIgnoreCase("caf")) {
			if (contig != null)
			    cafWriter.writeContig(contig);
		    } else {
			int contig_id = Integer.parseInt(words[i]);

			long clockStart = System.currentTimeMillis();

			contig = manager.loadContigByID(contig_id);

			long clockStop = System.currentTimeMillis() - clockStart;
			System.err.println("TOTAL TIME: " + clockStop + " ms");
			System.err.println();
		    }
		}
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

    public static void printUsage(PrintStream ps) {
	ps.println("MANDATORY PARAMETERS:");
	ps.println("\t-instance\tName of instance");
	ps.println("\t-organism\tName of organism");
    }
}

class MyListener implements ManagerEventListener {
    private long clock;
    private Runtime runtime = Runtime.getRuntime();

    public void managerUpdate(ManagerEvent event) {
	switch (event.getState()) {
	case ManagerEvent.START:
	    System.err.println("START -- " + event.getMessage());
	    clock = System.currentTimeMillis();
	    break;

	case ManagerEvent.WORKING:
	    //System.err.print('.');
	    break;

	case ManagerEvent.END:
	    //System.err.println();
	    clock = System.currentTimeMillis() - clock;
	    System.err.println("END   -- " + clock + " ms");
	    System.err.println("MEM      FREE=" + runtime.freeMemory()/1024 + ", TOTAL=" + runtime.totalMemory()/1024);
	    System.err.println();
	    break;
	}
    }
}
