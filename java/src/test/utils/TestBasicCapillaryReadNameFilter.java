package test.utils;

import static org.junit.Assert.*;
import org.junit.Test;

import uk.ac.sanger.arcturus.utils.BasicCapillaryReadNameFilter;

public class TestBasicCapillaryReadNameFilter {
	private BasicCapillaryReadNameFilter filter = new BasicCapillaryReadNameFilter();
	
	@Test
	public void nameIsNull() {
		String name = null;
		
		boolean accept = filter.accept(name);
		
		assertTrue("A null name should not be accepted", !accept);
	}
	
	@Test
	public void nameEndsInDotP1K() {
		String name = "readname.p1k";
		
		boolean accept = filter.accept(name);
		
		assertTrue("A name ending in .p1k should be accepted", accept);		
	}
	
	@Test
	public void nameEndsInDotQ1K() {
		String name = "readname.q1k";
		
		boolean accept = filter.accept(name);
		
		assertTrue("A name ending in .q1k should be accepted", accept);		
	}
	
	@Test
	public void nameIsLikeIllumina() {
		// This name is an actual Illumina name from the Zebrafish pooled assembly ZGTC_1
		String name = "IL17_4012:1:100:1000:2012";
		
		boolean accept = filter.accept(name);
		
		assertTrue("An Illumina-style name should not be accepted", !accept);		
	}
	
	@Test
	public void nameIsLikeConsensus() {
		// This name is an actual consensus read name from the Zebrafish pooled assembly ZGTC_1
		String name = "subset_16000000_00003312";
		
		boolean accept = filter.accept(name);
		
		assertTrue("A consensus name should not be accepted", !accept);		
	}
}
