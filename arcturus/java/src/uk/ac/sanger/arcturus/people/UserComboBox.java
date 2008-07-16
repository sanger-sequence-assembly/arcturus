package uk.ac.sanger.arcturus.people;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class UserComboBox extends javax.swing.JComboBox {
	public UserComboBox(ArcturusDatabase adb) {
		Person[] people = null;

		try {
			people = adb.getAllUsers();
		} catch (SQLException e) {
			Arcturus.logSevere("Failed to get list of users", e);
		}

		for (int i = 0; i < people.length; i++)
			addItem(people[i]);

		Person nobody = PeopleManager.findPerson("nobody");

		addItem(nobody);

		setMaximumRowCount(getItemCount());
	}
}
