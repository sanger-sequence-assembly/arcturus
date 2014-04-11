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

import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestLigationManager extends Base {
	@Test
	public void lookupLigationByName() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String ligationName = "NO-SUCH-LIGATION";
		
		Ligation ligation = adb.getLigationByName(ligationName);
		
		assertNull(ligation);
	}

	@Test
	public void findOrCreateLigation() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String cloneName = "MyClone";
		
		Clone clone = new Clone(cloneName);
		
		String ligationName = "MyLigation";
		int silow = 1000;
		int sihigh = 4000;
		
		Ligation ligation = new Ligation(ligationName, Ligation.UNKNOWN, clone, silow, sihigh, null);
		
		Ligation newLigation = adb.findOrCreateLigation(ligation);
		
		assertNotNull("findOrCreateLigation returned null", newLigation);
		
		assertEquals("findOrCreateLigation yielded unequal ligations", ligation, newLigation);
	}

}
