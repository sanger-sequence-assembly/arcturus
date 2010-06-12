package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.utils.ProjectSummary;
import uk.ac.sanger.arcturus.people.*;

import java.util.*;
//import java.util.zip.DataFormatException;

/**
 * This class represents a project, which is a set of contigs.
 */

public class Project extends Core {
	// Constants which represent the status values
	public static final int UNKNOWN = -1;
	public static final int IN_SHOTGUN = 0;
	public static final int PREFINISHING = 1;
	public static final int IN_FINISHING = 2;
	public static final int FINISHED = 3;
	public static final int QUALITY_CHECKED = 4;
	public static final int RETIRED = 5;

	protected Assembly assembly = null;
	protected Date updated = null;
	protected Person owner = null;
	protected Date lockdate = null;
	protected Person lockowner = null;
	protected Date created = null;
	protected Person creator = null;
	protected String directory = null;
	protected int status = UNKNOWN;

	protected Set<Contig> contigs = null;

	/**
	 * Constructs a Project which does not yet have an ID. This constructor will
	 * typically be used to create a Project <EM>ab initio</EM> prior to
	 * putting it into an Arcturus database.
	 */

	public Project() {
		super();
	}

	/**
	 * Constructs a Project which has an ID. This constructor will typically be
	 * used when a Project is retrieved from an Arcturus database.
	 * 
	 * @param ID
	 *            the ID of the Project.
	 * @param adb
	 *            the Arcturus database to which this Project belongs.
	 */

	public Project(int ID, ArcturusDatabase adb) {
		super(ID, adb);
	}

	/**
	 * Constructs a Project with basic properties. This constructor will
	 * typically be used when a Project is retrieved from an Arcturus database.
	 * 
	 * @param ID
	 *            the ID of the Project.
	 * @param adb
	 *            the Arcturus database to which this Project belongs.
	 */

	public Project(int ID, Assembly assembly, String name, Date updated,
			Person owner, Date lockdate, Person lockowner, Date created,
			Person creator, int status, ArcturusDatabase adb) {
		super(ID, adb);

		try {
			setAssembly(assembly, false);
		} catch (ArcturusDatabaseException sqle) {
		}

		this.name = name;
		this.updated = updated;
		this.owner = owner;
		this.lockdate = lockdate;
		this.lockowner = lockowner;
		this.created = created;
		this.creator = creator;
		this.directory = null;
		this.status = status;
	}

	/**
	 * Constructs a Project with basic properties. This constructor will
	 * typically be used when a Project is retrieved from an Arcturus database.
	 * 
	 * @param ID
	 *            the ID of the Project.
	 * @param adb
	 *            the Arcturus database to which this Project belongs.
	 */

	public Project(int ID, Assembly assembly, String name, Date updated,
			String owner, Date lockdate, String lockowner, Date created,
			String creator, int status, ArcturusDatabase adb) {
		super(ID, adb);

		try {
			setAssembly(assembly, false);

			this.name = name;
			this.updated = updated;
			this.owner = findPerson(owner);
			this.lockdate = lockdate;
			this.lockowner = findPerson(lockowner);
			this.created = created;
			this.creator = findPerson(creator);
			this.directory = null;
			this.status = status;
		} catch (ArcturusDatabaseException sqle) {
		}
	}

	private Person findPerson(String uid) throws ArcturusDatabaseException {
		return adb.findUser(uid);
	}

	public Assembly getAssembly() {
		return assembly;
	}

	public void setAssembly(Assembly assembly) throws ArcturusDatabaseException {
		setAssembly(assembly, true);
	}

