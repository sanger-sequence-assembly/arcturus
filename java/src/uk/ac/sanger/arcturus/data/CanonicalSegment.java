package uk.ac.sanger.arcturus.data;

public class CanonicalSegment implements Comparable<CanonicalSegment> {
	protected int cstart;
	protected int rstart;
	protected int length;
	
	public CanonicalSegment(int cstart, int rstart, int length) {
		this.cstart = cstart;
		this.rstart = rstart;
		this.length = length;
	}
	
	public int getReadStart() {
		return rstart;
	}
	
	public int getReadFinish() {
		return rstart + length - 1;
	}
	
	public Range getReadRange() {
		return new Range(rstart, rstart + length - 1);
	}
	
	public int getContigStart() {
		return cstart;
	}
	
	public int getContigFinish() {
		return cstart + length - 1;
	}
	
	public boolean containsContigPosition(int cpos) {
		return cstart <= cpos && cpos < cstart + length;
	}
	
	public boolean isLeftOfContigPosition(int cpos) {
		return cstart <= cpos;
	}
	
	public Range getContigRange() {
		return new Range(cstart, cstart + length - 1);
	}
	
	public int getLength() {
		return length;
	}
	
	public int getReadOffset(int cpos) {
		if (cpos < cstart || cpos >= cstart + length)
			return -1;
		else
			return rstart + (cpos - cstart);
	}
	
	public int compareTo(CanonicalSegment that) {
		return this.rstart - that.rstart;
	}
	
	public String toString() {
		return "CSeg[cstart=" + cstart + ", rstart=" + rstart + ", length=" + length + "]";
	}
}
