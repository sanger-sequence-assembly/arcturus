package uk.ac.sanger.arcturus.data;

/**
 * This class represents a clone.
 */

import uk.ac.sanger.arcturus.database.*;

public class Clone extends Core {
    private Clone clone;
    private int silow;
    private int sihigh;
  
    /**
     * Constructs a Clone which does not yet have an ID.
     * This constructor will typically be used to create a Clone
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     *
     * @param name the name of the object.
     */

    public Clone(String name) {
	super(name);
    }
    /**
     * Constructs a Clone which has a name and an ID.
     * This constructor will typically be used when a Clone
     * is retrieved from an Arcturus database.
     *
     * @param name the name of the Clone.
     * @param ID the ID of the Clone.
     * @param adb the Arcturus database to which this Clone belongs.
     */

    public Clone(String name, int ID, ArcturusDatabase adb) {
	super(name, ID, adb);
    }
}
