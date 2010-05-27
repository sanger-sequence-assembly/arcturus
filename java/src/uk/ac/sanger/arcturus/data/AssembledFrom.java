package uk.ac.sanger.arcturus.data;

// import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class AssembledFrom extends Alignment {
	
	public AssembledFrom(Range contigRange, Range readRange) throws IllegalArgumentException {
		super(contigRange,readRange);
	}
	
	public Range getReadRange() {
		return getSubjectRange();
	}
	
	public Range getContigRange() {
		return getReferenceRange();
	}

	public String toString() {
	    return "Assembled_from " + super.toString();
	}
}

