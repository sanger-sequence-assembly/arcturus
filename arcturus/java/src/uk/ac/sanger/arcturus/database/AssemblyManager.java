package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.*;

import java.sql.*;
import java.util.*;

/**
 * This class manages Assembly objects.
 */

public class AssemblyManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByID;
    private PreparedStatement pstmtByID;

    /**
     * Creates a new ContigManager to provide contig management
     * services to an ArcturusDatabase object.
     */

    public AssemblyManager(ArcturusDatabase adb) throws SQLException {
	this.adb = adb;

	conn = adb.getConnection();

	String query = "select name,updated,created,creator from ASSEMBLY where assembly_id = ?";
	pstmtByID = conn.prepareStatement(query);
    }


    public Assembly getAssemblyByID(int id) throws SQLException {
	return getAssemblyByID(id, true);
    }

    public Assembly getAssemblyByID(int id, boolean autoload) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	if (obj == null)
	    return autoload ? loadAssemblyByID(id) : null;

	Assembly assembly = (Assembly)obj;

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

	    assembly = createAndRegisterNewAssembly(id, name, updated, created, creator);
	}

	rs.close();

	return assembly;
    }

    private Assembly createAndRegisterNewAssembly(int id, String name, java.util.Date updated,
						  java.util.Date created, String creator) {
	Assembly assembly = new Assembly(id, name, updated, created, creator, adb);

	registerNewAssembly(assembly);

	return assembly;
    }

    void registerNewAssembly(Assembly assembly) {
	hashByID.put(new Integer(assembly.getID()), assembly);
    }

    public void preloadAllAssemblies() throws SQLException {
	String query = "select assembly_id,name,updated,created,creator from ASSEMBLY";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int id = rs.getInt(1);

	    String name = rs.getString(2);
	    java.util.Date updated = rs.getTimestamp(3);
	    java.util.Date created = rs.getTimestamp(4);
	    String creator = rs.getString(5);

	    Assembly assembly = createAndRegisterNewAssembly(id, name, updated, created, creator);
	}

	rs.close();
	stmt.close();
    }

    public Vector getAllAssemblies() {
	return new Vector(hashByID.values());
    }
}
