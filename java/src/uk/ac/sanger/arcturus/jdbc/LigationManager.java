package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

/**
 * This class manages Ligation objects.
 */

public class LigationManager extends AbstractManager {
	private ArcturusDatabase adb;
	private HashMap<Integer, Ligation> hashByID;
	private HashMap<String, Ligation> hashByName;
	private PreparedStatement pstmtByID, pstmtByName;

	/**
	 * Creates a new LigationManager to provide ligation management services to
	 * an ArcturusDatabase object.
	 */

	public LigationManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;

		hashByID = new HashMap<Integer, Ligation>();
		hashByName = new HashMap<String, Ligation>();

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the ligation manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		String query = "select name,clone_id,silow,sihigh from LIGATION where ligation_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select ligation_id,clone_id,silow,sihigh from LIGATION where name = ?";
		pstmtByName = conn.prepareStatement(query);
	}

	public void clearCache() {
		hashByID.clear();
		hashByName.clear();
	}

	public Ligation getLigationByName(String name) throws ArcturusDatabaseException {
		Object obj = hashByName.get(name);

		return (obj == null) ? loadLigationByName(name) : (Ligation) obj;
	}

	public Ligation getLigationByID(int id) throws ArcturusDatabaseException {
		Object obj = hashByID.get(new Integer(id));

		return (obj == null) ? loadLigationByID(id) : (Ligation) obj;
	}

	private Ligation loadLigationByName(String name) throws ArcturusDatabaseException {
		Ligation ligation = null;

		try {
			pstmtByName.setString(1, name);
			ResultSet rs = pstmtByName.executeQuery();

			if (rs.next()) {
				int id = rs.getInt(1);
				int clone_id = rs.getInt(2);
				int silow = rs.getInt(3);
				int sihigh = rs.getInt(4);
				ligation = registerNewLigation(name, id, clone_id, silow,
						sihigh);
			}
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to fetch ligation by name=\"" + name + "\"", conn, this);
		}
		

		return ligation;
	}

	private Ligation loadLigationByID(int id) throws ArcturusDatabaseException {
		Ligation ligation = null;

		try {
			pstmtByID.setInt(1, id);
			ResultSet rs = pstmtByID.executeQuery();

			if (rs.next()) {
				String name = rs.getString(1);
				int clone_id = rs.getInt(2);
				int silow = rs.getInt(3);
				int sihigh = rs.getInt(4);
				ligation = registerNewLigation(name, id, clone_id, silow,
						sihigh);
			}
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to fetch ligation by ID=\"" + id + "\"", conn, this);
		}

		return ligation;
	}

	private Ligation registerNewLigation(String name, int id, int clone_id,
			int silow, int sihigh) throws ArcturusDatabaseException {
		Clone clone = adb.getCloneByID(clone_id);

		Ligation ligation = new Ligation(name, id, clone, silow, sihigh, adb);

		hashByName.put(name, ligation);
		hashByID.put(new Integer(id), ligation);

		return ligation;
	}

	public void preload() throws ArcturusDatabaseException {
		String query = "select ligation_id,name,clone_id,silow,sihigh from LIGATION";

		try {
			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int id = rs.getInt(1);
				String name = rs.getString(2);
				int clone_id = rs.getInt(3);
				int silow = rs.getInt(4);
				int sihigh = rs.getInt(5);
				registerNewLigation(name, id, clone_id, silow, sihigh);
			}

			rs.close();
			stmt.close();
		}catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload ligations", conn, this);
		} 
	}
}
