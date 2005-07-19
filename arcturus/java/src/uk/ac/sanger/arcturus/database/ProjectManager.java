package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

import java.sql.*;
import java.util.*;

/**
 * This class manages Project objects.
 */

public class ProjectManager extends AbstractManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByID = new HashMap();
    private PreparedStatement pstmtByID;
    private PreparedStatement pstmtByName;
    private PreparedStatement pstmtSetAssemblyForProject;
    private PreparedStatement pstmtProjectSummary;

    /**
     * Creates a new ContigManager to provide contig management
     * services to an ArcturusDatabase object.
     */

    public ProjectManager(ArcturusDatabase adb) throws SQLException {
	this.adb = adb;

	conn = adb.getConnection();

	String query = "select assembly_id,name,updated,owner,locked,created,creator from PROJECT where project_id = ?";
	pstmtByID = conn.prepareStatement(query);

	query = "select project_id,updated,owner,locked,created,creator from PROJECT where assembly_id = ? and name = ?";
	pstmtByName = conn.prepareStatement(query);

	query = "update PROJECT set assembly_id = ? where project_id = ?";
	pstmtSetAssemblyForProject = conn.prepareStatement(query);

	query = "select count(*),sum(nreads),sum(length),round(avg(length)),round(std(length)),max(length) from " +
	    " CONTIG left join C2CMAPPING on CONTIG.contig_id = C2CMAPPING.parent_id" +
	    " where C2CMAPPING.parent_id is null " +
	    " and project_id = ? and length >= ?";
	pstmtProjectSummary = conn.prepareStatement(query);

    }

    public void clearCache() {
	hashByID.clear();
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

	    Assembly assembly = adb.getAssemblyByID(assembly_id);

	    project = createAndRegisterNewProject(id, assembly, name, updated, owner, locked, created, creator);
	}

	rs.close();

	return project;
    }

    public Project getProjectByName(Assembly assembly, String name) throws SQLException {
	int assembly_id = assembly.getID();

	pstmtByName.setInt(1, assembly_id);
	pstmtByName.setString(2, name);

	ResultSet rs = pstmtByName.executeQuery();

	Project project = null;

	if (rs.next()) {
	    int project_id = rs.getInt(1);

	    project = (Project)hashByID.get(new Integer(project_id));

	    if (project == null) {
		java.util.Date updated = rs.getTimestamp(2);
		String owner = rs.getString(3);
		java.util.Date locked = rs.getTimestamp(4);
		java.util.Date created = rs.getTimestamp(5);
		String creator = rs.getString(6);
		
		project = createAndRegisterNewProject(project_id, assembly, name, updated, owner, locked, created, creator);
	    }
	}

	rs.close();

	return project;
    }

    private Project createAndRegisterNewProject(int id, Assembly assembly, String name, java.util.Date updated, String owner,
						java.util.Date locked, java.util.Date created, String creator) {
	Project project = new Project(id, assembly, name, updated, owner, locked, created, creator, adb);

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

	    Assembly assembly = adb.getAssemblyByID(assembly_id);

	    Project project = (Project)hashByID.get(new Integer(id));

	    if (project == null)
		createAndRegisterNewProject(id, assembly, name, updated, owner, locked, created, creator);
	    else {
		project.setAssembly(assembly);
		project.setName(name);
		project.setUpdated(updated);
		project.setOwner(owner);
		project.setLocked(locked);
		project.setCreated(created);
		project.setCreator(creator);
	    }
	}

	rs.close();
	stmt.close();
    }

    public Set getAllProjects() {
	return new HashSet(hashByID.values());
    }

    public void refreshProject(Project project) throws SQLException {
	int id = project.getID();

	pstmtByID.setInt(1, id);
	ResultSet rs = pstmtByID.executeQuery();

	if (rs.next()) {
	    int assembly_id = rs.getInt(1);
	    String name = rs.getString(2);
	    java.util.Date updated = rs.getTimestamp(3);
	    String owner = rs.getString(4);
	    java.util.Date locked = rs.getTimestamp(5);
	    java.util.Date created = rs.getTimestamp(6);
	    String creator = rs.getString(7);

	    Assembly assembly = adb.getAssemblyByID(assembly_id);

	    project.setAssembly(assembly);
	    project.setName(name);
	    project.setUpdated(updated);
	    project.setOwner(owner);
	    project.setLocked(locked);
	    project.setCreated(created);
	    project.setCreator(creator);
	}

	rs.close();
    }

    public void refreshAllProjects() throws SQLException {
	preloadAllProjects();
    }

    public void setAssemblyForProject(Project project, Assembly assembly) throws SQLException {
	if (project != null && assembly != null) {
	    int project_id = project.getID();
	    int assembly_id = assembly.getID();

	    pstmtSetAssemblyForProject.setInt(1, assembly_id);
	    pstmtSetAssemblyForProject.setInt(2, project_id);

	    int rows = pstmtSetAssemblyForProject.executeUpdate();
	}
    }

    public void getProjectSummary(Project project, int minlen, ProjectSummary summary) throws SQLException {
	int project_id = project.getID();

	pstmtProjectSummary.setInt(1, project_id);
	pstmtProjectSummary.setInt(2, minlen);

	ResultSet rs = pstmtProjectSummary.executeQuery();

	if (rs.next()) {
	    summary.setNumberOfContigs(rs.getInt(1));
	    summary.setNumberOfReads(rs.getInt(2));
	    summary.setTotalConsensusLength(rs.getInt(3));
	    summary.setMeanConsensusLength(rs.getInt(4));
	    summary.setSigmaConsensusLength(rs.getInt(5));
	    summary.setMaximumConsensusLength(rs.getInt(6));
	} else
	    summary.reset();

	rs.close();
    }

    public void getProjectSummary(Project project, ProjectSummary summary) throws SQLException {
	getProjectSummary(project, 0, summary);
    }

    public ProjectSummary getProjectSummary(Project project, int minlen) throws SQLException {
	ProjectSummary summary = new ProjectSummary();

	getProjectSummary(project, minlen, summary);

	return summary;
    }

    public ProjectSummary getProjectSummary(Project project) throws SQLException {
	return getProjectSummary(project, 0);
    }
}
