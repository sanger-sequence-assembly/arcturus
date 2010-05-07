package test.jdbc;

import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestLigationManager extends TestBase {
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
		
		Ligation ligation = adb.findOrCreateLigation(ligationName, clone, silow, sihigh);
		
		assertNotNull(ligation);
	}

}
