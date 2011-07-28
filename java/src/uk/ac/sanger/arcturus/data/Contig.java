package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.util.zip.DataFormatException;

/**
 * This class represents a contig.
 */

public class Contig extends Core {
	protected int length;
	protected int nreads;
	protected Date updated = null;
	protected Date created = null;
	protected BasicSequenceToContigMapping[] mappings = null;
	protected SequenceToContigMapping[] scmappings = null;
	protected ContigToParentMapping[]  cpmappings = null;
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

	public Contig(String name) {
		super(name);
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
			Project project, BasicSequenceToContigMapping[] mappings, ArcturusDatabase adb) {
		this(name, ID, length, 0, created, updated, project, adb);

		this.nreads = (mappings == null) ? nreads : mappings.length;

		this.mappings = mappings;
	}

	public void setLength(int length) {
		this.length = length;
	}

	public int getLength() {
		return length;
	}

	public void setReadCount(int readCount) {
		this.nreads = readCount;
	}
	
	public int getReadCount() {
		return nreads;
	}
	
	public int getParentContigCount() {
		if (cpmappings == null)
			return 0;
		return getDistinctParentCount();
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
	
	public void setSequenceToContigMappings(SequenceToContigMapping[] mappings) {
		this.scmappings = mappings;

		if (mappings != null)
			this.nreads = mappings.length;
	}
	
	public SequenceToContigMapping[] getSequenceToContigMappings() {
		return scmappings;
	}
	
	public int getSequenceToContigMappingsCount() {
		return scmappings.length;
	}
	
	public void setMappings(BasicSequenceToContigMapping[] mappings) {
		this.mappings = mappings;

		if (mappings != null)
			this.nreads = mappings.length;
	}
	
	public BasicSequenceToContigMapping[] getMappings() {
		return mappings;
	}
	
	public void setContigToParentMappings(ContigToParentMapping[] mappings) {
		this.cpmappings = mappings;
	}
	
	public ContigToParentMapping[] getContigToParentMappings() {
		return this.cpmappings;
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
	
	public int getTagCount() {
		return tags.size();
	}
	
	public boolean equals(Object o) {
		if (o == null)
			return false;
		
		if (o instanceof Contig) {
			Contig that = (Contig) o;
			
			if (ID > 0 || that.ID > 0)
				return ID == that.ID;
			else
				return this.hashCode() == that.hashCode();
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
	
	public void update(int options) throws ArcturusDatabaseException,
		DataFormatException {
		adb.updateContig(this, options);
	}
	
	private int getDistinctParentCount() {
		for (ContigToParentMapping cpmapping : cpmappings ) {
//			int parent_id = (cpmapping.getSubject) == null) ? 0 : cpmapping.getSubject().getID();
		}
		return 0;
	}
}
