package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.ReadToContigMapping.Direction;

public class AssembledFrom extends Alignment {
	
	public AssembledFrom(Range contigRange, Range readRange) throws IllegalArgumentException {
        super(contigRange,readRange);
		if (readRange == null)
			throw new IllegalArgumentException("read range cannot be null");
		
		if (contigRange == null)
			throw new IllegalArgumentException("contig  range cannot be null");
		
		if (readRange.getDirection() == Direction.REVERSE)
			throw new IllegalArgumentException("read range cannot be reversed");
	}
	
	public Range getReadRange() {
		return getSubjectRange();
	}
	
	public Range getContigRange() {
		return getReferenceRange();
	}

	public String toString() {
	    return "Assembled_from " + getContigRange().toString() + " " + getReadRange().toString();
	}
}	

