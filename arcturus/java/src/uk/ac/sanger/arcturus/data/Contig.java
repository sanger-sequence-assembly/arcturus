package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.sql.Date;

/**
 * This class represents a contig.
 */

public class Contig extends Core {
    protected int length;
    protected int nreads;
    protected java.sql.Date updated;
    protected Mapping[] mappings;

    /**
     * Constructs a Contig which does not yet have an ID.
     * This constructor will typically be used to create a Contig
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     */

    public Contig() {
	super();
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
     * Constructs a Contig with basic properties.
     * This constructor will typically be used when a Contig
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Contig.
     * @param adb the Arcturus database to which this Contig belongs.
     */

    public Contig(int ID, int length, int nreads, java.sql.Date updated, ArcturusDatabase adb) {
	super(ID, adb);

	this.length = length;
	this.nreads = nreads;
	this.updated = updated;
    }


    /**
     * Constructs a Contig with basic properties and read-to-contig mappings.
     * This constructor will typically be used when a Contig
     * is retrieved from an Arcturus database.
     *
     * @param ID the ID of the Contig.
     * @param adb the Arcturus database to which this Contig belongs.
     */

    public Contig(int ID, int length, int nreads, java.sql.Date updated, Mapping[] mappings,
		  ArcturusDatabase adb) {
	super(ID, adb);

	this.length = length;
	
	this.nreads = (mappings == null) ? nreads : mappings.length;

	this.updated = updated;

	this.mappings = mappings;
    }

    public int getLength() { return length; }

    public int getReadCount() { return nreads; }

    public java.sql.Date getUpdated() { return updated; }

    public Mapping[] getMappings() { return mappings; }

    public void setMappings(Mapping[] mappings) {
	this.mappings = mappings;
	this.nreads = mappings.length;
    }
}
