package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.sql.Date;

/**
 * This class represents a contig.
 */

public class Contig extends Core {
    protected int length;
    protected int nReads;
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
	super((String)null, ID, adb);
    }
}
