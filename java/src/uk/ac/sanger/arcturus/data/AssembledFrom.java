package uk.ac.sanger.arcturus.data;

// import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class AssembledFrom extends Alignment {
	
	public AssembledFrom(Range contigRange, Range readRange) throws IllegalArgumentException {
        super(contigRange,readRange);
		if (super.getReferenceRange().getLength() != super.getSubjectRange().getLength()) {
		    throw new IllegalArgumentException("read and contig ranges must be equal size");	
		}
		// the next one may be redundant as the super class aligns on subjectRange
		if (super.getSubjectRange().getDirection() == GenericMapping.Direction.REVERSE)
			throw new IllegalArgumentException("read range cannot be reversed");
	}
	
	public AssembledFrom(int rStart, int rEnd, int sStart, int sEnd) throws IllegalArgumentException {
		this(new Range(rStart,rEnd), new Range(sStart,sEnd));
	}
	
	public AssembledFrom(Alignment alignment) throws IllegalArgumentException {
		this(alignment.getReferenceRange(),alignment.getSubjectRange());
	}
	
	public Range getReadRange() {
		return getSubjectRange();
	}
	
	public Range getContigRange() {
		return getReferenceRange();
	}
	
	public AssembledFrom getInverse() {
		return new AssembledFrom(super.getInverse());
	}

	public String toString() {
	    return "Assembled_from " + super.toString();
	}
}

