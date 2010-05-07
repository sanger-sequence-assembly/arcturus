package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.ReadToContigMapping.Direction;

public class Alignment implements Comparable<Alignment>,Traversable {
	private Range subjectRange;
	private Range referenceRange;
	
	public Alignment(Range referenceRange, Range subjectRange) {
// constructor uses copy or reverse to ensure immutable alignment with forward subjectRange
		if (subjectRange.getDirection() == Direction.REVERSE) {
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

    public Direction getDirection() {
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
    
    public Segment getSegment() {
        return new Segment(referenceRange.getStart(),subjectRange.getStart(),subjectRange.getLength());
    }
    
// this method changes the Range constituents
    
    public Alignment applyOffsetsAndDirection(int referenceOffset, int subjectOffset, Direction direction) {
    	subjectRange.offset(subjectOffset);
    	if (direction == Direction.REVERSE)
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
		rpos -= referenceRange.getStart();
        if (referenceRange.getDirection() == Direction.REVERSE)
    		rpos = -rpos;
    	
		if (rpos < 0)
			return Placement.ATLEFT;
		else if (rpos >= referenceRange.getLength())
			return Placement.ATRIGHT;
		else
			return Placement.INSIDE;
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
	
	private static Direction getAlignmentDirection(Range rRange,Range sRange) {
		if (rRange.getDirection() == Direction.UNKNOWN || sRange.getDirection() == Direction.UNKNOWN )
			return Direction.UNKNOWN;
		return (rRange.getDirection() == sRange.getDirection()) ? Direction.FORWARD : Direction.REVERSE;
	}
	
	private static void collate (Alignment[] alignments) {
		
	}
}