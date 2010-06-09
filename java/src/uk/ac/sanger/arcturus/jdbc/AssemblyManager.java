package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

/**
 * This class manages Assembly objects.
 */

public class AssemblyManager extends AbstractManager {
	private HashMap<Integer, Assembly> hashByID = new HashMap<Integer, Assembly>();
	private PreparedStatement pstmtByID;
	private PreparedStatement pstmtByName;

	/**
	 * Creates a new ContigManager to provide contig management services to an
	 * ArcturusDatabase object.
	 * @throws ArcturusDatabaseException 
	 */

	public AssemblyManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the assembly manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		String query = "select name,updated,created,creator from ASSEMBLY where assembly_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select assembly_id,updated,created,creator from ASSEMBLY where name = ?";
		pstmtByName = conn.prepareStatement(query);	
	}

	public void clearCache() {
		hashByID.clear();
	}

	public Assembly getAssemblyByID(int id) throws ArcturusDatabaseException  {
		return getAssemblyByID(id, true);
	}

	public Assembly getAssemblyByID(int id, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByID.get(new Integer(id));

		if (obj == null)
			try {
				return autoload ? loadAssemblyByID(id) : null;
			} catch (SQLException e) {
				adb.handleSQLException(e, "Failed to get assembly by ID=" + id, conn, this);
			}

		Assembly assembly = (Assembly) obj;

		return assembly;
	}

	private Assembly loadAssemblyByID(int id) throws SQLException {
		pstmtByID.setInt(1, id);
		ResultSet rs = pstmtByID.executeQuery();

		Assembly assembly = null;

		if (rs.next()) {
			String name = rs.getString(1);
			java.util.Date updated = rs.getTimestamp(2);
			java.util.Date created = rs.getTimestamp(3);
			String creator = rs.getString(4);

			assembly = createAndRegisterNewAssembly(name, id, updated, created,
					creator);
		}

		rs.close();

		return assembly;
	}

	public Assembly getAssemblyByName(String name) throws ArcturusDatabaseException {
		Assembly assembly = null;

		try {
			pstmtByName.setString(1, name);
			ResultSet rs = pstmtByName.executeQuery();

			if (rs.next()) {
				int assembly_id = rs.getInt(1);

				assembly = (Assembly) hashByID.get(new Integer(assembly_id));

				if (assembly == null) {
					java.util.Date updated = rs.getTimestamp(2);
					java.util.Date created = rs.getTimestamp(3);
					String creator = rs.getString(4);

					assembly = createAndRegisterNewAssembly(name, assembly_id,
							updated, created, creator);
				}
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get assembly by name=" + name, conn, this);			
		}

		return assembly;
	}

	private Assembly createAndRegisterNewAssembly(String name, int id,
			java.util.Date updated, java.util.Date created, String creator) {
		Assembly assembly = new Assembly(name, id, updated, created, creator,
				adb);

		registerNewAssembly(assembly);

		return assembly;
	}

	void registerNewAssembly(Assembly assembly) {
		hashByID.put(new Integer(assembly.getID()), assembly);
	}

	public void preload() throws ArcturusDatabaseException {
		try {
			String query = "select assembly_id,name,updated,created,creator from ASSEMBLY";

			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int id = rs.getInt(1);

				String name = rs.getString(2);
				java.util.Date updated = rs.getTimestamp(3);
				java.util.Date created = rs.getTimestamp(4);
				String creator = rs.getString(5);

				Assembly assembly = (Assembly) hashByID.get(new Integer(id));

				if (assembly == null)
					createAndRegisterNewAssembly(name, id, updated, created,
							creator);
				else {
					assembly.setName(name);
					assembly.setUpdated(updated);
					assembly.setCreated(created);
					assembly.setCreator(creator);
				}
			}

			rs.close();
			stmt.close();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to preload assemblies", conn, this);
		}
	}

	public Assembly[] getAllAssemblies() throws ArcturusDatabaseException {
		preload();
		Collection<Assembly> asms = hashByID.values();
		Assembly[] assemblies = (Assembly[]) asms.toArray(new Assembly[0]);
		Arrays.sort(assemblies);
		return assemblies;
	}

	public void refreshAssembly(Assembly assembly)
			throws ArcturusDatabaseException {
		try {
			int id = assembly.getID();

			pstmtByID.setInt(1, id);
			ResultSet rs = pstmtByID.executeQuery();

			if (rs.next()) {
				String name = rs.getString(1);
				java.util.Date updated = rs.getTimestamp(2);
				java.util.Date created = rs.getTimestamp(3);
				String creator = rs.getString(4);

				assembly.setName(name);
				assembly.setUpdated(updated);
				assembly.setCreated(created);
				assembly.setCreator(creator);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to refresh assemblies", conn, this);
		}
	}

	public void refreshAllAssemblies() throws ArcturusDatabaseException {
		preload();
	}

	public String getCacheStatistics() {
		return "ByID: " + hashByID.size();
	}
}
