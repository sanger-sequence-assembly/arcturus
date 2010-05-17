package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * This class represents a clone.
 */

public class Clone extends Core {
	/**
	 * Constructs a Clone which does not yet have an ID. This constructor will
	 * typically be used to create a Clone <EM>ab initio</EM> prior to putting
	 * it into an Arcturus database.
	 * 
	 * @param name
	 *            the name of the object.
	 */

	public Clone(String name) {
		super(name);
	}

	/**
	 * Constructs a Clone which has a name and an ID. This constructor will
	 * typically be used when a Clone is retrieved from an Arcturus database.
	 * 
	 * @param name
	 *            the name of the Clone.
	 * @param ID
	 *            the ID of the Clone.
	 * @param adb
	 *            the Arcturus database to which this Clone belongs.
	 */

	public Clone(String name, int ID, ArcturusDatabase adb) {
		super(name, ID, adb);
	}
	
	/**
	 * Tests whether another clone is equal to this one.
	 * 
	 * Two clones are equal if, and only if, they have the same name, the same ID and
	 * the same ArcturusDatabase object as their owner.
	 * 
	 * @param that the clone with which to compare
	 * @return true if the two clones are identical; false otherwise.
	 */
	
	public boolean equals(Clone that) {
		return that != null && this.name != null && that.name != null &&
			this.name.equals(that.name) && this.ID == that.ID &&
			this.adb == that.adb;
	}
}
