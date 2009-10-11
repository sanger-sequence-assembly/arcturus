package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.CloneManager;

public class TestCloneManager {
	public static void main(String args[]) {
		System.out.println("TestCloneManager");
		System.out.println("================");
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

			adb.preload(ArcturusDatabase.CLONE);

			System.out.println("Looking up clone " + objectname + " by name");
			System.out.println();

			Clone clone = adb.getCloneByName(objectname);

			if (clone == null)
				System.out.println("*** FAILED ***");
			else
				System.out.println(clone);

			System.out.println();

			System.out.println("Looking up clone 6 by ID");
			System.out.println();

			clone = adb.getCloneByID(6);

			if (clone == null)
				System.out.println("*** FAILED ***");
			else
				System.out.println(clone);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
