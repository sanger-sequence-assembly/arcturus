package uk.ac.sanger.arcturus.data;

/**
 * This class represents a ligation of a clone.
 */

import uk.ac.sanger.arcturus.database.*;

public class Ligation extends Core {
    private Clone clone;
    private int silow;
    private int sihigh;
 
    /**
     * Constructs a Ligation which does not yet have an ID.
     * This constructor will typically be used to create a Ligation
     * <EM>ab initio</EM> prior to putting it into an Arcturus database.
     *
     * @param name the name of the object.
     */

    public Ligation(String name) {
	super(name);
    }

    /**
     * Constructs a Ligation which has a name and an ID.
     * This constructor will typically be used when a Ligation
     * is retrieved from an Arcturus database.
     *
     * @param name the name of the Ligation.
     * @param ID the ID of the Ligation.
     * @param adb the Arcturus database to which this Ligation belongs.
     */

    public Ligation(String name, int ID, ArcturusDatabase adb) {
	super(name, ID, adb);
    }

    /**
     * Sets the Clone to which this Ligation belongs.
     *
     * @param clone the Clone to which this Ligation belongs.
     */

    public void setClone(Clone clone) {
	this.clone =clone;
    }

    /**
     * Gets the Clone to which this Ligation belongs.
     *
     * @return the Clone to which this Ligation belongs.
     */

    public Clone getClone() { return clone; }

    /**
     * Sets the minimum and maximum insert size estimates for this Ligation.
     *
     * @param silow the minimum insert size estimate.
     * @param sihigh the maximum insert size estimate.
     */

    public void setInsertSizeRange(int silow, int sihigh) {
	this.silow = silow;
	this.sihigh = sihigh;
    }

    /**
     * Gets the minimum insert size estimate for this Ligation.
     *
     * @return the minimum insert size estimate for this Ligation.
     */

    public int getInsertSizeLow() { return silow; }

    /**
     * Gets the maximum insert size estimate for this Ligation.
     *
     * @return the maximum insert size estimate for this Ligation.
     */

    public int getInsertSizeHigh() { return sihigh; }
}
