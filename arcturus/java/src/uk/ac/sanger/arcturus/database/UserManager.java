package uk.ac.sanger.arcturus.database;

import java.sql.*;
import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.people.Person;

public class UserManager extends AbstractManager {
	private Connection conn;
	private PreparedStatement pstmtRoleByName, pstmtPrivilegesByName;
	private PreparedStatement pstmtHasPrivilege;
	private Map<String, String> roleCache = new HashMap<String, String>();

	/**
	 * Creates a new UserManager to provide user management services to
	 * an ArcturusDatabase object.
	 * 
	 * @param adb
	 *            the ArcturusDatabase object to which this manager belongs.
	 */

	public UserManager(ArcturusDatabase adb) throws SQLException {
		conn = adb.getConnection();

		String query = "select role from USER where username = ?";
		pstmtRoleByName = conn.prepareStatement(query);

		query = "select privilege from PRIVILEGE where username = ?";
		pstmtPrivilegesByName = conn.prepareStatement(query);
		
		query = "select count(*) from PRIVILEGE where username = ? and privilege = ?";
		pstmtHasPrivilege = conn.prepareStatement(query);
	}

	public void clearCache() {
		roleCache.clear();
	}

	public String getRoleForUser(String username) {
		if (username == null)
			return null;
		
		String role = roleCache.get(username);
		
		if (role != null)
			return role;
		
		try {
			pstmtRoleByName.setString(1, username);
		
			ResultSet rs = pstmtRoleByName.executeQuery();
		
			role = rs.next() ? rs.getString(1): null;
		
			rs.close();
		}
		catch (SQLException e) {
			role = "unknown";
			Arcturus.logSevere("Failed to get role for " + username, e);
		}
		
		roleCache.put(username, role);
		
		return role;
	}
	
	public String getRoleForUser(Person person) {
		if (person == null)
			return null;
		
		return getRoleForUser(person.getUID());
	}
	
	public String[] getPrivilegesForUser(String username) throws SQLException {
		if (username == null)
			return null;
		
		pstmtPrivilegesByName.setString(1, username);
		
		ResultSet rs = pstmtPrivilegesByName.executeQuery();
		
		Vector<String> rolesv = new Vector<String>();
		
		while (rs.next())
			rolesv.add(rs.getString(1));
		
		String[] roles = rolesv.size() > 0 ? (String[])rolesv.toArray(new String[0]) : null;
		
		rs.close();
		
		return roles;
	}
	
	public String[] getPrivilegesForUser(Person person) throws SQLException {
		if (person == null)
			return null;
		
		return getPrivilegesForUser(person.getUID());
	}
	
	public boolean hasPrivilege(String username, String privilege) throws SQLException {
		if (username == null || privilege == null)
			return false;
		
		pstmtHasPrivilege.setString(1, username);
		pstmtHasPrivilege.setString(2, privilege);
		
		ResultSet rs = pstmtHasPrivilege.executeQuery();
		
		boolean cando = rs.next() && rs.getInt(1) > 0;
		
		rs.close();
		
		return cando;
	}
	
	public boolean hasPrivilege(Person person, String privilege) throws SQLException {
		if (person == null || privilege == null)
			return false;
		
		return hasPrivilege(person.getUID(), privilege);
	}
	
	public boolean hasFullPrivileges(Person person) throws SQLException {
		if (person == null)
			return false;

		String role = null;

		role = getRoleForUser(person);

		if (role == null)
			return false;

		return role.equalsIgnoreCase("team leader")
				|| role.equalsIgnoreCase("administrator")
				|| role.equalsIgnoreCase("superuser");
	}
}
