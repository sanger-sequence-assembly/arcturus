// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * This class represents a basic object which has a name and an ID and which can
 * be stored in or retrieved from an Arcturus database.
 */

public class Core {
	/**
	 * A constant representing an attribute whose value is unknown.
	 */

	public final static short UNKNOWN = 0;
	
	public final static String UNKNOWN_STRING = "Unknown";

	protected int ID;
	protected String name;
	protected ArcturusDatabase adb;

	/**
	 * Constructs an object which does not yet have an ID or a name. This
	 * constructor will typically be used to create an object <EM>ab initio</EM>
	 * prior to putting it into an Arcturus database.
	 */

	public Core() {
		this.name = null;
		ID = UNKNOWN;
	}

	/**
	 * Constructs an object which does not yet have an ID. This constructor will
	 * typically be used to create an object <EM>ab initio</EM> prior to
	 * putting it into an Arcturus database.
	 * 
	 * @param name
	 *            the name of the object.
	 */

	public Core(String name) {
		this.name = name;
		ID = UNKNOWN;
	}

	/**
	 * Constructs an object which has a name and an ID. This constructor will
	 * typically be used when an object is retrieved from an Arcturus database.
	 * 
	 * @param name
	 *            the name of the object.
	 * @param ID
	 *            the ID of the object.
	 * @param adb
	 *            the Arcturus database to which this object belongs.
	 */

	public Core(String name, int ID, ArcturusDatabase adb) {
		this.name = name;
		this.ID = ID;
		this.adb = adb;
	}

	/**
	 * Constructs an object which has an ID. This constructor will typically be
	 * used when an object is retrieved from an Arcturus database.
	 * 
	 * @param ID
	 *            the ID of the object.
	 * @param adb
	 *            the Arcturus database to which this object belongs.
	 */

	public Core(int ID, ArcturusDatabase adb) {
		this(null, ID, adb);
	}

	/**
	 * Returns the name of the object.
	 * 
	 * @return the name of the object.
	 */

	public String getName() {
		return name;
	}

	/**
	 * Sets the ID of the object.
	 * 
	 * @param ID
	 *            the ID of the object.
	 */

	public void setID(int ID) {
		this.ID = ID;
	}

	/**
	 * Returns the ID of the object.
	 * 
	 * @return the ID of the object.
	 */

	public int getID() {
		return ID;
	}

	/**
	 * Associates this object with an Arcturus database.
	 * 
	 * @param adb
	 *            the Arcturus database to which this object belongs.
	 */

	public void setArcturusDatabase(ArcturusDatabase adb) {
		this.adb = adb;
	}

	/**
	 * Returns the Arcturus database to which this object belongs.
	 * 
	 * @return the Arcturus database to which this object belongs.
	 */

	public ArcturusDatabase getArcturusDatabase() {
		return adb;
	}

	/**
	 * Returns a string representation of this object, in a form suitable for
	 * printing.
	 * 
	 * @return a string representation of this object.
	 */

	public String toString() {
		return getClass().getName() + "[name=" + name
				+ ((ID != UNKNOWN) ? ", ID=" + ID + "]" : "]");
	}
	
	/**
	 * Tests whether another Core is equal to this one.
	 * 
	 * Two Cores are equal if, and only if, they have the same name, the same ID and
	 * the same ArcturusDatabase object as their owner.
	 * 
	 * @param that the obkect with which to compare
	 * @return true if the two objects are identical; false otherwise.
	 */
	
	public boolean equals(Core that) {
		return that != null && this.name != null && that.name != null &&
			this.name.equals(that.name) && this.ID == that.ID &&
			this.adb == that.adb;
	}
	
}
