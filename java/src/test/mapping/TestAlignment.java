package test.mapping;

import static org.junit.Assert.*;

import java.util.Arrays;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.*;
//import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class TestAlignment {
	private GenericMapping.Direction forward = GenericMapping.Direction.FORWARD;
	private GenericMapping.Direction reverse = GenericMapping.Direction.REVERSE;
	private GenericMapping.Direction unknown = GenericMapping.Direction.UNKNOWN;
	private GenericMapping.Direction direction;
	private AssembledFrom af;
	private AssembledFrom fa;
	private Alignment alignment;
	@Test
	public void testConstructor() {
		af = new AssembledFrom(737,1414,124,801);
		assertEquals(737,af.getReferenceRange().getStart());
		assertEquals(1414,af.getReferenceRange().getEnd());
		assertEquals(124,af.getSubjectRange().getStart());
		assertEquals(801,af.getSubjectRange().getEnd());
	    fa = new AssembledFrom(1414,737,801,124);
		assertEquals(737,fa.getReferenceRange().getStart());
		assertEquals(1414,fa.getReferenceRange().getEnd());
		assertEquals(124,fa.getSubjectRange().getStart());
		assertEquals(801,fa.getSubjectRange().getEnd());
	}
	@Test(expected=IllegalArgumentException.class)
	public void testConstructorFail() {
		af = new AssembledFrom(737,1414,124,800);	    
		af = new AssembledFrom(new Range(737,1414),null);
	    af = new AssembledFrom(null,new Range(124,801));
		af = new AssembledFrom(null,null);
	}

	@Test
	public void testDirectionForward() {
		af = new AssembledFrom(737,1414,124,801);	    
		assertEquals(forward,af.getDirection());
	}
	@Test
	public void testDirectionReturn() {
		af = new AssembledFrom(737,1414,801,124);	    
		assertEquals(reverse,af.getDirection());
	}
	@Test
	public void testDirectionUnknown() {
		af = new AssembledFrom(737,737,801,801);	    
		assertEquals(unknown,af.getDirection());		
	}

	@Test
    public void testInverseForward() {
		af = new AssembledFrom(737,1414,124,801);	    
        alignment = af.getInverse();
        fa = af.getInverse();
        assertFalse(af == fa);
        assertFalse(alignment == af);
        assertFalse(alignment == fa);
        assertTrue(af.equals(fa.getInverse()));
        assertTrue(af.equals(alignment.getInverse()));
	}
	@Test
    public void testInverseReverse() {
		af = new AssembledFrom(737,1414,801,124);	    
        fa = af.getInverse();
        assertFalse(af == fa);
        assertTrue(af.equals(fa.getInverse()));
 	}
	@Test
    public void toSegmentForward() {
		af = new AssembledFrom(737,1414,124,801);	    
		BasicSegment segment = af.getSegment();		
		assertEquals(737,segment.getReferenceStart());
		assertEquals(124,segment.getSubjectStart());
		assertEquals(1414-737+1,segment.getLength());
	}
	@Test
    public void toSegmentReverse() {
		af = new AssembledFrom(737,1414,801,124);	    
		BasicSegment segment = af.getSegment();			 		
		assertEquals(1414,segment.getReferenceStart());
		assertEquals(124,segment.getSubjectStart());
	}
	
	@Test
	public void testAlignmentDirectionForList() {
		AssembledFrom[] af = stub1();
		assertEquals(forward,Alignment.getDirection(af));
		AssembledFrom[] fa = stub2();
		assertEquals(reverse,Alignment.getDirection(fa));
		AssembledFrom[] uu = stub3();
		assertEquals(unknown,Alignment.getDirection(uu));
	}
	
	@Test
	public void testRemappingForward() {
		af = new AssembledFrom(737,1414,124,801);
		assertEquals(737,af.getReferencePositionForSubjectPosition(124));
		assertEquals(1414,af.getReferencePositionForSubjectPosition(801));
		assertEquals(737+35,af.getReferencePositionForSubjectPosition(124+35));
		assertEquals(124,af.getSubjectPositionForReferencePosition(737));
		assertEquals(801,af.getSubjectPositionForReferencePosition(1414));
		assertEquals(124+55,af.getSubjectPositionForReferencePosition(737+55));	

		assertEquals(-1,af.getReferencePositionForSubjectPosition(123));
		assertEquals(-1,af.getReferencePositionForSubjectPosition(802));
		assertEquals(-1,af.getSubjectPositionForReferencePosition(736));
		assertEquals(-1,af.getSubjectPositionForReferencePosition(1415));
	}
	@Test
	public void testRemappingReverse() {
		af = new AssembledFrom(737,1414,801,124);	    
		assertEquals(1414,af.getReferencePositionForSubjectPosition(124));
		assertEquals(737,af.getReferencePositionForSubjectPosition(801));
		assertEquals(1414-35,af.getReferencePositionForSubjectPosition(124+35));
		assertEquals(124,af.getSubjectPositionForReferencePosition(1414));
		assertEquals(801,af.getSubjectPositionForReferencePosition(737));
		assertEquals(801-55,af.getSubjectPositionForReferencePosition(737+55));	

		assertEquals(-1,af.getReferencePositionForSubjectPosition(123));
		assertEquals(-1,af.getReferencePositionForSubjectPosition(802));
		assertEquals(-1,af.getSubjectPositionForReferencePosition(736));
		assertEquals(-1,af.getSubjectPositionForReferencePosition(1415));
	}
	
	@Test
	public void testPlacementForward() {
		AssembledFrom[] af = stub1();
		int segment = Utility.locateElement(af,1400);
		assertEquals(0,segment);
		segment = Utility.locateElement(af,1448);
		assertEquals(3,segment);
		segment = Utility.locateElement(af,1417);
		assertEquals(1,segment);
		segment = Utility.locateElement(af,1450);
		assertEquals(4,segment);
		segment = Utility.locateElement(af,1431);
		assertEquals(-1,segment);
	}
	@Test
	public void testPlacementReverse() {
		AssembledFrom[] af = stub2();	    
		list(af);
		int segment = Utility.locateElement(af,1400,false);
		Utility.report("segment for 1400 " + segment);
		assertEquals(4,segment);
		segment = Utility.locateElement(af,1448,false);
		Utility.report("segment for 1448 " + segment);
		assertEquals(1,segment);
		segment = Utility.locateElement(af,1417,false);
		Utility.report("segment for 1417 " + segment);
		assertEquals(3,segment);
		segment = Utility.locateElement(af,1450,false);
		Utility.report("segment for 1450 " + segment);
		assertEquals(0,segment);
		segment = Utility.locateElement(af,1431,false);
		Utility.report("segment for 1431 " + segment);
		assertEquals(-1,segment);
	}
	
	// Stubs
	
	private AssembledFrom[] stub1() {
	    AssembledFrom[] af = new AssembledFrom[6];
	    af[0] = new AssembledFrom( 737,1414, 124, 801);
	    af[1] = new AssembledFrom(1417,1430, 802, 815);
	    af[2] = new AssembledFrom(1432,1440, 816, 824);
	    af[3] = new AssembledFrom(1442,1448, 825, 831);
	    af[4] = new AssembledFrom(1450,1455, 832, 837);
	    af[5] = new AssembledFrom(1457,1464, 838, 845);
		Arrays.sort(af);
	    return af;
	}
	
	private AssembledFrom[] stub2() {
	    AssembledFrom[] af = new AssembledFrom[5];
	    af[0] = new AssembledFrom( 737,1414, 801, 124);
	    af[1] = new AssembledFrom(1417,1430, 124, 111);
	    af[2] = new AssembledFrom(1432,1440, 110, 102);
	    af[3] = new AssembledFrom(1442,1448, 101,  95);
	    af[4] = new AssembledFrom(1450,1455,  94,  89);
		Arrays.sort(af);
	    return af;
	}
	
	private AssembledFrom[] stub3() {
	    AssembledFrom[] af = new AssembledFrom[1];
	    af[0] = new AssembledFrom(1414,1414, 801, 801);
	    return af;
	}
	
	private void list (Alignment[] af) {
	    for (int i=0 ; i < af.length ; i++) {
	    	Utility.report("nr " + i + " " + af[i].toString());
	    }
	}
}

// public 
