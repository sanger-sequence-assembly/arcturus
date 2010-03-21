package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.CloneManager;
import uk.ac.sanger.arcturus.jdbc.LigationManager;
import uk.ac.sanger.arcturus.jdbc.TemplateManager;

public class TestTemplateManager {
	public static void main(String args[]) {
		System.out.println("TestTemplateManager");
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

			adb.preload(ArcturusDatabase.CLONE);

			System.out.println("Pre-loading all ligations");
			System.out.println();

			adb.preload(ArcturusDatabase.LIGATION);

			System.out.println("Pre-loading all templates");
			System.out.println();

			adb.preload(ArcturusDatabase.TEMPLATE);

			System.out
					.println("Looking up template " + objectname + " by name");
			System.out.println();

			Template template = adb.getTemplateByName(objectname);

			if (template == null)
				System.out.println("*** FAILED ***");
			else {
				System.out.println(template);
				System.out.println("    " + template.getLigation());
				System.out.println("        "
						+ template.getLigation().getClone());
			}

			System.out.println();

			System.out.println("Looking up template 6 by ID");
			System.out.println();

			template = adb.getTemplateByID(6);

			if (template == null)
				System.out.println("*** FAILED ***");
			else {
				System.out.println(template);
				System.out.println("    " + template.getLigation());
				System.out.println("        "
						+ template.getLigation().getClone());
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
