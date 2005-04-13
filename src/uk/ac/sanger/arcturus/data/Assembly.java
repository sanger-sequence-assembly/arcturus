package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.sql.SQLException;

/**
 * This class represents a assembly, which is a set of projects.
 */

public class Assembly extends Core {
    protected Date updated = null;
    protected Date created = null;
    protected String creator = null;

    protected Set projects = null;

    /**
     * Constructs a Assembly which does not yet have an ID.
     * This constructor will typically be used to create a Assembly
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     */

    public Assembly() {
	super();
    }

    /**
     * Constructs a Assembly which has an ID.
     * This constructor will typically be used when a Assembly
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Assembly.
     * @param adb the Arcturus database to which this Assembly belongs.
     */

    public Assembly(int ID, ArcturusDatabase adb) {
	super(ID, adb);
    }

    /**
     * Constructs a Assembly with basic properties.
     * This constructor will typically be used when a Assembly
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Assembly.
     * @param adb the Arcturus database to which this Assembly belongs.
     */

    public Assembly(int ID, String name, Date updated, Date created, String creator,
		   ArcturusDatabase adb) {
	super(ID, adb);

	this.name = name;
	this.updated = updated;
	this.created = created;
	this.creator = creator;
    }

    public String getName() { return name; }

    public void setName(String name) { this.name = name; }

    public Date getUpdated() { return updated; }

    public void setUpdated(Date updated) { this.updated = updated; }

    public Date getCreated() { return created; }

    public void setCreated(Date created) { this.created = created; }

    public String getCreator() { return creator; }

    public void setCreator(String creator) { this.creator = creator; }

    /**
     * Returns the number of projects currently contained in this Assembly object.
     *
     * @return the number of projects currently contained in this Assembly object.
     */

    public int getProjectCount() { return (projects == null) ? 0 : projects.size(); }

    /**
     * Returns the Vector containing the projects currently in this Assembly object.
     *
     * @return the Vector containing the projects currently in this Assembly object.
     */

    public Set getProjects() { return projects; }

    public void setProjects(Set projects) { this.projects = projects; }

    public void addProject(Project project) {
	if (projects == null)
	    projects = new HashSet();

	projects.add(project);
    }

    public boolean removeProject(Project project) {
	if (projects == null)
	    return false;
	else
	    return projects.remove(project);
    }

    public void refresh() throws SQLException {
	if (adb != null)
	    adb.refreshAssembly(this);
    }
}
