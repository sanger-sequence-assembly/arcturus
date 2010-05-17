package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.database.ProjectLockException;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

import java.io.File;
import java.io.IOException;
import java.sql.*;
import java.util.*;

/**
 * This class manages Project objects.
 */

public class ProjectManager extends AbstractManager {
	private HashMap<Integer, Project> hashByID = new HashMap<Integer, Project>();
	private PreparedStatement pstmtByID;
	private PreparedStatement pstmtByName;
	private PreparedStatement pstmtByNameAndAssembly;
	private PreparedStatement pstmtSetAssemblyForProject;
	private PreparedStatement pstmtProjectSummaryByID;
	private PreparedStatement pstmtProjectSummary;
	private PreparedStatement pstmtLastContigTransferOutByID;
	private PreparedStatement pstmtLastContigTransferOut;
	private PreparedStatement pstmtUnlockProject;
	private PreparedStatement pstmtLockProject;
	private PreparedStatement pstmtLockProjectForOwner;
	private PreparedStatement pstmtSetProjectOwner;
	private PreparedStatement pstmtCreateNewProject;
	private PreparedStatement pstmtChangeProjectStatus;

	/**
	 * Creates a new ProjectManager to provide project management services to an
	 * ArcturusDatabase object.
	 */

	public ProjectManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);
	
		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the project manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		String query = "select assembly_id,name,updated,owner,lockdate,lockowner,created,creator,directory,status"
				+ " from PROJECT where project_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select project_id,updated,owner,lockdate,lockowner,created,creator,directory,status"
				+ " from PROJECT where assembly_id = ? and name = ?";
		pstmtByNameAndAssembly = conn.prepareStatement(query);

		query = "select project_id,updated,owner,lockdate,lockowner,created,creator,directory,status"
				+ " from PROJECT where name = ?";
		pstmtByName = conn.prepareStatement(query);

		query = "update PROJECT set assembly_id = ? where project_id = ?";
		pstmtSetAssemblyForProject = conn.prepareStatement(query);

		query = "select count(*),sum(nreads),sum(length),round(avg(length)),round(std(length)),max(length),max(created),max(updated)"
				+ " from CURRENTCONTIGS"
				+ " where project_id = ? and length >= ? and nreads >= ?";
		pstmtProjectSummaryByID = conn.prepareStatement(query);

		query = "select project_id,count(*),sum(nreads),sum(length),round(avg(length)),round(std(length)),max(length),max(created),max(updated)"
				+ " from CURRENTCONTIGS"
				+ " where length >= ? and nreads >= ?"
				+ " group by project_id";
		pstmtProjectSummary = conn.prepareStatement(query);

		query = "select max(closed) from CONTIGTRANSFERREQUEST where old_project_id = ? and status = 'done'";
		pstmtLastContigTransferOutByID = conn.prepareStatement(query);

		query = "select old_project_id,max(closed) from CONTIGTRANSFERREQUEST"
				+ " where status = 'done'" + " group by old_project_id";

		pstmtLastContigTransferOut = conn.prepareStatement(query);

		query = "update PROJECT set lockowner=null,lockdate=null"
				+ " where project_id=? and lockowner is not null";

		pstmtUnlockProject = conn.prepareStatement(query);

		query = "update PROJECT set lockowner=?,lockdate=NOW()"
				+ " where project_id=? and lockowner is null";

		pstmtLockProject = conn.prepareStatement(query);

		query = "update PROJECT set lockowner=owner,lockdate=NOW()"
				+ " where project_id=? and lockowner is null";

		pstmtLockProjectForOwner = conn.prepareStatement(query);

		query = "update PROJECT set owner = ? where project_id = ?";

		pstmtSetProjectOwner = conn.prepareStatement(query);

		query = "insert into PROJECT(assembly_id,name,creator,created,owner,directory)"
				+ "values (?,?,?,NOW(),?,?)";

		pstmtCreateNewProject = conn.prepareStatement(query);
		
		query = "update PROJECT set status = ? where project_id = ?";
		
		pstmtChangeProjectStatus = conn.prepareStatement(query);
	}

	public void clearCache() {
		hashByID.clear();
	}

	public Project getProjectByID(int id) throws ArcturusDatabaseException {
		return getProjectByID(id, true);
	}

	public Project getProjectByID(int id, boolean autoload) throws ArcturusDatabaseException {
		Object obj = hashByID.get(new Integer(id));

		if (obj == null)
			return autoload ? loadProjectByID(id) : null;

		Project project = (Project) obj;

		return project;
	}

	private Project loadProjectByID(int id) throws ArcturusDatabaseException {
		Project project = null;

		try {
			pstmtByID.setInt(1, id);
			ResultSet rs = pstmtByID.executeQuery();

			if (rs.next()) {
				int assembly_id = rs.getInt(1);
				String name = rs.getString(2);
				java.util.Date updated = rs.getTimestamp(3);
				String owner = rs.getString(4);
				java.util.Date lockdate = rs.getTimestamp(5);
				String lockowner = rs.getString(6);
				java.util.Date created = rs.getTimestamp(7);
				String creator = rs.getString(8);
				String directory = rs.getString(9);
				int status = statusStringToCode(rs.getString(10));

				Assembly assembly = adb.getAssemblyByID(assembly_id);

				project = createAndRegisterNewProject(id, assembly, name,
						updated, owner, lockdate, lockowner, created, creator,
						directory, status);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load project by ID=" + id, conn, this);
		}

		return project;
	}

	public Project getProjectByName(Assembly assembly, String name)
			throws ArcturusDatabaseException {
		Project project = null;

		PreparedStatement pstmt;

		try {
			if (assembly == null) {
				pstmt = pstmtByName;
				pstmt.setString(1, name);
			} else {
				int assembly_id = assembly.getID();
				pstmt = pstmtByNameAndAssembly;
				pstmt.setInt(1, assembly_id);
				pstmt.setString(2, name);
			}

			ResultSet rs = pstmt.executeQuery();

			if (rs.next()) {
				int project_id = rs.getInt(1);

				project = (Project) hashByID.get(new Integer(project_id));

				if (project == null) {
					java.util.Date updated = rs.getTimestamp(2);
					String owner = rs.getString(3);
					java.util.Date lockdate = rs.getTimestamp(4);
					String lockowner = rs.getString(5);
					java.util.Date created = rs.getTimestamp(6);
					String creator = rs.getString(7);
					String directory = rs.getString(8);
					int status = statusStringToCode(rs.getString(9));

					project = createAndRegisterNewProject(project_id, assembly,
							name, updated, owner, lockdate, lockowner, created,
							creator, directory, status);
				}
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load project by name=" + name, conn, this);
		}

		return project;
	}

	private Project createAndRegisterNewProject(int id, Assembly assembly,
			String name, java.util.Date updated, String owner,
			java.util.Date lockdate, String lockowner, java.util.Date created,
			String creator, String directory, int status) {
		Project project = new Project(id, assembly, name, updated, owner,
				lockdate, lockowner, created, creator, status, adb);

		project.setDirectory(directory);

		registerNewProject(project);

		return project;
	}

	private void registerNewProject(Project project) {
		hashByID.put(new Integer(project.getID()), project);
	}

	public void preload() throws ArcturusDatabaseException {
		String query = "select project_id,assembly_id,name,updated,owner,lockdate,lockowner,created,creator,directory,status from PROJECT";

		try {
			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int id = rs.getInt(1);

				int assembly_id = rs.getInt(2);
				String name = rs.getString(3);
				java.util.Date updated = rs.getTimestamp(4);
				String owner = rs.getString(5);
				java.util.Date lockdate = rs.getTimestamp(6);
				String lockowner = rs.getString(7);
				java.util.Date created = rs.getTimestamp(8);
				String creator = rs.getString(9);
				String directory = rs.getString(10);
				int status = statusStringToCode(rs.getString(11));

				Assembly assembly = adb.getAssemblyByID(assembly_id);

				Project project = (Project) hashByID.get(new Integer(id));

				if (project == null)
					createAndRegisterNewProject(id, assembly, name, updated,
							owner, lockdate, lockowner, created, creator,
							directory, status);
				else {
					project.setAssembly(assembly);
					project.setName(name);
					project.setUpdated(updated);
					project.setOwner(owner);
					project.setLockdate(lockdate);
					project.setLockOwner(lockowner);
					project.setCreated(created);
					project.setCreator(creator);
					project.setDirectory(directory);
					project.setStatus(status);
				}
			}

			rs.close();
			stmt.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload projects", conn, this);
		}
	}

	public Set<Project> getAllProjects() throws ArcturusDatabaseException {
		preload();
		return new HashSet<Project>(hashByID.values());
	}

	public Set<Project> getProjectsForOwner(Person owner) throws ArcturusDatabaseException {
		preload();

		if (owner == null)
			return null;

		HashSet<Project> set = new HashSet<Project>();

		for (Iterator iter = hashByID.values().iterator(); iter.hasNext();) {
			Project project = (Project) iter.next();

			if (owner.equals(project.getOwner()))
				set.add(project);
		}

		return set;
	}
	
	public Set<Project> getBinProjects() throws ArcturusDatabaseException {
		preload();
		
		HashSet<Project> set = new HashSet<Project>();

		for (Iterator iter = hashByID.values().iterator(); iter.hasNext();) {
			Project project = (Project) iter.next();

			if (project.isBin())
				set.add(project);
		}

		return set;		
	}

	public void refreshProject(Project project) throws ArcturusDatabaseException {
		int id = project.getID();

		try {
			pstmtByID.setInt(1, id);
			ResultSet rs = pstmtByID.executeQuery();

			if (rs.next()) {
				int assembly_id = rs.getInt(1);
				String name = rs.getString(2);
				java.util.Date updated = rs.getTimestamp(3);
				String owner = rs.getString(4);
				java.util.Date lockdate = rs.getTimestamp(5);
				String lockowner = rs.getString(6);
				java.util.Date created = rs.getTimestamp(7);
				String creator = rs.getString(8);
				String directory = rs.getString(9);
				int status = statusStringToCode(rs.getString(10));

				Assembly assembly = adb.getAssemblyByID(assembly_id);

				project.setAssembly(assembly);
				project.setName(name);
				project.setUpdated(updated);
				project.setOwner(owner);
				project.setLockdate(lockdate);
				project.setLockOwner(lockowner);
				project.setCreated(created);
				project.setCreator(creator);
				project.setDirectory(directory);
				project.setStatus(status);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to refresh project ID=" + project.getID(), conn, this);
		}
	}

	public void refreshAllProjects() throws ArcturusDatabaseException {
		preload();
	}
	
	private int statusStringToCode(String status) {
		if (status.equalsIgnoreCase("in shotgun"))
			return Project.IN_SHOTGUN;
		else if (status.equalsIgnoreCase("prefinishing"))
			return Project.PREFINISHING;
		else if (status.equalsIgnoreCase("in finishing"))
			return Project.IN_FINISHING;
		else if (status.equalsIgnoreCase("quality checked"))
			return Project.QUALITY_CHECKED;
		else if (status.equalsIgnoreCase("finished"))
			return Project.FINISHED;
		else if (status.equalsIgnoreCase("retired"))
			return Project.RETIRED;
		else
			return Project.UNKNOWN;
	}

	private String statusCodeToString(int status) {
		switch (status) {
			case Project.IN_SHOTGUN:
				return "in shotgun";
				
			case Project.PREFINISHING:
				return "prefinishing";
				
			case Project.IN_FINISHING:
				return "in finishing";
				
			case Project.QUALITY_CHECKED:
				return "quality checked";
				
			case Project.FINISHED:
				return "finished";
				
			case Project.RETIRED:
				return "retired";
				
			default:
				return null;
		}
	}
	
	public void setAssemblyForProject(Project project, Assembly assembly)
			throws ArcturusDatabaseException {
		if (project == null)
			throw new IllegalArgumentException("Project cannot be null");
		
		if (assembly == null)
			throw new IllegalArgumentException("Assembly cannot be null");
		
		try {
			int project_id = project.getID();
			int assembly_id = assembly.getID();

			pstmtSetAssemblyForProject.setInt(1, assembly_id);
			pstmtSetAssemblyForProject.setInt(2, project_id);

			pstmtSetAssemblyForProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to set assembly ID=" + assembly.getID() + " for project ID=" + project.getID(),
					conn, this);
		}

	}

	public void getProjectSummary(Project project, int minlen, int minreads,
			ProjectSummary summary) throws ArcturusDatabaseException {
		int project_id = project.getID();

		try {
			pstmtProjectSummaryByID.setInt(1, project_id);
			pstmtProjectSummaryByID.setInt(2, minlen);
			pstmtProjectSummaryByID.setInt(3, minreads);

			ResultSet rs = pstmtProjectSummaryByID.executeQuery();

			if (rs.next()) {
				summary.setNumberOfContigs(rs.getInt(1));
				summary.setNumberOfReads(rs.getInt(2));
				summary.setTotalConsensusLength(rs.getInt(3));
				summary.setMeanConsensusLength(rs.getInt(4));
				summary.setSigmaConsensusLength(rs.getInt(5));
				summary.setMaximumConsensusLength(rs.getInt(6));
				summary.setNewestContigCreated(rs.getTimestamp(7));
				summary.setMostRecentContigUpdated(rs.getTimestamp(8));
			} else
				summary.reset();

			rs.close();

			pstmtLastContigTransferOutByID.setInt(1, project_id);

			rs = pstmtLastContigTransferOutByID.executeQuery();

			summary.setMostRecentContigTransferOut(rs.next() ? rs
					.getTimestamp(1) : null);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get summary for project ID=" + project.getID(), conn, this);
		}
	}

	public void getProjectSummary(Project project, ProjectSummary summary)
			throws ArcturusDatabaseException {
		getProjectSummary(project, 0, 0, summary);
	}

	public ProjectSummary getProjectSummary(Project project)
			throws ArcturusDatabaseException {
		return getProjectSummary(project, 0, 0);
	}

	public ProjectSummary getProjectSummary(Project project, int minlen)
			throws ArcturusDatabaseException {
		ProjectSummary summary = new ProjectSummary();

		getProjectSummary(project, minlen, 0, summary);

		return summary;
	}

	public ProjectSummary getProjectSummary(Project project, int minlen,
			int minreads) throws ArcturusDatabaseException {
		ProjectSummary summary = new ProjectSummary();

		getProjectSummary(project, minlen, minreads, summary);

		return summary;
	}

	public Map<Integer, ProjectSummary> getProjectSummary(int minlen,
			int minreads) throws ArcturusDatabaseException {
		HashMap<Integer, ProjectSummary> map = new HashMap<Integer, ProjectSummary>();

		try {
			pstmtProjectSummary.setInt(1, minlen);
			pstmtProjectSummary.setInt(2, minreads);

			ResultSet rs = pstmtProjectSummary.executeQuery();

			while (rs.next()) {
				int project_id = rs.getInt(1);

				ProjectSummary summary = new ProjectSummary();

				summary.setNumberOfContigs(rs.getInt(2));
				summary.setNumberOfReads(rs.getInt(3));
				summary.setTotalConsensusLength(rs.getInt(4));
				summary.setMeanConsensusLength(rs.getInt(5));
				summary.setSigmaConsensusLength(rs.getInt(6));
				summary.setMaximumConsensusLength(rs.getInt(7));
				summary.setNewestContigCreated(rs.getTimestamp(8));
				summary.setMostRecentContigUpdated(rs.getTimestamp(9));
				summary.setMostRecentContigTransferOut(null);

				map.put(new Integer(project_id), summary);
			}

			rs.close();

			rs = pstmtLastContigTransferOut.executeQuery();

			while (rs.next()) {
				int project_id = rs.getInt(1);

				ProjectSummary summary = (ProjectSummary) map.get(new Integer(
						project_id));

				if (summary != null)
					summary.setMostRecentContigTransferOut(rs.getTimestamp(2));
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get summary for projects", conn, this);
		}

		return map;
	}

	public Map getProjectSummary(int minlen) throws ArcturusDatabaseException {
		return getProjectSummary(minlen, 0);
	}

	public Map getProjectSummary() throws ArcturusDatabaseException {
		return getProjectSummary(0, 0);
	}

	/*
	 * Project locking and unlocking
	 */

	public boolean canUserUnlockProject(Project project, Person user)
			throws ArcturusDatabaseException {
		if (!project.isLocked())
			return false;

		return project.getLockOwner().equals(user)
				|| adb.hasFullPrivileges(user);
	}

	public boolean canUserLockProjectForSelf(Project project, Person user)
			throws ArcturusDatabaseException {
		if (project.isLocked() || project.isBin())
			return false;

		return project.isUnowned() || project.isOwner(user)
				|| adb.hasFullPrivileges(user);
	}

	public boolean canUserLockProjectForOwner(Project project, Person user)
			throws ArcturusDatabaseException {
		if (project.isLocked() || project.isBin() || project.isUnowned())
			return false;

		return project.isOwner(user) || adb.hasFullPrivileges(user);
	}
	
	public boolean canUserLockProject(Project project, Person user)
		throws ArcturusDatabaseException {
		if (project.isLocked() || project.isBin())
			return false;

		return (project.isUnowned() || project.isOwner(user)) || adb.hasFullPrivileges(user);
	}

	public boolean unlockProject(Project project) throws ProjectLockException,
			ArcturusDatabaseException {
		if (!project.isLocked())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_IS_UNLOCKED);

		if (!canUserUnlockProject(project, adb.findMe()))
			throw new ProjectLockException(
					ProjectLockException.OPERATION_NOT_PERMITTED);

		int rc = 0;
		
		try {
			pstmtUnlockProject.setInt(1, project.getID());

			rc = pstmtUnlockProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to unlock project ID=" + project.getID(), conn, this);
		}
	
		if (rc == 1)
			lockChanged(project);

		return rc == 1;
	}

	public boolean lockProject(Project project) throws ProjectLockException,
			ArcturusDatabaseException {
		if (project.isLocked())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_IS_LOCKED);

		Person me = adb.findMe();

		if (!canUserLockProjectForSelf(project, me))
			throw new ProjectLockException(
					ProjectLockException.OPERATION_NOT_PERMITTED);
		
		int rc = 0;

		try {
			pstmtLockProject.setString(1, me.getUID());
			pstmtLockProject.setInt(2, project.getID());

			rc = pstmtLockProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to lock project ID=" + project.getID(), conn, this);
		}
	
		if (rc == 1)
			lockChanged(project);

		return rc == 1;
	}

	public boolean lockProjectForOwner(Project project)
			throws ProjectLockException, ArcturusDatabaseException {
		if (project.isLocked())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_IS_LOCKED);

		if (project.isUnowned())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_HAS_NO_OWNER);

		Person me = adb.findMe();

		if (!canUserLockProjectForOwner(project, me))
			throw new ProjectLockException(
					ProjectLockException.OPERATION_NOT_PERMITTED);

		int rc = 0;
		
		try {
			pstmtLockProjectForOwner.setInt(1, project.getID());

			rc = pstmtLockProjectForOwner.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to lock project ID=" + project.getID() + " for owner", conn, this);
		}

		if (rc == 1)
			lockChanged(project);

		return rc == 1;
	}

	public boolean setProjectLockOwner(Project project, Person person)
		throws ProjectLockException, ArcturusDatabaseException {
		if (project.isLocked())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_IS_LOCKED);

		Person me = adb.findMe();

		if (!canUserLockProject(project, me))
			throw new ProjectLockException(
					ProjectLockException.OPERATION_NOT_PERMITTED);
		
		int rc = 0;

		try {
			pstmtLockProject.setString(1, person.getUID());
			pstmtLockProject.setInt(2, project.getID());

			rc = pstmtLockProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to lock project ID=" + project.getID() + " for user UID=" + person.getUID(),
					conn, this);
		}

		if (rc == 1)
			lockChanged(project);

		return rc == 1;
	}

	public boolean unlockProjectForExport(Project project)
			throws ProjectLockException, ArcturusDatabaseException {
		if (!project.isLocked())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_IS_UNLOCKED);
		
		int rc = 0;

		try {
			pstmtUnlockProject.setInt(1, project.getID());

			rc = pstmtUnlockProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to unlock project ID=" + project.getID() + " for export",
					conn, this);
		}

		if (rc == 1)
			lockChanged(project);

		return rc == 1;
	}

	public boolean lockProjectForExport(Project project)
			throws ProjectLockException, ArcturusDatabaseException {
		if (project.isLocked())
			throw new ProjectLockException(
					ProjectLockException.PROJECT_IS_LOCKED);

		Person me = adb.findMe();
		
		int rc = 0;

		try {
			pstmtLockProject.setString(1, me.getUID());
			pstmtLockProject.setInt(2, project.getID());

			rc = pstmtLockProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to lock project ID=" + project.getID() + " for export",
					conn, this);
		}

		if (rc == 1)
			lockChanged(project);

		return rc == 1;
	}

	private void lockChanged(Project project) throws ArcturusDatabaseException {
		refreshProject(project);

		ProjectChangeEvent event = new ProjectChangeEvent(this, project,
				ProjectChangeEvent.LOCK_CHANGED);

		adb.notifyProjectChangeEventListeners(event, null);
	}

	public void setProjectOwner(Project project, Person person)
			throws ArcturusDatabaseException {
		boolean nobody = person.isNobody();
		
		int rc = 0;

		try {
			if (nobody)
				pstmtSetProjectOwner.setNull(1, Types.CHAR);
			else
				pstmtSetProjectOwner.setString(1, person.getUID());

			pstmtSetProjectOwner.setInt(2, project.getID());

			rc = pstmtSetProjectOwner.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to set owner for project ID=" + project.getID() + " to " +
					(nobody ? "NULL" : person.getUID()), conn, this);
		}

		if (rc == 1)
			ownerChanged(project);
	}

	private void ownerChanged(Project project) throws ArcturusDatabaseException {
		refreshProject(project);

		ProjectChangeEvent event = new ProjectChangeEvent(this, project,
				ProjectChangeEvent.OWNER_CHANGED);

		adb.notifyProjectChangeEventListeners(event, null);
	}

	public boolean createNewProject(Assembly assembly, String name, Person owner,
			String directory) throws ArcturusDatabaseException, IOException {
		if (Arcturus.isLinux()) {
			File dir = new File(directory);
		
			if (dir.exists()) {
				if (!dir.isDirectory())
					throw new IOException("A file named \"" + directory +
					"\" already exists and is not a directory");
			} else {
				if (!dir.mkdirs())
					throw new IOException("Unable to create a directory named \"" + directory + "\"");
			}
		}
		
		int rc = 0;
		
		String creator = System.getProperty("user.name");
		
		try {
			pstmtCreateNewProject.setInt(1, assembly.getID());
			pstmtCreateNewProject.setString(2, name);
			pstmtCreateNewProject.setString(3, creator);
			pstmtCreateNewProject.setString(4, owner.getUID());
			pstmtCreateNewProject.setString(5, directory);

			rc = pstmtCreateNewProject.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to create a new project with assembly ID=" + assembly.getID() +
					", name=\"" + name + "\", creator=" + creator + ", owner=" + owner + ", directory=" + directory,
					conn, this);
		}
	
		return rc == 1;
	}

	public boolean canUserChangeProjectStatus(Project project, Person user)
			throws ArcturusDatabaseException {
		if (project.isLocked() || project.isBin() || project.isUnowned())
			return false;

		return project.getOwner().equals(user) || adb.hasFullPrivileges(user);
	}

	public boolean canUserChangeProjectStatus(Project project)
			throws ArcturusDatabaseException {
		if (project.isLocked() || project.isBin() || project.isUnowned())
			return false;
		
		Person user = adb.findMe();

		return project.getOwner().equals(user) || adb.hasFullPrivileges(user);
	}
	
	public boolean changeProjectStatus(Project project, int status) throws ArcturusDatabaseException {
		if (project == null)
			return false;
		
		if (project.getStatus() == status)
			return true;
		
		if (!canUserChangeProjectStatus(project))
			return false;
		
		String statusString = statusCodeToString(status);
		
		if (statusString == null)
			return false;
		
		int rc = 0;
		
		try {
			pstmtChangeProjectStatus.setString(1, statusString);
			pstmtChangeProjectStatus.setInt(2, project.getID());
		
			rc = pstmtChangeProjectStatus.executeUpdate();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to change status of project ID=" + project.getID(), conn, this);
		}
	
		if (rc == 1) {
			project.setStatus(status);
			
			if (status == Project.RETIRED)
				retireContigs(project);
			
			return true;
		} else
			return false;
	}

	public boolean retireProject(Project project) throws ArcturusDatabaseException {
		if (project.isRetired())
			return true;
		return changeProjectStatus(project, Project.RETIRED);
	}
	
	private void retireContigs(Project project) throws ArcturusDatabaseException {
		Project bin = getBinForProject(project);
		adb.moveContigs(project, bin);
	}
	
	public Project getBinForProject(Project project) throws ArcturusDatabaseException {
		if (project == null)
			return null;
		
		Assembly assembly = project.getAssembly();
		
		Project bin = getProjectByName(assembly, "BIN");
		
		return (bin != null) ? bin : getProjectByName(null, "BIN");
	}
}
