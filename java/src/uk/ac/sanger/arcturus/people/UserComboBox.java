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

package uk.ac.sanger.arcturus.people;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class UserComboBox extends javax.swing.JComboBox {
	public UserComboBox(ArcturusDatabase adb) {
		Person[] people = null;

		try {
			people = adb.getAllUsers(false);
		} catch (SQLException e) {
			Arcturus.logSevere("Failed to get list of users", e);
		}

		for (int i = 0; i < people.length; i++)
			addItem(people[i]);

		Person nobody = adb.findUser(Person.NOBODY);

		addItem(nobody);
		
		setMaximumRowCount(getItemCount());
	}
}
