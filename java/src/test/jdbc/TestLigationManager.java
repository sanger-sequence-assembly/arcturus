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
