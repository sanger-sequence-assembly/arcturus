package test.jdbc;

import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class MappingManagerTest extends Base {
//public class TestMappingManager {
		
	@Test
	public void findOrCreateCanonicalMapping() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		System.out.println("DB opened");
		
		String cigar = "50M1D1M1D1M1D3M";
		CanonicalMapping mapping = new CanonicalMapping(cigar);
		
	    
		
		CanonicalMapping cached = adb.findOrCreateCanonicalMapping(mapping);
			
		assertTrue(cached != null);
	}

}
