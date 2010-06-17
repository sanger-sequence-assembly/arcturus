package test.jdbc;

import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestMappingManager extends Base {
	
//	@Test
	public void createCanonicalMapping() throws ArcturusDatabaseException {
		
		String cigar = "50M1D1M1D1M1D3M";
		CanonicalMapping mapping = new CanonicalMapping(cigar);
		int cspan = mapping.getReferenceSpan();
		assertTrue(cspan > 0);
		int rspan = mapping.getSubjectSpan();		
		assertTrue(rspan > 0);
		System.out.println("rSpan " + cspan + " sSpan " + rspan);
	}
	
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
