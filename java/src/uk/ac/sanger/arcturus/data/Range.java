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
	
	public GenericMapping.Direction getDirection() {
		if (start < end)
			return GenericMapping.Direction.FORWARD;
		
		if (start > end)
			return GenericMapping.Direction.REVERSE;
			
		return GenericMapping.Direction.UNKNOWN;
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
	
	public void offset(int shift) {
		start += shift;
		end += shift;
	}
	
	public void mirror(int shift) {
		start = shift - start;
		end = shift - end;
	}
	
	public String toString() {
		return start + " " + end;
	}
}
