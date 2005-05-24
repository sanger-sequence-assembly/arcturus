package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;

/**
 * This class represents a contig.
 */

public class Contig extends Core {
    protected int length;
    protected int nreads;
    protected Date updated = null;
    protected Date created = null;
    protected Mapping[] mappings = null;
    protected byte[] dna = null;
    protected byte[] quality = null;
    protected Project project = null;

    /**
     * Constructs a Contig which does not yet have an ID or a name.
     * This constructor will typically be used to create a Contig
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     */

    public Contig() {
	super();
    }

     /**
     * Constructs a Contig with basic properties.
     * This constructor will typically be used when a Contig
     * is retrieved from an Arcturus database.
     *
     * @param name the name of the Contig.
     * @param ID the ID of the Contig.
     * @param length the length of the Contig.
     * @param nreads the number of reads in the Contig.
     * @param created the date and time when the Contig was created.
     * @param updated the date and time when the Contig was last updated.
     * @param project the project to which this Contig belongs.
     * @param adb the Arcturus database to which this Contig belongs.
     */

    public Contig(String name, int ID, int length, int nreads, Date created, Date updated,
		  Project project, ArcturusDatabase adb) {
	super(name, ID, adb);

	this.length = length;
	this.nreads = nreads;
	this.created = created;
	this.updated = updated;
	this.project = project;
    }


    /**
     * Constructs a Contig which has an ID and a name.
     * This constructor will typically be used when a Contig
     * is retrieved from an Arcturus database.
     *
     * @param name the name of the Contig.
     * @param ID the ID of the Contig.
     * @param adb the Arcturus database to which this Contig belongs.
     */

    public Contig(String name, int ID, ArcturusDatabase adb) {
	super(name, ID, adb);
    }

    /**
     * Constructs a Contig which has an ID.
     * This constructor will typically be used when a Contig
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Contig.
     * @param adb the Arcturus database to which this Contig belongs.
     */

    public Contig(int ID, ArcturusDatabase adb) {
	super(ID, adb);
    }

    /**
     * Constructs a Contig with basic properties and read-to-contig mappings.
     * This constructor will typically be used when a Contig
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Contig.
     * @param adb the Arcturus database to which this Contig belongs.
     */

    public Contig(int ID, int length, int nreads, Date updated, Mapping[] mappings,
		  ArcturusDatabase adb) {
	super(ID, adb);

	this.length = length;
	
	this.nreads = (mappings == null) ? nreads : mappings.length;

	this.updated = updated;

	this.mappings = mappings;
    }

    public int getLength() { return length; }

    public int getReadCount() { return nreads; }

    public Date getCreated() { return created; }

    public Date getUpdated() { return updated; }

    public Project getProject() { return project; }

    public void setProject(Project project) {
	this.project = project;
    }

    public Mapping[] getMappings() { return mappings; }

    public void setMappings(Mapping[] mappings) {
	this.mappings = mappings;
	this.nreads = mappings.length;
    }

    public byte[] getDNA() { return dna; }

    public byte[] getQuality() { return quality; }

    public void setConsensus(byte[] dna, byte[] quality) {
	this.dna = dna;
	this.quality = quality;
    }
}
