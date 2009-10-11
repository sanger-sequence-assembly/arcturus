package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.util.zip.DataFormatException;
import java.sql.SQLException;

/**
 * This class represents a contig.
 */

public class Contig extends Core implements DNASequence {
	protected int length;
	protected int nreads;
	protected Date updated = null;
	protected Date created = null;
	protected Mapping[] mappings = null;
	protected byte[] dna = null;
	protected byte[] quality = null;
	protected Project project = null;
	protected Vector<Tag> tags = null;

	/**
	 * Constructs a Contig which does not yet have an ID or a name. This
	 * constructor will typically be used to create a Contig <EM>ab initio</EM>
	 * prior to putting it into an Arcturus database.
	 */

	public Contig() {
		super();
	}

	/**
	 * Constructs a Contig with basic properties. This constructor will
	 * typically be used when a Contig is retrieved from an Arcturus database.
	 * 
	 * @param name
	 *            the name of the Contig.
	 * @param ID
	 *            the ID of the Contig.
	 * @param length
	 *            the length of the Contig.
	 * @param nreads
	 *            the number of reads in the Contig.
	 * @param created
	 *            the date and time when the Contig was created.
	 * @param updated
	 *            the date and time when the Contig was last updated.
	 * @param project
	 *            the project to which this Contig belongs.
	 * @param adb
	 *            the Arcturus database to which this Contig belongs.
	 */

	public Contig(String name, int ID, int length, int nreads, Date created,
			Date updated, Project project, ArcturusDatabase adb) {
		super(name, ID, adb);

		this.length = length;
		this.nreads = nreads;
		this.created = created;
		this.updated = updated;
		this.project = project;
	}

	/**
	 * Constructs a Contig which has an ID and a name. This constructor will
	 * typically be used when a Contig is retrieved from an Arcturus database.
	 * 
	 * @param name
	 *            the name of the Contig.
	 * @param ID
	 *            the ID of the Contig.
	 * @param adb
	 *            the Arcturus database to which this Contig belongs.
	 */

	public Contig(String name, int ID, ArcturusDatabase adb) {
		super(name, ID, adb);
	}

	/**
	 * Constructs a Contig which has an ID. This constructor will typically be
	 * used when a Contig is retrieved from an Arcturus database.
	 * 
	 * @param ID
	 *            the ID of the Contig.
	 * @param adb
	 *            the Arcturus database to which this Contig belongs.
	 */

	public Contig(int ID, ArcturusDatabase adb) {
		super(ID, adb);
	}

	/**
	 * Constructs a Contig with basic properties and read-to-contig mappings.
	 * This constructor will typically be used when a Contig is retrieved from
	 * an Arcturus database.
	 * 
	 * @param name
	 *            the name of the Contig.
	 * @param ID
	 *            the ID of the Contig.
	 * @param created
	 *            the date and time when the Contig was created.
	 * @param updated
	 *            the date and time when the Contig was last updated.
	 * @param project
	 *            the project to which this Contig belongs.
	 * @param mappings
	 *            the read-to-contig mappings for this Contig.
	 * @param adb
	 *            the Arcturus database to which this Contig belongs.
	 */

	public Contig(String name, int ID, int length, Date created, Date updated,
			Project project, Mapping[] mappings, ArcturusDatabase adb) {
		this(name, ID, length, 0, created, updated, project, adb);

		this.nreads = (mappings == null) ? nreads : mappings.length;

		this.mappings = mappings;
	}

	public int getLength() {
		return length;
	}

	public int getReadCount() {
		return nreads;
	}

	public Date getCreated() {
		return created;
	}

	public Date getUpdated() {
		return updated;
	}
	
	public void setUpdated(Date updated) {
		this.updated = updated;
	}

	public Project getProject() {
		return project;
	}

	public void setProject(Project project) {
		this.project = project;
	}

	public Mapping[] getMappings() {
		return mappings;
	}

	public void setMappings(Mapping[] mappings) {
		this.mappings = mappings;

		if (mappings != null)
			this.nreads = mappings.length;
	}

	public byte[] getDNA() {
		return dna;
	}

	public byte[] getQuality() {
		return quality;
	}

	public void setConsensus(byte[] dna, byte[] quality) {
		this.dna = dna;
		this.quality = quality;
	}

	public void addTag(Tag tag) {
		if (tags == null)
			tags = new Vector<Tag>();
		
		tags.add(tag);
	}

	public Vector<Tag> getTags() {
		return tags;
	}
	
	public boolean equals(Object o) {
		if (o instanceof Contig) {
			Contig that = (Contig) o;
			return (that != null && that.getID() == ID);
		} else
			return false;
	}
	
	public String toString() {
		return "Contig[ID=" + ID +
		", name=" + name + 
		", length=" + length +
		", reads=" + nreads +
		", created=" + created +
		"]";
	}
	
	public void update(int options) throws SQLException,
		DataFormatException {
		adb.updateContig(this, options);
	}
}
