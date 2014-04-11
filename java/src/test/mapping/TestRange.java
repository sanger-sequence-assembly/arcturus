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

import org.junit.Test;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class TestRange {
	private Direction forward = Direction.FORWARD;
	private Direction reverse = Direction.REVERSE;
	private Direction unknown = Direction.UNKNOWN;
	@Test
	public void testConstructor() {
		assertEquals(10,new Range(10,19).getStart());
		assertEquals(19,new Range(10,19).getEnd());
	}
	@Test
	public void testDirectionForward() {
		assertEquals(forward,new Range(10,19).getDirection());
	}
	@Test
	public void testDirectionReverse() {
		assertEquals(reverse,new Range(21,19).getDirection());
	}
	@Test
	public void testDirectionUnknown() {
		assertEquals(unknown,new Range(21,21).getDirection());
	}
	@Test
	public void testLengthForward() {
		assertTrue(new Range(21,22).getLength() > 0);
	}
	@Test
	public void testLengthReverse() {
		assertTrue(new Range(22,21).getLength() > 0);
	}
	@Test
	public void testLength() {
		assertTrue(new Range(22,22).getLength() > 0);
	}
	@Test
    public void testContainsForward() {
		Range range = new Range(10,20);
		assertTrue(range.contains(15));
		assertTrue(range.contains(20));
		assertTrue(range.contains(10));
		assertFalse(range.contains(9));
		assertFalse(range.contains(21));
	}
	@Test
    public void testContainsReverse() {
		Range range = new Range(20,10);
		assertTrue(range.contains(15));
		assertTrue(range.contains(20));
		assertTrue(range.contains(10));
		assertFalse(range.contains(9));
		assertFalse(range.contains(21));
	}
	@Test
    public void testContains() {
		assertTrue(new Range(10,10).contains(10));
	}
	@Test
    public void testEquals() {
		Range range1 = new Range(10,20);
		Range range2 = new Range(10,20);
		assertTrue(range1.equals(range2));
	}
	@Test
    public void testReverse() {
		Range range1 = new Range(10,20);
		Range range2 = range1.reverse();
		assertFalse(range1.equals(range2));
		assertTrue(range1.equals(range2.reverse()));
	}
	@Test
    public void testCopy() {
		Range range1 = new Range(10,20);
		Range range2 = range1.copy();
		assertFalse(range1 == range2);
		assertTrue(range1.equals(range2));
	}
	@Test
	public void testOffset() {
		Range range1 = new Range(10,20);
		Range range2 = range1.copy();
	    range2.offset(-4);
		assertTrue(range1.equals(range2.offset(+4)));
	}
	@Test
	public void testMirror() {
		Range range1 = new Range(10,20);
		Range range2 = range1.copy();
		range2.mirror(30);
		assertTrue(range2.getDirection() == reverse);
		assertTrue(range1.equals(range2.mirror(30)));
	}
	
	@Test
	public void list() {
		Range range1 = new Range(10,20);
		Range range2 = range1.reverse();
		System.out.println(range1.toString());
		System.out.println(range2.toString());
	}
}
