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
		return start + " " + end;
	}
}
