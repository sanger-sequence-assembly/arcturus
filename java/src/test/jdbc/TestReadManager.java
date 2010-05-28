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
		
		int read_id = adb.putRead(readname, flags);
		
		assertTrue("putRead returned a non-positive read ID", read_id > 0);
	}
}
