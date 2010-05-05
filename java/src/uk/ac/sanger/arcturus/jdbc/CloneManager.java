package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

/**
 * This class manages Clone objects.
 */

public class CloneManager extends AbstractManager {
	private ArcturusDatabase adb;
	private HashMap<Integer, Clone> hashByID;
	private HashMap<String, Clone> hashByName;
	private PreparedStatement pstmtByID, pstmtByName, pstmtInsertNewClone;
	
	private static final String GET_CLONE_BY_ID = "select name from CLONE where clone_id = ?";
	
	private static final String GET_CLONE_BY_NAME = "select clone_id from CLONE where name = ?";
	
	private static final String PUT_CLONE = "insert into CLONE (name) values (?)";

	/**
	 * Creates a new CloneManager to provide clone management services to an
	 * ArcturusDatabase object.
	 * @throws ArcturusDatabaseException 
	 */

	public CloneManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;

		hashByID = new HashMap<Integer, Clone>();
		hashByName = new HashMap<String, Clone>();

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the clone manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		pstmtByID = conn.prepareStatement(GET_CLONE_BY_ID);

		pstmtByName = conn.prepareStatement(GET_CLONE_BY_NAME);
		
		pstmtInsertNewClone = conn.prepareStatement(PUT_CLONE, Statement.RETURN_GENERATED_KEYS);
	}

	public void clearCache() {
		hashByID.clear();
		hashByName.clear();
	}

	public Clone getCloneByName(String name) throws ArcturusDatabaseException {
		Clone clone = hashByName.get(name);

		try {
			if (clone == null)
				clone = loadCloneByName(name);
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get clone by name=\"" + name + "\"", conn, this);
		}
		
		return clone;
	}

	public Clone getCloneByID(int id) throws ArcturusDatabaseException {
		Clone clone = hashByID.get(new Integer(id));

		try {
			if (clone == null)
				clone = loadCloneByID(id);
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get clone by ID=" + id, conn, this);
		}
		
		return clone;
	}
	
	public Clone findOrCreateClone(String name) throws ArcturusDatabaseException {
		try {
			Clone clone = getCloneByName(name);
		
			if (clone != null)
				return clone;
		
			pstmtInsertNewClone.setString(1, name);
			
			int rc = pstmtInsertNewClone.executeUpdate();
			
			if (rc == 1) {
				ResultSet rs = pstmtInsertNewClone.getGeneratedKeys();
				
				int id = rs.next() ? rs.getInt(1) : -1;
				
				rs.close();
				
				if (id > 0)
					return registerNewClone(name, id);
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find or create clone by name=" + name, conn, this);
		}
		
		return null;
	}

	private Clone loadCloneByName(String name) throws SQLException {
		pstmtByName.setString(1, name);
		ResultSet rs = pstmtByName.executeQuery();

		Clone clone = null;

		if (rs.next()) {
			int id = rs.getInt(1);
			clone = registerNewClone(name, id);
		}

		return clone;
	}

	private Clone loadCloneByID(int id) throws SQLException {
		pstmtByID.setInt(1, id);
		ResultSet rs = pstmtByID.executeQuery();

		Clone clone = null;

		if (rs.next()) {
			String name = rs.getString(1);
			clone = registerNewClone(name, id);
		}

		return clone;
	}

	private Clone registerNewClone(String name, int id) {
		Clone clone = new Clone(name, id, adb);

		hashByName.put(name, clone);
		hashByID.put(new Integer(id), clone);

		return clone;
	}

	public void preload() throws ArcturusDatabaseException  {
		String query = "select clone_id, name from CLONE";

		try {
			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int id = rs.getInt(1);
				String name = rs.getString(2);
				registerNewClone(name, id);
			}

			rs.close();
			stmt.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload clones", conn, this);
		}
	}
}
