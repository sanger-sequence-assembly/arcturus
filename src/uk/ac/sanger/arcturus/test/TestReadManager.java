package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;
import javax.naming.Context;

public class TestReadManager {
	private static long lasttime;

	public static void main(String args[]) {
		lasttime = System.currentTimeMillis();

		System.out.println("TestReadManager");
		System.out.println("===============");
		System.out.println();

		String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

		Properties props = new Properties();

		Properties env = System.getProperties();

		props.put(Context.INITIAL_CONTEXT_FACTORY, env
				.get(Context.INITIAL_CONTEXT_FACTORY));
		props.put(Context.PROVIDER_URL, ldapURL);

		String instance = null;
		String organism = null;
		String objectname = null;

		switch (args.length) {
			case 0:
			case 1:
				System.out
						.println("Argument(s) missing: [instance] organism objectname");
				System.exit(1);
				break;

			case 2:
				instance = "dev";
				organism = args[0];
				objectname = args[1];
				break;

			default:
				instance = args[0];
				organism = args[1];
				objectname = args[2];
				break;
		}

		try {
			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();

			ArcturusInstance ai = new ArcturusInstance(props, instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			report();

			System.out.println("Finding a CloneManager");
			System.out.println();

			CloneManager cmgr = adb.getCloneManager();

			System.out.println("Pre-loading all clones");
			System.out.println();

			cmgr.preloadAllClones();

			report();

			System.out.println("Finding a LigationManager");
			System.out.println();

			LigationManager lmgr = adb.getLigationManager();

			System.out.println("Pre-loading all ligations");
			System.out.println();

			lmgr.preloadAllLigations();

			report();

			System.out.println("Finding a TemplateManager");
			System.out.println();

			TemplateManager tmgr = adb.getTemplateManager();

			System.out.println("Pre-loading all templates");
			System.out.println();

			tmgr.preloadAllTemplates();

			report();

			System.out.println("Finding a ReadManager");
			System.out.println();

			ReadManager rmgr = adb.getReadManager();

			System.out.println("Pre-loading all reads");
			System.out.println();

			rmgr.preloadAllReads();

			report();

			System.out.println("Looking up read " + objectname + " by name");
			System.out.println();

			Read read = rmgr.getReadByName(objectname);

			if (read == null)
				System.out.println("*** FAILED ***");
			else {
				System.out.println(read);
				System.out.println("    " + read.getTemplate());
				System.out.println("        "
						+ read.getTemplate().getLigation());
				System.out.println("            "
						+ read.getTemplate().getLigation().getClone());
			}

			System.out.println();

			System.out.println("Looking up read 6 by ID");
			System.out.println();

			read = rmgr.getReadByID(6);

			if (read == null)
				System.out.println("*** FAILED ***");
			else {
				System.out.println(read);
				System.out.println("    " + read.getTemplate());
				System.out.println("        "
						+ read.getTemplate().getLigation());
				System.out.println("            "
						+ read.getTemplate().getLigation().getClone());
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public static void report() {
		long timenow = System.currentTimeMillis();

		System.out.println("******************** REPORT *******************");
		System.out.println("Time: " + (timenow - lasttime));

		lasttime = timenow;

		Runtime runtime = Runtime.getRuntime();

		System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()
				/ 1024 + "/" + runtime.totalMemory() / 1024);
		System.out.println("************************************************");
		System.out.println();
	}
}
