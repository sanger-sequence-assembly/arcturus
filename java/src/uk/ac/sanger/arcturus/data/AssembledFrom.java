package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.ReadToContigMapping.Direction;

public class AssembledFrom implements Comparable<AssembledFrom> {
	protected Range readRange;
	protected Range contigRange;
	
	public AssembledFrom(Range contigRange, Range readRange) throws IllegalArgumentException {
		if (readRange == null)
			throw new IllegalArgumentException("Read range cannot be null");
		
		if (contigRange == null)
			throw new IllegalArgumentException("Contig range cannot be null");
		
		if (readRange.getDirection() == Direction.REVERSE)
			throw new IllegalArgumentException("Read range cannot be reveresed");
		
		this.readRange = readRange;
		this.contigRange = contigRange;
	}
	
	public Range getReadRange() {
		return readRange;
	}
	
	public Range getContigRange() {
		return contigRange;
	}

	public int compareTo(AssembledFrom that) {
		return this.readRange.getStart() - that.readRange.getStart();
	}
	
	public static Direction getDirection(AssembledFrom[] afdata) {
		// If no segments, we can't infer a direction.
		if (afdata == null || afdata.length == 0)
			return Direction.UNKNOWN;
		
		// Try to infer direction from one of the segments.
		for (int i = 0; i < afdata.length; i++) {
			if (afdata[i] != null) {
				Direction dir = afdata[i].getDirection();
				if (dir != Direction.UNKNOWN)
					return dir;
			}
		}
		
		// All of the segments are apparently single-base or null.
		// Try to find two non-null segments and infer the direction
		// from them.
		AssembledFrom seg1 = null;
		AssembledFrom seg2 = null;
		
		for (int i = 0; i < afdata.length; i++) {
			if (afdata[i] != null) {
				if (seg1 == null)
					seg1 = afdata[i];
				else if (seg2 == null) {
					seg2 = afdata[i];
					break;
				}
			}
		}
		
		// We failed to find two non-null segments.
		if (seg1 == null || seg2 == null)
			return Direction.UNKNOWN;
		
		int readDelta = seg1.getReadRange().getStart() - seg2.getReadRange().getStart();
		int contigDelta = seg1.getContigRange().getStart() - seg2.getContigRange().getStart();
		
		int signum = readDelta * contigDelta;
		
		if (signum > 0)
			return Direction.FORWARD;
		else if (signum < 0)
			return Direction.REVERSE;
		else
			return Direction.UNKNOWN;
	}
	
	public Direction getDirection() {
		if (readRange == null || contigRange == null)
			return Direction.UNKNOWN;
		
		Direction readDirection = readRange.getDirection();
		
		Direction contigDirection = contigRange.getDirection();
	
		if (readDirection == Direction.UNKNOWN || contigDirection == Direction.UNKNOWN)
			return Direction.UNKNOWN;
		
		return readDirection == contigDirection ? Direction.FORWARD : Direction.REVERSE;
	}
}
