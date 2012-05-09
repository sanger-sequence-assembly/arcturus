package uk.ac.sanger.arcturus.gui;

import java.util.prefs.Preferences;

public class SetProjectColour {
	public static void main(String[] args) {
		if (args.length != 3) {
			System.err.println("Arguments: assembly project colour");
			System.exit(1);
		}

		String assembly = args[0];
		String project = args[1];

		Integer intcol = Integer.decode(args[2]);

		if (intcol == null) {
			System.err.println("Error -- failed to decode \"" + args[2]
					+ "\" as an integer");
			System.exit(2);
		}

		int icol = intcol.intValue();

		Preferences prefs = Preferences
				.userNodeForPackage(SetProjectColour.class);

		prefs = prefs.node(assembly);
		prefs = prefs.node(project);

		prefs.putInt("colour", icol);
	}
}
