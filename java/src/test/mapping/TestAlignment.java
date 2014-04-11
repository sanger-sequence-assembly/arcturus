// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package test.mapping;

import static org.junit.Assert.*;

import java.util.Arrays;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class TestAlignment {
	private Direction forward = Direction.FORWARD;
	private Direction reverse = Direction.REVERSE;
	private Direction unknown = Direction.UNKNOWN;
//	private Direction direction;
	private Alignment af;
	private Alignment fa;
	private Alignment alignment;
	@Test
	public void testConstructor() {
		af = new Alignment(737,1414,124,801);
		assertEquals(737,af.getReferenceRange().getStart());
		assertEquals(1414,af.getReferenceRange().getEnd());
		assertEquals(124,af.getSubjectRange().getStart());
		assertEquals(801,af.getSubjectRange().getEnd());
	    fa = new Alignment(1414,737,801,124);
		assertEquals(737,fa.getReferenceRange().getStart());
		assertEquals(1414,fa.getReferenceRange().getEnd());
		assertEquals(124,fa.getSubjectRange().getStart());
		assertEquals(801,fa.getSubjectRange().getEnd());
	}
	@Test(expected=IllegalArgumentException.class)
	public void testConstructorFail() {
		af = new Alignment(737,1414,124,800);	    
		af = new Alignment(new Range(737,1414),null);
	    af = new Alignment(null,new Range(124,801));
		af = new Alignment(null,null);
	}

	@Test
	public void testDirectionForward() {
		af = new Alignment(737,1414,124,801);	    
		assertEquals(forward,af.getDirection());
	}
	@Test
	public void testDirectionReturn() {
		af = new Alignment(737,1414,801,124);	    
		assertEquals(reverse,af.getDirection());
	}
	@Test
	public void testDirectionUnknown() {
		af = new Alignment(737,737,801,801);	    
		assertEquals(unknown,af.getDirection());		
	}

	@Test
    public void testInverseForward() {
		af = new Alignment(737,1414,124,801);	    
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
		af = new Alignment(737,1414,801,124);	    
        fa = af.getInverse();
        assertFalse(af == fa);
        assertTrue(af.equals(fa.getInverse()));
 	}
	@Test
    public void toSegmentForward() {
		af = new Alignment(737,1414,124,801);	    
		BasicSegment segment = af.getSegment();		
		assertEquals(737,segment.getReferenceStart());
		assertEquals(124,segment.getSubjectStart());
		assertEquals(1414-737+1,segment.getLength());
	}
	@Test
    public void toSegmentReverse() {
		af = new Alignment(737,1414,801,124);	    
		BasicSegment segment = af.getSegment();			 		
		assertEquals(1414,segment.getReferenceStart());
		assertEquals(124,segment.getSubjectStart());
	}
	
	@Test
	public void testAlignmentDirectionForList() {
		Alignment[] af = stub1();
		assertEquals(forward,Alignment.getDirection(af));
		Alignment[] fa = stub2();
		assertEquals(reverse,Alignment.getDirection(fa));
		Alignment[] uu = stub3();
		assertEquals(unknown,Alignment.getDirection(uu));
	}
	
	@Test
	public void testRemappingForward() {
		af = new Alignment(737,1414,124,801);
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
		af = new Alignment(737,1414,801,124);	    
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
		Alignment[] af = stub1();
		int segment = Traverser.locateElement(af,1400);
		assertEquals(0,segment);
		segment = Traverser.locateElement(af,1448);
		assertEquals(3,segment);
		segment = Traverser.locateElement(af,1417);
		assertEquals(1,segment);
		segment = Traverser.locateElement(af,1450);
		assertEquals(4,segment);
		segment = Traverser.locateElement(af,1431);
		assertEquals(-1,segment);
	}
	@Test
	public void testPlacementReverse() {
		Alignment[] af = stub2();	    
//		list(af);
		int segment = Traverser.locateElement(af,1400,Direction.REVERSE);
//		report("segment for 1400 " + segment);
		assertEquals(4,segment);
		segment = Traverser.locateElement(af,1448,Direction.REVERSE);
//		report("segment for 1448 " + segment);
		assertEquals(1,segment);
		segment = Traverser.locateElement(af,1417,Direction.REVERSE);
//		report("segment for 1417 " + segment);
		assertEquals(3,segment);
		segment = Traverser.locateElement(af,1450,Direction.REVERSE);
//		report("segment for 1450 " + segment);
		assertEquals(0,segment);
		segment = Traverser.locateElement(af,1431,Direction.REVERSE);
//		report("segment for 1431 " + segment);
		assertEquals(-1,segment);
	}
	
	@Test
	public void testCoalesceForward() {
		Alignment[] af = stub4();	    
//		list(af);
		Alignment[] afc = Alignment.coalesce(af);
//		list(afc);
		assertTrue(af != afc);
		Alignment[] afd = Alignment.coalesce(af,1);
//		list(afd);
		assertTrue(af != afd);
// other tests
	}
	
	@Test
	public void testCoalesceReverse() {
		Alignment[] af = stub5();	    
//		list(af);
		Alignment[] afc = Alignment.coalesce(af);
//		list(afc);
		assertTrue(af != afc);
		Alignment[] afd = Alignment.coalesce(af,1);
		list(afd);
		assertTrue(af != afd);
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
	    af[0] = new Alignment( 1414,1414, 801, 801);
	    return af;	
	}
	
	private Alignment[] stub4() {
	    Alignment[] af = new Alignment[6];
	    af[0] = new Alignment( 737,1414, 124, 801);
	    af[1] = new Alignment(1417,1430, 802, 815);
	    af[2] = new Alignment(1432,1440, 816, 824);
	    af[3] = new Alignment(1442,1448, 826, 832);
	    af[4] = new Alignment(1449,1454, 833, 838);
	    af[5] = new Alignment(1457,1464, 839, 846);
		Arrays.sort(af);
	    return af;
	}
	
	private Alignment[] stub5() {
	    Alignment[] af = new Alignment[6];
	    af[0] = new Alignment(1414, 737, 124, 801);
	    af[1] = new Alignment(1430,1417, 802, 815);
	    af[2] = new Alignment(1440,1432, 816, 824);
	    af[3] = new Alignment(1448,1442, 826, 832);
	    af[4] = new Alignment(1454,1449, 833, 838);
	    af[5] = new Alignment(1464,1457, 839, 846);
		Arrays.sort(af);
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

// public 