	public void setAssembly(Assembly assembly, boolean commit)
			throws ArcturusDatabaseException {
		if (this.assembly == assembly)
			return;

		if (adb != null && assembly != null && commit)
			adb.setAssemblyForProject(this, assembly);

		if (this.assembly != null)
			this.assembly.removeProject(this);

		this.assembly = assembly;

		if (this.assembly != null)
			this.assembly.addProject(this);
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getNameAndOwner() {
		if (owner == null)
			return name;
		else
			return name + " (" + owner.getName() + ")";
	}

	public boolean isBin() {
		return name.endsWith("BIN");
	}

	public Date getUpdated() {
		return updated;
	}

	public void setUpdated(Date updated) {
		this.updated = updated;
	}

	public Person getOwner() {
		return owner;
	}

	public void setOwner(String owner) throws ArcturusDatabaseException {
		this.owner = adb.findUser(owner);
	}

	public void setOwner(Person owner) {
		this.owner = owner;
	}

	public boolean isUnowned() {
		return owner == null;
	}

	public boolean isMine() {
		return adb.isMe(owner);
	}

	public boolean isOwner(Person person) {
		return person != null && person.equals(owner);
	}

	public Date getLockdate() {
		return lockdate;
	}

	public void setLockdate(Date lockdate) {
		this.lockdate = lockdate;
	}

	public boolean isLocked() {
		return lockowner != null;
	}

	public Person getLockOwner() {
		return lockowner;
	}

	public void setLockOwner(Person lockowner) {
		this.lockowner = lockowner;
	}

	public void setLockOwner(String lockowner) throws ArcturusDatabaseException {
		this.lockowner = adb.findUser(lockowner);
	}

	public boolean lockIsMine() {
		return adb.isMe(lockowner);
	}

	public Date getCreated() {
		return created;
	}

	public void setCreated(Date created) {
		this.created = created;
	}

	public Person getCreator() {
		return creator;
	}

	public void setCreator(String creator) throws ArcturusDatabaseException {
		this.creator = adb.findUser(creator);
	}

	public void setCreator(Person creator) {
		this.creator = creator;
	}

	public void setDirectory(String directory) {
		this.directory = directory;
	}

	public String getDirectory() {
		return directory;
	}

	public void setStatus(int status) {
		this.status = status;
	}

	public int getStatus() {
		return status;
	}

	public String getStatusAsString() {
		switch (status) {
			case IN_SHOTGUN:
				return "In shotgun";

			case PREFINISHING:
				return "Prefinishing";

			case IN_FINISHING:
				return "In finishing";

			case FINISHED:
				return "Finished";

			case QUALITY_CHECKED:
				return "Quality checked";

			case RETIRED:
				return "Retired";

			default:
				return "Unknown";
		}
	}
	
	public boolean isActive() {
		return status == IN_SHOTGUN || status == PREFINISHING || status == IN_FINISHING;
	}

	public boolean isRetired() {
		return status == RETIRED;
	}

	/**
	 * Returns the number of contigs currently contained in this Project object.
	 * 
	 * @return the number of contigs currently contained in this Project object.
	 */

	public int getContigCount() {
		return (contigs == null) ? 0 : contigs.size();
	}

	/**
	 * Returns the Vector containing the contigs currently in this Project
	 * object.
	 * 
	 * @return the Vector containing the contigs currently in this Project
	 *         object.
	 */

	public Set<Contig> getContigs() {
		return contigs;
	}

	public Set<Contig> getContigs(boolean refresh) throws ArcturusDatabaseException {
		if (refresh && adb != null)
			contigs = adb.getContigsByProject(ID,
					ArcturusDatabase.CONTIG_BASIC_DATA, 0);

		return contigs;
	}

	public void setContigs(Set<Contig> contigs) {
		this.contigs = contigs;
	}

	public void addContig(Contig contig) {
		if (contigs == null)
			contigs = new HashSet<Contig>();

		contigs.add(contig);
	}

	public boolean removeContig(Contig contig) {
		if (contigs == null)
			return false;
		else
			return contigs.remove(contig);
	}

	public void refresh() throws ArcturusDatabaseException {
		if (adb != null)
			adb.refreshProject(this);
	}

	public ProjectSummary getProjectSummary(int minlen) throws ArcturusDatabaseException {
		if (adb != null)
			return adb.getProjectSummary(this, minlen, 0);
		else
			return null;
	}

	public ProjectSummary getProjectSummary() throws ArcturusDatabaseException {
		return getProjectSummary(0);
	}

	public ProjectSummary getProjectSummary(int minlen, int minreads)
			throws ArcturusDatabaseException {
		if (adb != null)
			return adb.getProjectSummary(this, minlen, minreads);
		else
			return null;
	}

	public boolean equals(Object o) {
		if (o != null && o instanceof Project)
			return ((Project) o).ID == this.ID;
		else
			return false;
	}
}
