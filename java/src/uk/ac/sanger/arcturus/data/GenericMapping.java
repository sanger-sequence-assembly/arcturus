package uk.ac.sanger.arcturus.data;

import java.util.*;

public class GenericMapping<S,R> implements Comparable<GenericMapping> {
	public static enum Direction { FORWARD , REVERSE, UNKNOWN }

	private final S subject;
	private final R reference;
	
	protected int referenceOffset;
	protected int subjectOffset;
	protected Direction direction;
	protected CanonicalMapping cm;
	protected Alignment[] alignments;
	protected Range referenceRange;
	protected Range subjectRange;
	
	public GenericMapping(S subject, R reference, CanonicalMapping cm, int referenceOffset, int subjectOffset, Direction direction) {
		// Constructor to be used building mapping from database
		this.subject = subject;
		this.reference = reference;
		this.cm = cm;
		this.referenceOffset = referenceOffset;
		this.subjectOffset = subjectOffset;
		this.direction = direction;
		putRanges();
	}
	
	public GenericMapping(S subject, R reference, Alignment[] alignments) {
		// Constructor to be used building Mapping from a list of alignments
		this.subject = subject;
		this.reference = reference;
		this.alignments = alignments;

		Arrays.sort(alignments);		
		direction = Alignment.getDirection(alignments);
		
		buildCanonicalMapping();
		putRanges();
	}
	
	public GenericMapping(S subject, R reference, GenericMapping gm) { // ?needed?
        this(subject,reference,gm.getAlignments());
	}
	
	public GenericMapping(S subject, R reference) {
		this.subject = subject;
		this.reference = reference;
 	}

	public GenericMapping(CanonicalMapping cm, int referenceOffset, int subjectOffset, Direction direction) {
		this(null,null,cm,referenceOffset,subjectOffset,direction);
	}

	public GenericMapping(Alignment[] alignments) {
	    this(null,null,alignments);
	}

	public S getSubject() {
	    return subject;
	}
	
	public R getReference() {
		return reference;
	}
	
	public CanonicalMapping getCanonicalMapping() {
		if (cm == null && alignments != null) 
			buildCanonicalMapping();
		return cm;
	}
	
	public void replaceCanonicalMapping(CanonicalMapping mapping) {
		// replace only by a canonical mapping with identical checksum
	    if (this.cm == null || this.cm.equals(mapping))
	    	this.cm = mapping;
	}

	public int getReferenceOffset() {
		return referenceOffset;
	}

	public int getSubjectOffset() {
		return subjectOffset;
	}
	
	public Direction getDirection() {
		return direction;
	}
	
	public boolean isForward() {
		return (direction != Direction.REVERSE);
	}
	
	public Alignment[] getAlignments() {
	    if (alignments != null)
	    	return alignments;
	    if (cm == null || cm.getSegments() == null)
	    	return null;
	    BasicSegment segments[] = cm.getSegments();
        int numberOfSegments = segments.length;
        Alignment[] alignments = new Alignment[numberOfSegments];
        for (int i = 0 ; i < numberOfSegments ; i++) {
            alignments[i] = segments[i].getAlignment();
            alignments[i].fromCanonicalAlignment(referenceOffset, subjectOffset, direction);
       }
        return alignments;
    }
	
	public int getReferenceStart () {
	    return referenceRange.getStart();
	}
	
	public int getReferenceEnd () {
	    return referenceRange.getEnd();
	}
	
	public int getSubjectStart () {
	    return subjectRange.getStart();
	}
	
	public int getSubjectEnd () {
	    return subjectRange.getEnd();
	}
	
	public int compareTo(GenericMapping that) {
	    return this.getReferenceStart() - that.getReferenceStart();
	}
	
	public boolean equals(GenericMapping that) {
		if (this.isCongruentWith(that)) {
			if (this.referenceOffset == that.referenceOffset 
		       && this.subjectOffset == that.subjectOffset)
				return true;
		}
		return false;
	}
	
	public boolean isCongruentWith(GenericMapping that) {
		getCanonicalMapping();
		if (cm == null) 
			return false;
		return cm.equals(that.getCanonicalMapping());
	}

	public void applyShiftToReferencePosition(int shift) {
		getCanonicalMapping(); // will build CM from existing alignments if not yet done
		if (cm == null) 
			return;
		referenceOffset += shift;
		alignments = null; // forces rebuild from canonical mapping
	}

	public void mirrorReferencePosition(int mirrorPosition) {
		getCanonicalMapping(); // will build CM from existing alignments if not yet done
		if (cm == null) 
			return;
		referenceOffset = mirrorPosition - referenceOffset;
		if (direction == Direction.FORWARD)
			direction = Direction.REVERSE;
		else if (direction == Direction.REVERSE)
			direction = Direction.FORWARD;
		alignments = null; // forces rebuild from canonical mapping
	}
	
	public void minimise() {
	    alignments = null;
	}
	
	private void buildCanonicalMapping() {
// build the canonical mapping and offsets given the alignments	
System.out.println("BuildCanonicalMapping");
        subjectOffset = alignments[0].getSubjectRange().getStart() - 1;
        
	    referenceOffset = alignments[0].getReferenceRange().getStart();	
  	    if (direction == Direction.FORWARD)
		    referenceOffset -= 1;
	    else
		    referenceOffset += 1;
	
  	    BasicSegment[] segments = new BasicSegment[alignments.length];
	
	    for (int i = 0; i < alignments.length; i++) {
             Alignment alignment = alignments[i].copy(); // insulate original
		     alignment.toCanonicalAlignment(referenceOffset,subjectOffset,direction);
             segments[i] = alignment.getSegment();
	    }
	    
		this.cm = new CanonicalMapping(segments);
	}
	
	private void putRanges () {
// determine ranges (both as forward ranges) from characteristics of the canonical mapping
		subjectRange = new Range(subjectOffset + 1,subjectOffset + cm.getSubjectSpan());
		if (isForward())
	   	    referenceRange = new Range(referenceOffset + 1,referenceOffset + cm.getReferenceSpan());
		else 
  		    referenceRange = new Range(referenceOffset - cm.getReferenceSpan(),referenceOffset - 1);
	}
} 
