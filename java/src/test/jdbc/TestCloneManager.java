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
		
		if (adb == null)
			throw new Exception("The ArcturusDatabase object was null");
	}

	@AfterClass
	public static void tearDownAfterClass() throws Exception {
		if (adb != null)
			adb.closeConnectionPool();
	}
	
	@Test
	public void lookupCloneByName() throws ArcturusDatabaseException {
		String cloneName = "NO-SUCH-CLONE";
		
		Clone clone = adb.getCloneByName(cloneName);
		
		assertNull(clone);
	}

	@Test
	public void findOrCreateClone() throws ArcturusDatabaseException {
		String cloneName = "MyClone";
		
		Clone clone = adb.findOrCreateClone(cloneName);
		
		assertNotNull(clone);
	}
}
