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

public class Range {
	protected int start;
	protected int end;
	
	public Range(int start, int end) {
		this.start = start;
		this.end = end;
	}
	
	public int getStart() {
		return start;
	}
	
	public int getEnd() {
		return end;
	}
	
	public Direction getDirection() {
		if (start < end)
			return Direction.FORWARD;
		
		if (start > end)
			return Direction.REVERSE;
			
		return Direction.UNKNOWN;
	}

	public int getLength() {
		return (start < end) ? 1 + end - start : 1 + start - end; 
	}
	
	public boolean contains(int pos) {
		if (start < end)
			return start <= pos && pos <= end;
		else
			return start >= pos && pos >= end;
	}

    public Range reverse() {
        return new Range(end,start);
    }

	public Range copy() {
		return new Range(start,end);
	}
	
	public Range offset(int shift) {
		start += shift;
		end += shift;
		return this;
	}
	
	public Range mirror(int shift) {
		start = shift - start;
		end = shift - end;
		return this;
	}
	
	public boolean equals(Range that) {
		return (this.start == that.start && this.end == that.end);
	}
	
	public String toString() {
		return "Range[" + start + ".." + end + "]";
	}
}
