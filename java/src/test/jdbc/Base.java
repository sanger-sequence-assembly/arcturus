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
