package uk.ac.sanger.arcturus.jdbc;

import java.sql.*;
import java.util.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.people.role.*;

public class UserManager extends AbstractManager {
	private PreparedStatement pstmtRoleByName;
	private Map<String, Role> roleMap = new HashMap<String, Role>();
	private Map<String, Person> personMap = new HashMap<String, Person>();

	/**
	 * Creates a new UserManager to provide user management services to an
	 * ArcturusDatabase object.
	 * 
	 * @param adb
	 *            the ArcturusDatabase object to which this manager belongs.
	 */

	public UserManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the user manager", conn, adb);
		}

		populateRoleMap();

		getAllUsers(true);
	}
	
	protected void prepareConnection() throws SQLException {
		String query = "select role from USER where username = ?";
		pstmtRoleByName = conn.prepareStatement(query);		
	}

	private void populateRoleMap() {
		roleMap.put("finisher", Finisher.getInstance());
		roleMap.put("coordinator", Coordinator.getInstance());
		roleMap.put("team leader", TeamLeader.getInstance());
		roleMap.put("assembler", Assembler.getInstance());
		roleMap.put("annotator", Annotator.getInstance());
		roleMap.put("administrator", Administrator.getInstance());
	}

	public void clearCache() {
	}
	
	public void preload() throws ArcturusDatabaseException {
		getAllUsers(true);
	}

	protected Role getRoleForRolename(String rolename) {
		return roleMap.get(rolename);
	}

	public Person[] getAllUsers(boolean includeNobody) throws ArcturusDatabaseException {
		String query = "select username,role from USER";
		
		Vector<Person> people = new Vector<Person>();

		try {
		Statement stmt = conn.createStatement();
		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			String username = rs.getString(1);
			String rolename = rs.getString(2);

			Person person = PeopleManager.createPerson(username);

			Role role = getRoleForRolename(rolename);

			person.setRole(role);

			personMap.put(username, person);

			boolean addToList = role != null && !(role instanceof Assembler)
					&& !(role instanceof Annotator);

			if (addToList)
				people.add(person);
		}

		rs.close();
		stmt.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get all users", conn, this);
		}

		if (includeNobody)
			people.add(PeopleManager.createPerson(Person.NOBODY));

		Person[] allusers = (Person[]) people.toArray(new Person[0]);

		Arrays.sort(allusers);

		return allusers;
	}

	public Person findUser(String username) throws ArcturusDatabaseException {
		if (username == null)
			return null;

		Person person = personMap.get(username);

		if (person != null)
			return person;

		person = PeopleManager.createPerson(username);

		try {
			pstmtRoleByName.setString(1, username);

			ResultSet rs = pstmtRoleByName.executeQuery();

			String rolename = rs.next() ? rs.getString(1) : null;

			rs.close();

			Role role = getRoleForRolename(rolename);

			person.setRole(role);
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find user UID=" + username, conn, this);
		}

		personMap.put(username, person);

		return person;
	}

	public Person findMe() throws ArcturusDatabaseException {
		String myUID = PeopleManager.getEffectiveUID();
		return findUser(myUID);
	}

	public boolean isMe(Person person) {
		return person != null
				&& person.getUID().equalsIgnoreCase(PeopleManager.getEffectiveUID());
	}

	public boolean hasFullPrivileges(Person person) {
		if (person == null)
			return false;

		Role role = person.getRole();

		if (role == null)
			return false;

		return role instanceof TeamLeader || role instanceof Coordinator
				|| role instanceof Administrator;
	}

	public boolean hasFullPrivileges() throws ArcturusDatabaseException {
		return hasFullPrivileges(findMe())
				&& !Boolean.getBoolean("minerva.noadmin");
	}

	public boolean isCoordinator(Person person) {
		if (person == null)
			return false;

		Role role = person.getRole();

		if (role == null)
			return false;

		return role instanceof TeamLeader || role instanceof Coordinator
				|| role instanceof Administrator;
	}

	public boolean isCoordinator() throws ArcturusDatabaseException {
		return isCoordinator(findMe())
				&& !Boolean.getBoolean("minerva.noadmin");
	}
}
