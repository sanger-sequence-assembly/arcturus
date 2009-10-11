package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.CloneManager;
import uk.ac.sanger.arcturus.jdbc.LigationManager;
import uk.ac.sanger.arcturus.jdbc.ReadManager;
import uk.ac.sanger.arcturus.jdbc.TemplateManager;

public class TestReadManager {
	private static long lasttime;

	public static void main(String args[]) {
		lasttime = System.currentTimeMillis();

		System.out.println("TestReadManager");
		System.out.println("===============");
		System.out.println();

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

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			report();

			System.out.println("Pre-loading all clones");
			System.out.println();

			adb.preload(ArcturusDatabase.CLONE);

			report();

			System.out.println("Pre-loading all ligations");
			System.out.println();

			adb.preload(ArcturusDatabase.LIGATION);

			report();

			System.out.println("Pre-loading all templates");
			System.out.println();

			adb.preload(ArcturusDatabase.TEMPLATE);

			report();

			System.out.println("Pre-loading all reads");
			System.out.println();

			adb.preload(ArcturusDatabase.CLONE);

			report();

			System.out.println("Looking up read " + objectname + " by name");
			System.out.println();

			Read read = adb.getReadByName(objectname);

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

			read = adb.getReadByID(6);

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
