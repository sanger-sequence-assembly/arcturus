package test.jdbc;

import static org.junit.Assert.*;

import java.util.Date;

import org.junit.Test;

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
				
		String templateName = "MyTemplate";
		
		Template template = new Template(templateName);
		
		String readName = "MyRead";
		
		Date asped = new Date();
		
		String basecaller = "UnitTesting";
		
		String status = "PASS";
		
		Read read = new Read(readName, 0, template, asped,
				Read.FORWARD, Read.UNIVERSAL_PRIMER, Read.DYE_TERMINATOR,
				basecaller, status, null);
		
		Read newRead = adb.findOrCreateRead(read);
		
		assertNotNull("findOrCreateRead returned null", newRead);
		
		assertEquals("findOrCreateRead yielded unequal reads", read, newRead);
	}
}
