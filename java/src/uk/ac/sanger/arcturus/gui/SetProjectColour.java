// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
