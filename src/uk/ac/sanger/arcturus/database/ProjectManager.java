package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.*;

import java.sql.*;
import java.util.*;

/**
 * This class manages Project objects.
 */

public class ProjectManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByID;
    private PreparedStatement pstmtByID;

    /**
     * Creates a new ContigManager to provide contig management
     * services to an ArcturusDatabase object.
     */

    public ProjectManager(ArcturusDatabase adb) throws SQLException {
	this.adb = adb;

	conn = adb.getConnection();

	String query = "select assembly_id,name,updated,owner,locked,created,creator from PROJECT where project_id = ?";
	pstmtByID = conn.prepareStatement(query);
    }


    public Project getProjectByID(int id) throws SQLException {
	return getProjectByID(id, true);
    }

    public Project getProjectByID(int id, boolean autoload) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	if (obj == null)
	    return autoload ? loadProjectByID(id) : null;

	Project project = (Project)obj;

	return project;
    }

    private Project loadProjectByID(int id) throws SQLException {
	pstmtByID.setInt(1, id);
	ResultSet rs = pstmtByID.executeQuery();

	Project project = null;

	if (rs.next()) {
	    int assembly_id = rs.getInt(1);
	    String name = rs.getString(2);
	    java.util.Date updated = rs.getTimestamp(3);
	    String owner = rs.getString(4);
	    java.util.Date locked = rs.getTimestamp(5);
	    java.util.Date created = rs.getTimestamp(6);
	    String creator = rs.getString(7);

	    project = createAndRegisterNewProject(id, assembly_id, name, updated, owner, locked, created, creator);
	}

	rs.close();

	return project;
    }

    private Project createAndRegisterNewProject(int id, int assembly_id, String name, java.util.Date updated, String owner,
						java.util.Date locked, java.util.Date created, String creator) {
	Project project = new Project(id, assembly_id, name, updated, owner, locked, created, creator, adb);

	registerNewProject(project);

	return project;
    }

    private void registerNewProject(Project project) {
	hashByID.put(new Integer(project.getID()), project);
    }

    public void preloadAllProjects() throws SQLException {
	String query = "select project_id,assembly_id,name,updated,owner,locked,created,creator from PROJECT";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int id = rs.getInt(1);
	    int assembly_id = rs.getInt(2);
	    String name = rs.getString(3);
	    java.util.Date updated = rs.getTimestamp(4);
	    String owner = rs.getString(5);
	    java.util.Date locked = rs.getTimestamp(6);
	    java.util.Date created = rs.getTimestamp(7);
	    String creator = rs.getString(8);

	    Project project = createAndRegisterNewProject(id, assembly_id, name, updated, owner, locked, created, creator);
	}

	rs.close();
	stmt.close();
    }

    public Vector getAllProjects() {
	return new Vector(hashByID.values());
    }
}
