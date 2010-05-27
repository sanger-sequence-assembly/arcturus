package test.mapping;

import static org.junit.Assert.*;

import org.junit.Test;

import java.util.Arrays;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class TestMapping {
	
	@Test
	public void testConstructor1() {
		Alignment[] af = stub1();
		GenericMapping gm = new GenericMapping(af);
		CanonicalMapping cm = gm.getCanonicalMapping();
		assertTrue(cm != null);
		assertEquals(6,cm.getSegments().length);
		assertEquals(Direction.FORWARD,gm.getDirection());	
	}
	
	@Test
	public void testConstructor2() {
		Alignment[] af = stub2();
		GenericMapping gm = new GenericMapping(af);
		CanonicalMapping cm = gm.getCanonicalMapping();
		assertTrue(cm != null);
		assertEquals(5,cm.getSegments().length);
		assertEquals(Direction.REVERSE,gm.getDirection());
	}
	
	@Test
	public void testConstructor3() {
		// detailed comparison of alignments
		Alignment[] af = stub1();
		GenericMapping gm = new GenericMapping(af);
	    gm.minimise(); // delete alignments
	    Alignment[] an = gm.getAlignments();
	    assertEquals(af.length,an.length);
	    for (int i = 0 ; i < af.length ; i++) {
	    	assertTrue(af[i].equals(an[i]));
	    }
	}
	
	@Test
	public void testConstructor4() {
		// detailed comparison of alignments
		Alignment[] af = stub2();
		GenericMapping gm = new GenericMapping(af);
	    gm.minimise(); // delete alignments
	    Alignment[] an = gm.getAlignments();
	    assertEquals(af.length,an.length);
	    for (int i = 0 ; i < af.length ; i++) {
	    	assertTrue(af[i].equals(an[i]));
	    }
	}
	
	@Test
	public void testConstructor5() {
		Alignment[] af = stub1();
		GenericMapping gm1 = new GenericMapping(af);
		GenericMapping gm2 = new GenericMapping(af);
		CanonicalMapping cm1 = gm1.getCanonicalMapping();
		CanonicalMapping cm2 = gm2.getCanonicalMapping();
		assertTrue(cm1 != null);
		assertTrue(cm2 != null);
		assertTrue(cm1 != cm2);
		assertTrue(cm1.equals(cm2));
	}
	
	@Test
	public void testConstructor6() {
		Alignment[] af = stub2();
		GenericMapping gm1 = new GenericMapping(af);
		GenericMapping gm2 = new GenericMapping(af);
		CanonicalMapping cm1 = gm1.getCanonicalMapping();
		CanonicalMapping cm2 = gm2.getCanonicalMapping();
		assertTrue(cm1 != null);
		assertTrue(cm2 != null);
		assertTrue(cm1 != cm2);
		assertTrue(cm1.equals(cm2));
	}

	@Test
	public void testShiftForward() {
		Alignment[] af = stub1();
		GenericMapping gm = new GenericMapping(af);
		gm.minimise(); // unlink alignments
		gm.applyShiftToReferencePosition(+10);
		Alignment[] an = gm.getAlignments();
	    assertEquals(af.length,an.length);
	    for (int i = 0 ; i < af.length ; i++) {
	    	an[i].applyOffsetsAndDirection(-10,0,Direction.FORWARD);
	    	assertTrue(af[i].equals(an[i]));
	    }
	}

	@Test
	public void testShiftReverse() {
		Alignment[] af = stub2();
		GenericMapping gm = new GenericMapping(af);
		gm.minimise();
		gm.applyShiftToReferencePosition(+10);
		Alignment[] an = gm.getAlignments();
	    assertEquals(af.length,an.length);
	    for (int i = 0 ; i < af.length ; i++) {
	    	System.out.println("test8  before "+an[i].toString());
	    	an[i].applyOffsetsAndDirection(-10, 0,Direction.FORWARD);
	    	System.out.println("test8 shifted "+an[i].toString());
	    	System.out.println("test8 compare "+af[i].toString());
	    	assertTrue(af[i].equals(an[i]));
	    }
	}	
	
	
	// Stubs
	
	private Alignment[] stub1() {
	    Alignment[] af = new Alignment[6];
	    af[0] = new Alignment( 737,1414, 124, 801);
	    af[1] = new Alignment(1417,1430, 802, 815);
	    af[2] = new Alignment(1432,1440, 816, 824);
	    af[3] = new Alignment(1442,1448, 825, 831);
	    af[4] = new Alignment(1450,1455, 832, 837);
	    af[5] = new Alignment(1457,1464, 838, 845);
		Arrays.sort(af);
	    return af;
	}
	
	private Alignment[] stub2() {
	    Alignment[] af = new Alignment[5];
	    af[0] = new Alignment( 737,1414, 801, 124);
	    af[1] = new Alignment(1417,1430, 124, 111);
	    af[2] = new Alignment(1432,1440, 110, 102);
	    af[3] = new Alignment(1442,1448, 101,  95);
	    af[4] = new Alignment(1450,1455,  94,  89);
		Arrays.sort(af);
	    return af;
	}
	
	private Alignment[] stub3() {
	    Alignment[] af = new Alignment[1];
	    af[0] = new Alignment(1414,1414, 801, 801);
	    return af;
	}
	
	private void list (Alignment[] af) {
	    for (int i=0 ; i < af.length ; i++) {
	    	report("nr " + i + " " + af[i].toString());
	    }
	}
	
	public static void report(String report) {
		System.err.println(report);
	}

}
