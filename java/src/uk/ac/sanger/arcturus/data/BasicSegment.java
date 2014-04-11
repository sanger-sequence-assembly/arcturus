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

package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

/**
 * An object which represents a single contiguous segment of a co-aligned 
 * mapping between a reference sequence and a subject sequence
 * 
 * It has a start position on the reference sequence, a start position on
 * the subject sequence and a length. 
 */

public class BasicSegment implements Comparable<BasicSegment>,Traversable {
	protected int referenceStart;
	protected int subjectStart;
	protected int length;

	/**
	 * Constructs a segment object with the given start positions and length.
	 * 
	 * @param referenceStart
	 *            the start position on the reference sequence, e.g. contig.
	 * @param subjectStart
	 *            the start position on the subject sequence, e.g. read
	 * @param length
	 *            the length of this segment.
	 */

	public BasicSegment(int referenceStart, int subjectStart, int length) {
		this.referenceStart = referenceStart;
		this.subjectStart = subjectStart;
		if (length < 1) length = 1;
		this.length = length;
	}

	public int getReferenceStart() {
		return referenceStart;
	}

	public int getReferenceFinish() {
		return referenceStart + length - 1;
	}

	public int getSubjectStart() {
		return subjectStart;
	}

	public int getSubjectFinish() {
		return subjectStart + length - 1;
	}
	
	public Range getReferenceRange() {
		return new Range(referenceStart, referenceStart + length - 1);
	}

	public Range getReferenceRange(int referenceOffset, GenericMapping.Direction direction) {
		// this functionality is also in Alignment:applyOffsetsAndDirection
		if (direction == GenericMapping.Direction.REVERSE)
			return getReferenceRange().mirror(referenceOffset);
		else 
			return getReferenceRange().offset(referenceOffset);	
		}
	
	public Range getSubjectRange() {
		return new Range(subjectStart, subjectStart + length - 1);
	}
	
	public Range getSubjectRange(int subjectOffset) {
		// this functionality is also in Alignment:applyOffsetsAndDirection
	    return getSubjectRange().offset(subjectOffset);
	}
	
	public Alignment getAlignment() {
		Alignment alignment = new Alignment(getReferenceRange(),getSubjectRange());
		return alignment;
	}

	public int getLength() {
		return length;
	}
	
	public int getSubjectPositionForReferencePosition(int rpos) {
		return getSubjectPositionForReferencePosition(rpos, Direction.FORWARD);
	}

	public int getSubjectPositionForReferencePosition(int rpos, Direction direction) {
		rpos -= referenceStart;
		if (direction == Direction.REVERSE)
			rpos = -rpos;
		
		if (rpos < 0 || rpos >= length)
			return -1;
		else
			return subjectStart + rpos;
	}
	
	public int getReferencePositionForSubjectPosition(int spos) {
		return getReferencePositionForSubjectPosition(spos, Direction.FORWARD);
	}

	public int getReferencePositionForSubjectPosition(int spos, Direction direction) {
		spos -= subjectStart;
		if (spos < 0 || spos >= length)
			return -1;
		else if (direction == Direction.REVERSE)
			spos = -spos;
		
		return referenceStart + spos;
	}
	
	public Placement getPlacementOfPosition(int rpos) {
		rpos -= referenceStart;
		if (rpos < 0)
			return Placement.AT_LEFT;
		else if (rpos >= length)
			return Placement.AT_RIGHT;
		else
			return Placement.INSIDE;
	}

	public int compareTo(BasicSegment that) {
		return this.subjectStart - that.subjectStart;
	}
	
	public String toString() {
		return "Segment[refstart=" + referenceStart + ", substart=" + subjectStart + ", length=" + length + "]";
	}	
}
