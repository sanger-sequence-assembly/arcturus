package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class Alignment implements Comparable<Alignment>,Traversable {
	private Range subjectRange;
	private Range referenceRange;
	
	public Alignment(Range referenceRange, Range subjectRange) throws IllegalArgumentException {
// constructor uses copy or reverse to ensure immutable alignment with forward subjectRange
		if (referenceRange == null || subjectRange == null) {
			throw new IllegalArgumentException("reference range and subject range cannot be null");
		}
		else if (referenceRange.getLength() != subjectRange.getLength()) {
		    throw new IllegalArgumentException("reference and subject ranges must be of equal size");	
		}
		else if (subjectRange.getDirection() == Direction.REVERSE) {
    		this.subjectRange   = subjectRange.reverse();
            this.referenceRange = referenceRange.reverse();
	    }
		else {
		    this.subjectRange   = subjectRange.copy();
		    this.referenceRange = referenceRange.copy();
		}
	}

	public Range getSubjectRange() {
		return subjectRange.copy(); // copy to ensure isolation	
	}
	
	public Range getReferenceRange() {
		return referenceRange.copy();
	}

    public Direction getDirection() {
		return getAlignmentDirection(referenceRange,subjectRange);
	}
  	
/* add static method to find quickly an alignment in a (sorted) list, e.g. isToLeftOf ..
   and methods to translate getCforR, getRforC in this alignment
*/	
	
    public int compareTo(Alignment that) {
	    return this.subjectRange.getStart() - that.subjectRange.getStart();
    }
    
    public boolean equals(Alignment that) {
   	    return (referenceRange.equals(that.getReferenceRange())
    	    &&  subjectRange.equals(that.getSubjectRange()));
    }
    
    public Alignment getInverse() { // interchange subject and reference ranges
        return new Alignment(subjectRange,referenceRange);
    }
    
    public BasicSegment getSegment() {
        return new BasicSegment(referenceRange.getStart(),subjectRange.getStart(),subjectRange.getLength());
    }
    
    public Alignment applyOffsetsAndDirection(int referenceOffset, int subjectOffset, boolean forward) {
    	// this method changes the Range constituents
     	subjectRange.offset(subjectOffset);
    	if (forward)
    		referenceRange.mirror(referenceOffset);
    	else 
     	    referenceRange.offset(referenceOffset);
    	return this;
    }

    public int getReferencePositionForSubjectPosition(int spos) {
    	if (subjectRange.contains(spos)) {
    		spos -= subjectRange.getStart();
     	    if (referenceRange.getDirection() == Direction.REVERSE)
    		    spos = -spos;
    	    return referenceRange.getStart() + spos;
    	}
       	else
    		return -1;
    }

    public int getSubjectPositionForReferencePosition(int rpos) {
    	if (referenceRange.contains(rpos)) {
    		rpos -= referenceRange.getStart();
    		if (referenceRange.getDirection() == Direction.REVERSE)
    			rpos = -rpos;
    		return subjectRange.getStart() + rpos;
    	}
    	else
     	    return -1;
    }

    /**
     *
     * @param rpos
     * @return value : in an ordered list of Alignments (increasing Subject position)
     * the return value ATLEFT means that the position relative to the current alignment
     * is in the direction of alignments of lower rank, ibid. ATRIGHT towards higher rank  
     */
    
    public Placement getPlacementOfPosition(int rpos) {
//Utility.report("ref:" + referenceRange.toString() + "  pos:"+rpos);
    	if (referenceRange.getDirection() == Direction.FORWARD)
       		rpos -= referenceRange.getStart();
        else
   		    rpos -= referenceRange.getEnd();
 
Utility.report("rpos " + rpos);
   	
		if (rpos < 0)
			return Placement.AT_LEFT;
		else if (rpos >= referenceRange.getLength())
			return Placement.AT_RIGHT;
		else
			return Placement.INSIDE;
	}

	public String toString() {
	    return referenceRange.toString() + " " + subjectRange.toString();
	}
   
// class method acting on an array of Alignment
    
    public static Direction getDirection(Alignment[] alignments) {
		// If no segments, we can't infer a direction.
        if (alignments == null || alignments.length == 0)
            return Direction.UNKNOWN;
		
		// Try to infer direction from one of the segments.
		
        for (int i = 0; i < alignments.length; i++) {
            if (alignments[i] != null) {
                Direction dir = alignments[i].getDirection();
                if (dir != Direction.UNKNOWN)
                    return dir;
            }
        }
		
		// All of the segments are apparently single-base or null.
		// Try to find two non-null segments and infer the direction

        Alignment seg1 = null;
        Alignment seg2 = null;
		
        for (int i = 0; i < alignments.length; i++) {
            if (alignments[i] != null) {
                if (seg1 == null)
                    seg1 = alignments[i];
                else if (seg2 == null) {
                    seg2 = alignments[i];
                    Range sRange = new Range(seg1.getSubjectRange().getStart(),
                    		                 seg2.getSubjectRange().getStart());
                    Range rRange = new Range(seg1.getReferenceRange().getStart(),
                    		                 seg2.getReferenceRange().getStart());
                    return getAlignmentDirection(rRange,sRange);
                }
            }
        }
		// We failed to find two non-null segments.
        return Direction.UNKNOWN;
    }
    
    public static AssembledFrom[] getAssembledFrom(Alignment[] alignments) {
    	if (alignments == null)
    		return null;
    	AssembledFrom[] af = new AssembledFrom[alignments.length];
    	for (int i = 0 ; i < alignments.length ; i++) {
    		af[i] = new AssembledFrom(alignments[i]);
    	}
      	return af;
    }
	
	private static Direction getAlignmentDirection(Range rRange,Range sRange) {
		if (rRange.getDirection() == Direction.UNKNOWN || sRange.getDirection() == Direction.UNKNOWN )
			return Direction.UNKNOWN;
		return (rRange.getDirection() == sRange.getDirection()) ? Direction.FORWARD : Direction.REVERSE;
	}
	
	private static void coalesce (Alignment[] alignments) {
		// see perl code  collate TO BE COMPLETED
		
	}
}