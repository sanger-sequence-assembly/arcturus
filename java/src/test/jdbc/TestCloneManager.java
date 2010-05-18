package test.jdbc;

import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestCloneManager extends Base {
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
		
		String cloneName = "MyClone1";
		
		Clone clone = new Clone(cloneName);
		
		Clone newClone = adb.findOrCreateClone(clone);
		
		assertNotNull("findOrCreateClone returned null", newClone);
		
		assertEquals("findOrCreateClone yielded unequal clones", clone, newClone);
	}
	
	@Test
	public void putClone() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String cloneName = "MyClone2";
		
		Clone clone = new Clone(cloneName);
		
		Clone newClone = adb.putClone(clone);
		
		assertNotNull("putClone returned null", newClone);	
		
		assertEquals("putClone yielded unequal clones", clone, newClone);
	}
}
