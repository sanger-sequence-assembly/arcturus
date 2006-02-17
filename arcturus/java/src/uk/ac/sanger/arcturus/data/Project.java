package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.utils.ProjectSummary;
import uk.ac.sanger.arcturus.people.*;

import java.util.*;
import java.sql.SQLException;
import java.util.zip.DataFormatException;

/**
 * This class represents a project, which is a set of contigs.
 */

public class Project extends Core {
    protected Assembly assembly = null;
    protected Date updated = null;
    protected Person owner = null;
    protected Date locked = null;
    protected Date created = null;
    protected Person creator = null;

    protected Set contigs = null;

    /**
     * Constructs a Project which does not yet have an ID.
     * This constructor will typically be used to create a Project
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     */

    public Project() {
	super();
    }

    /**
     * Constructs a Project which has an ID.
     * This constructor will typically be used when a Project
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Project.
     * @param adb the Arcturus database to which this Project belongs.
     */

    public Project(int ID, ArcturusDatabase adb) {
	super(ID, adb);
    }

    /**
     * Constructs a Project with basic properties.
     * This constructor will typically be used when a Project
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Project.
     * @param adb the Arcturus database to which this Project belongs.
     */

    public Project(int ID, Assembly assembly, String name, Date updated, Person owner, Date locked, Date created, Person creator,
		   ArcturusDatabase adb) {
	super(ID, adb);

	try {
	    setAssembly(assembly, false);
	}
	catch (SQLException sqle) {}

	this.name = name;
	this.updated = updated;
	this.owner = owner;
	this.locked = locked;
	this.created = created;
	this.creator = creator;
    }

    /**
     * Constructs a Project with basic properties.
     * This constructor will typically be used when a Project
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Project.
     * @param adb the Arcturus database to which this Project belongs.
     */

    public Project(int ID, Assembly assembly, String name, Date updated, String owner, Date locked, Date created, String creator,
		   ArcturusDatabase adb) {
	super(ID, adb);

	try {
	    setAssembly(assembly, false);
	}
	catch (SQLException sqle) {}

	this.name = name;
	this.updated = updated;
	this.owner = findPerson(owner);
	this.locked = locked;
	this.created = created;
	this.creator = findPerson(creator);
    }

    private Person findPerson(String uid) {
	return PeopleManager.findPerson(uid);
    }

    public Assembly getAssembly() { return assembly; }

    public void setAssembly(Assembly assembly) throws SQLException {
	setAssembly(assembly, true);
    }

    public void setAssembly(Assembly assembly, boolean commit) throws SQLException {
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

    public String getName() { return name; }

    public void setName(String name) { this.name = name; }

    public Date getUpdated() { return updated; }

    public void setUpdated(Date updated) { this.updated = updated; }

    public Person getOwner() { return owner; }

    public void setOwner(String owner) { this.owner = findPerson(owner); }

    public void setOwner(Person owner) { this.owner = owner; }

    public Date getLocked() { return locked; }

    public void setLocked(Date locked) { this.locked = locked; }

    public boolean isLocked() { return locked == null; }

    public Date getCreated() { return created; }

    public void setCreated(Date created) { this.created = created; }

    public Person getCreator() { return creator; }

    public void setCreator(String creator) { this.creator = findPerson(creator); }

    public void setCreator(Person creator) { this.creator = creator; }

    /**
     * Returns the number of contigs currently contained in this Project object.
     *
     * @return the number of contigs currently contained in this Project object.
     */

    public int getContigCount() { return (contigs == null) ? 0 : contigs.size(); }

    /**
     * Returns the Vector containing the contigs currently in this Project object.
     *
     * @return the Vector containing the contigs currently in this Project object.
     */

    public Set getContigs() { return contigs; }

    public Set getContigs(boolean refresh) throws SQLException {
	try {
	    if (refresh && adb != null)
		contigs = adb.getContigsByProject(ID, ArcturusDatabase.CONTIG_BASIC_DATA, 0);
	}
	catch (DataFormatException dfe) { /* This is never going to happen */ }

	return contigs;
    }

    public void setContigs(Set contigs) { this.contigs = contigs; }

    public void addContig(Contig contig) {
	if (contigs == null)
	    contigs = new HashSet();

	contigs.add(contig);
    }

    public boolean removeContig(Contig contig) {
	if (contigs == null)
	    return false;
	else
	    return contigs.remove(contig);
    }

    public void refresh() throws SQLException {
	if (adb != null)
	    adb.refreshProject(this);
    }

    public ProjectSummary getProjectSummary(int minlen) throws SQLException {
	if (adb != null)
	    return adb.getProjectSummary(this, minlen);
	else
	    return null;
    }

    public ProjectSummary getProjectSummary() throws SQLException {
	return getProjectSummary(0);
    }
}
