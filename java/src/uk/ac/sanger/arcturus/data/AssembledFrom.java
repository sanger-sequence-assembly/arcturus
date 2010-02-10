package uk.ac.sanger.arcturus.data;

public class AssembledFrom {
	protected Range readRange;
	protected Range contigRange;
	
	public AssembledFrom(Range readRange, Range contigRange) {
		this.readRange = readRange;
		this.contigRange = contigRange;
	}
	
	public Range getReadRange() {
		return readRange;
	}
	
	public Range getContigRange() {
		return contigRange;
	}
}
