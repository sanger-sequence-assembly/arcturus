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
}
