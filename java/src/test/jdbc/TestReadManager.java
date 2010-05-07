package test.jdbc;

import static org.junit.Assert.*;

import java.util.Date;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestReadManager extends TestBase {
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
		
		String strand = "Forward";
		String primer = "Universal_primer";
		String chemistry = "Dye_primer";
		
		Read read = adb.findOrCreateRead(readName, template, asped, strand, primer, chemistry);
		
		assertNotNull(read);
	}
}
