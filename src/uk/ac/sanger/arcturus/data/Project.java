package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;

/**
 * This class represents a project, which is a set of contigs.
 */

public class Project extends Core {
    protected int assembly_id = 0;
    protected String name = null;
    protected Date updated = null;
    protected String owner = null;
    protected Date locked = null;
    protected Date created = null;
    protected String creator = null;

    protected Vector contigs = null;

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

    public Project(int ID, int assembly_id, String name, Date updated, String owner, Date locked, Date created, String creator,
		   ArcturusDatabase adb) {
	super(ID, adb);

	this.assembly_id = assembly_id;
	this.name = name;
	this.updated = updated;
	this.owner = owner;
	this.locked = locked;
	this.created = created;
	this.creator = creator;
    }

    public int getAssemblyID() { return assembly_id; }

    public void setAssemblyID(int assembly_id) { this.assembly_id = assembly_id; }

    public String getName() { return name; }

    public void setName(String name) { this.name = name; }

    public Date getUpdated() { return updated; }

    public void setUpdated(Date updated) { this.updated = updated; }

    public String getOwner() { return owner; }

    public void setOwner(String owner) { this.owner = owner; }

    public Date getLocked() { return locked; }

    public void setLocked(Date locked) { this.locked = locked; }

    public boolean isLocked() { return locked == null; }

    public Date getCreated() { return created; }

    public void setCreated(Date created) { this.created = created; }

    public String getCreator() { return creator; }

    public void setCreator(String creator) { this.creator = creator; }

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

    public Vector getContigs() { return contigs; }

    public void setContigs(Vector contigs) { this.contigs = contigs; }

    public void addContig(Contig contig) {
	if (contigs == null)
	    contigs = new Vector();

	contigs.add(contig);
    }

    public boolean removeContig(Contig contig) {
	if (contigs == null)
	    return false;
	else
	    return contigs.remove(contig);
    }
}
