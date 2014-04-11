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

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class MappingManagerTest extends Base {
//public class TestMappingManager {
		
	@Test
	public void findOrCreateCanonicalMapping() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		System.out.println("DB opened");
		
		String cigar = "50M1D1M1D1M1D3M";
		CanonicalMapping mapping = new CanonicalMapping(cigar);
		
	    
		
		CanonicalMapping cached = adb.findOrCreateCanonicalMapping(mapping);
			
		assertTrue(cached != null);
	}

}
