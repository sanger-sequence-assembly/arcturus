package uk.ac.sanger.arcturus.people;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class UserComboBox extends javax.swing.JComboBox {
	public UserComboBox(ArcturusDatabase adb) throws ArcturusDatabaseException {
		Person[] people = null;

		people = adb.getAllUsers(false);

		for (int i = 0; i < people.length; i++)
			addItem(people[i]);

		Person nobody = adb.findUser(Person.NOBODY);

		addItem(nobody);
		
		setMaximumRowCount(getItemCount());
	}
}
