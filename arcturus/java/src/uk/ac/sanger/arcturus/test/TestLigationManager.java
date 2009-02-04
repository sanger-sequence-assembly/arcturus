package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.CloneManager;
import uk.ac.sanger.arcturus.jdbc.LigationManager;

public class TestLigationManager {
	public static void main(String args[]) {
		System.out.println("TestLigationManager");
		System.out.println("===================");
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

			System.out.println("Pre-loading all clones");
			System.out.println();

			adb.preloadAllClones();

			System.out.println("Pre-loading all ligations");
			System.out.println();

			adb.preloadAllLigations();

			System.out
					.println("Looking up ligation " + objectname + " by name");
			System.out.println();

			Ligation ligation = adb.getLigationByName(objectname);

			if (ligation == null)
				System.out.println("*** FAILED ***");
			else {
				System.out.println(ligation);
				System.out.println("    " + ligation.getClone());
			}

			System.out.println();

			System.out.println("Looking up ligation 6 by ID");
			System.out.println();

			ligation = adb.getLigationByID(6);

			if (ligation == null)
				System.out.println("*** FAILED ***");
			else {
				System.out.println(ligation);
				System.out.println("    " + ligation.getClone());
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
