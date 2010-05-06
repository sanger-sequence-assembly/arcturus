package test.jdbc;

import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestCloneManager extends TestBase {
	@Test
	public void lookupCloneByName() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String cloneName = "NO-SUCH-CLONE";
		
		Clone clone = adb.getCloneByName(cloneName);
		
		assertNull(clone);
	}

	@Test
	public void findOrCreateClone() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String cloneName = "MyClone";
		
		Clone clone = adb.findOrCreateClone(cloneName);
		
		assertNotNull(clone);
	}
}
