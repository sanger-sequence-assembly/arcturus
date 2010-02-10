package uk.ac.sanger.arcturus.data;

public class Range {
	public enum Sense {
		FORWARD, REVERSE, UNKNOWN;
	}
	
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
	
	public Sense getSense() {
		if (start < end)
			return Sense.FORWARD;
		
		if (start > end)
			return Sense.REVERSE;
			
		return Sense.UNKNOWN;
	}
	
	public int getLength() {
		return (start < end) ? 1 + end - start : 1 + start - end; 
	}
}
