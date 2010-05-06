package test.jdbc;

import static org.junit.Assert.*;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;

import test.Utility;
import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestCloneManager {
	private static ArcturusDatabase adb;
	
	@BeforeClass
	public static void setUpBeforeClass() throws Exception {
		adb = Utility.getTestDatabase();
	}

	@AfterClass
	public static void tearDownAfterClass() throws Exception {
		adb.closeConnectionPool();
	}
	
	@Test
	public void lookupCloneByName() throws ArcturusDatabaseException {
		String cloneName = "NO-SUCH-CLONE";
		
		Clone clone = adb.getCloneByName(cloneName);
		
		assertNull(clone);
	}

}
