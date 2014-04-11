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

package test.jdbc;

import org.junit.AfterClass;
import org.junit.BeforeClass;

import test.Utility;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public abstract class Base {
	private static ArcturusDatabase adb;
	
	@BeforeClass
	public static void setUpBeforeClass() throws Exception {
		adb = Utility.getTestDatabase();
		
		if (adb == null)
			throw new Exception("The ArcturusDatabase object was null");
	}

	@AfterClass
	public static void tearDownAfterClass() throws Exception {
		if (adb != null)
			adb.close();
	}

	protected ArcturusDatabase getArcturusDatabase() {
		return adb;
	}
}
