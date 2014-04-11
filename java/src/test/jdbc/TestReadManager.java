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

import java.util.Date;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.CapillaryRead;
import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestReadManager extends Base {
	@Test
	public void lookupReadByName() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String readName = "NO-SUCH-READ";
		
		Read read = adb.getReadByName(readName);
		
		assertNull(read);
	}

	@Test
	public void findOrCreateRead() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
				
		String templateName = "MyTemplate1";
		
		Template template = new Template(templateName);
		
		String readName = "MyRead1";
		
		Date asped = new Date();
		
		String basecaller = "UnitTesting";
		
		String status = "PASS";
		
		CapillaryRead read = new CapillaryRead(readName, 0, template, asped,
				CapillaryRead.FORWARD, CapillaryRead.UNIVERSAL_PRIMER, CapillaryRead.DYE_TERMINATOR,
				basecaller, status, null);
		
		Read newRead = adb.findOrCreateRead(read);
		
		assertNotNull("findOrCreateRead returned null", newRead);
		
		assertTrue("findOrCreateRead returned a read with non-positive ID: " + newRead.getID(),
				newRead.getID() > 0);
		
		assertEquals("findOrCreateRead yielded unequal reads", read, newRead);
	}

	@Test
	public void putRead() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
				
		String templateName = "MyTemplate2";
		
		Template template = new Template(templateName);
		
		String readName = "MyRead2";
		
		Date asped = new Date();
		
		String basecaller = "UnitTesting";
		
		String status = "PASS";
		
		CapillaryRead read = new CapillaryRead(readName, 0, template, asped,
				CapillaryRead.FORWARD, CapillaryRead.UNIVERSAL_PRIMER, CapillaryRead.DYE_TERMINATOR,
				basecaller, status, null);
		
		Read newRead = adb.putRead(read);
		
		assertNotNull("putRead returned null", newRead);
		
		assertTrue("putRead returned a read with non-positive ID: " + newRead.getID(),
				newRead.getID() > 0);
		
		assertEquals("putRead yielded unequal reads", read, newRead);
	}
	
	@Test
	public void putReadByName() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();

		String readname = "MyRead3";
		int flags = 65;
		
		Read read = new Read(readname, flags);
		
		Read newRead = adb.putRead(read);
		
		assertNotNull("putRead returned null", newRead);
		
		assertTrue("putRead returned a non-positive read ID", newRead.getID() > 0);
	}
	
	@Test
	public void putReadsWithSameName() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();

		String readname = "MyRead4";
		int flags = 65;
		
		Read read = new Read(readname, flags);
		
		Read newRead = adb.putRead(read);
		
		assertNotNull("putRead returned null on first read", newRead);
		
		assertTrue("putRead returned a non-positive read ID on first read", newRead.getID() > 0);
		
		flags = 0;
		
		read = new Read(readname, flags);
		
		newRead = adb.putRead(read);
		
		assertNotNull("putRead returned null on second read", newRead);
		
		assertTrue("putRead returned a non-positive read ID on second read", newRead.getID() > 0);
	}
}
