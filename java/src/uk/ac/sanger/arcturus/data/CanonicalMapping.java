package uk.ac.sanger.arcturus.data;

import java.util.Arrays;

public class CanonicalMapping {
	protected int ID;
	protected int rspan;
	protected int cspan;
	protected byte[] hash;
	protected CanonicalSegment[] segments;
	
	public CanonicalMapping(int ID, CanonicalSegment[] segments) {
		this.ID = ID;
		setSegments(segments); 
	}
	
	public void setSegments(CanonicalSegment[] segments) {
		this.segments = segments;
		
		if (this.segments != null) {
			Arrays.sort(this.segments);
		
			CanonicalSegment lastSegment = segments[segments.length - 1];
			
			rspan = lastSegment.getReadFinish();
			cspan = lastSegment.getContigFinish();
		}
	}
	
	public CanonicalSegment[] getSegments() {
		return segments;
	}
	
	public int getReadSpan() {
		return rspan;
	}
	
	public int getContigSpan() {
		return cspan;
	}
	
	public int getReadPositionFromContigPosition(int cpos) {
		if (segments == null)
			return -1;
		
		report("CanonicalMapping.getReadPositionFromContigPosition(" + cpos + ")");
		
		for (CanonicalSegment segment : segments) {
			report("\tExamining " + segment);
			if (segment.containsContigPosition(cpos)) {
				return segment.getReadOffset(cpos);
			}
		}
		
		return -1;
	}
	
	private void report(String message) {
		//System.err.println(message);
	}

	public float getPadPositionFromContigPosition(int deltaC) {
		return 0;
	}
}
