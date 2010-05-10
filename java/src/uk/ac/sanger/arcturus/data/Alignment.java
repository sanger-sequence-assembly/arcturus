package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class Alignment implements Comparable<Alignment>,Traversable {
	private Range subjectRange;
	private Range referenceRange;
	
	public Alignment(Range referenceRange, Range subjectRange) {
// constructor uses copy or reverse to ensure immutable alignment with forward subjectRange
		if (subjectRange.getDirection() == GenericMapping.Direction.REVERSE) {
 			this.subjectRange   = subjectRange.reverse();
		    this.referenceRange = referenceRange.reverse();
		}
		else {
		    this.subjectRange   = subjectRange.copy();
		    this.referenceRange = referenceRange.copy();
		}
	}

	public Range getSubjectRange() {
		return subjectRange.copy(); // copy to ensure encapsulation
	}
	
	public Range getReferenceRange() {
		return referenceRange.copy();
	}

    public GenericMapping.Direction getDirection() {
		return getAlignmentDirection(referenceRange,subjectRange);
	}
  	
/* add static method to find quickly an alignment in a (sorted) list, e.g. isToLeftOf ..
   and methods to translate getCforR, getRforC in this alignment
*/	
	
    public int compareTo(Alignment that) {
	    return this.subjectRange.getStart() - that.subjectRange.getStart();
    }
    
    public Alignment getInverse() { // interchange subject and reference ranges
        return new Alignment(subjectRange,referenceRange);
    }
    
    public BasicSegment getSegment() {
        return new BasicSegment(referenceRange.getStart(),subjectRange.getStart(),subjectRange.getLength());
    }
    
// this method changes the Range constituents
    
    public Alignment applyOffsetsAndDirection(int referenceOffset, int subjectOffset, GenericMapping.Direction direction) {
    	subjectRange.offset(subjectOffset);
    	if (direction == GenericMapping.Direction.REVERSE)
    		referenceRange.mirror(referenceOffset);
    	else 
     	    referenceRange.offset(referenceOffset);
    	return this;
    }

    public int getReferencePositionForSubjectPosition(int spos) {
    	if (subjectRange.contains(spos)) {
    		spos -= subjectRange.getStart();
     	    if (referenceRange.getDirection() == GenericMapping.Direction.REVERSE)
    		    spos = -spos;
    	    return referenceRange.getStart() + spos;
    	}
       	else
    		return -1;
    }

    public int getSubjectPositionForReferencePosition(int rpos) {
    	if (referenceRange.contains(rpos)) {
    		rpos -= referenceRange.getStart();
    		if (referenceRange.getDirection() == GenericMapping.Direction.REVERSE)
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
		rpos -= referenceRange.getStart();
        if (referenceRange.getDirection() == GenericMapping.Direction.REVERSE)
    		rpos = -rpos;
    	
		if (rpos < 0)
			return Placement.AT_LEFT;
		else if (rpos >= referenceRange.getLength())
			return Placement.AT_RIGHT;
		else
			return Placement.INSIDE;
	}
    
// class method acting on an array of Alignment
    
    public static GenericMapping.Direction getDirection(Alignment[] alignments) {
		// If no segments, we can't infer a direction.
        if (alignments == null || alignments.length == 0)
            return GenericMapping.Direction.UNKNOWN;
		
		// Try to infer direction from one of the segments.
		
        for (int i = 0; i < alignments.length; i++) {
            if (alignments[i] != null) {
                GenericMapping.Direction dir = alignments[i].getDirection();
                if (dir != GenericMapping.Direction.UNKNOWN)
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
        return GenericMapping.Direction.UNKNOWN;
    }
	
	private static GenericMapping.Direction getAlignmentDirection(Range rRange,Range sRange) {
		if (rRange.getDirection() == GenericMapping.Direction.UNKNOWN || sRange.getDirection() == GenericMapping.Direction.UNKNOWN )
			return GenericMapping.Direction.UNKNOWN;
		return (rRange.getDirection() == sRange.getDirection()) ? GenericMapping.Direction.FORWARD : GenericMapping.Direction.REVERSE;
	}
	
	private static void collate (Alignment[] alignments) {
		
	}
}