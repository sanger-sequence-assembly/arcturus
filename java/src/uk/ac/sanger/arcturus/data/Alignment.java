// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.data;

import java.util.*;

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
		
	public Alignment(int rStart, int rEnd, int sStart, int sEnd) throws IllegalArgumentException {
		this(new Range(rStart,rEnd), new Range(sStart,sEnd));
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
 	
    public int compareTo(Alignment that) {
	    return this.subjectRange.getStart() - that.subjectRange.getStart();
    }
    
    public boolean equals(Alignment that) {
   	    return (referenceRange.equals(that.getReferenceRange())
    	    &&  subjectRange.equals(that.getSubjectRange()));
    }
    
    public Alignment copy() {
        return new Alignment(getReferenceRange(),getSubjectRange());
    }
    
    public Alignment getInverse() { // interchange subject and reference ranges
        return new Alignment(getSubjectRange(),getReferenceRange());
    }
    
    public BasicSegment getSegment() {
        return new BasicSegment(referenceRange.getStart(),subjectRange.getStart(),subjectRange.getLength());
    }

    public Alignment applyOffsetsAndDirection(int referenceOffset, int subjectOffset, Direction direction) {
	    // this method changes the Range constituents
 	    subjectRange.offset(subjectOffset);
	    if (direction == Direction.FORWARD)
	        referenceRange.offset(referenceOffset);
	    else 
	   	    referenceRange.mirror(-referenceOffset);
	    return this;
    }
   
    public Alignment fromCanonicalAlignment(int referenceOffset, int subjectOffset, Direction direction) {
    	// this method changes the Range constituents
     	subjectRange.offset(subjectOffset);
    	if (direction == Direction.FORWARD)
    	    referenceRange.offset(referenceOffset);
    	else 
    		referenceRange.mirror(referenceOffset);
    	return this;
    }
    
    public Alignment toCanonicalAlignment(int referenceOffset, int subjectOffset, Direction direction) {
    	// this method changes the Range constituents
     	subjectRange.offset(-subjectOffset);
    	if (direction == Direction.FORWARD)
    	    referenceRange.offset(-referenceOffset);
    	else 
    		referenceRange.mirror(referenceOffset);
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

    	if (referenceRange.getDirection() == Direction.FORWARD)
       		rpos -= referenceRange.getStart();
        else
   		    rpos -= referenceRange.getEnd();
   	
		if (rpos < 0)
			return Placement.AT_LEFT;
		else if (rpos >= referenceRange.getLength())
			return Placement.AT_RIGHT;
		else
			return Placement.INSIDE;
	}

	public String toString() {
		return "Alignment["+referenceRange.toString()+ "," + subjectRange.toString()+"]";
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
    		af[i] = new AssembledFrom(alignments[i].getReferenceRange(),alignments[i].getSubjectRange());
    	}
      	return af;
    }
	
	public static Alignment[] coalesce (Alignment[] alignments) {
		return coalesce(alignments,0); // default max gap size 0 for exactly budding entries
	}
	
	public static Alignment[] coalesce (Alignment[] alignments, int maxGapSize) {
// replace budding entries by
		Vector<Alignment> v = new Vector<Alignment>();
		for (int i=0 ; i < alignments.length ; i++) {
		     v.add(alignments[i]);
		}
		
		Direction direction = getDirection(alignments);
		
		int j = 1;
		while (j < v.size()) {
			Alignment ai = v.get(j-1);
			Alignment aj = v.get(j);
			Range air = ai.getReferenceRange();
			Range ais = ai.getSubjectRange();
			Range ajr = aj.getReferenceRange();
			Range ajs = aj.getSubjectRange();
			int referenceGap = (direction == Direction.FORWARD) ? ajr.getStart() - air.getEnd()
					                                            : ajr.getEnd() - air.getStart();
			int subjectGap   = ajs.getStart() - ais.getEnd();

            if (referenceGap == subjectGap && subjectGap-1 <= maxGapSize) {
			// replace elements i and j by one merged segment
            	if (direction == Direction.FORWARD)
				    alignments[j-1] = new Alignment(air.getStart(), ajr.getEnd(),
						                            ais.getStart(), ajs.getEnd());
				else if (direction == Direction.REVERSE)
					alignments[j-1] = new Alignment(ajr.getStart(), air.getEnd(),
	                                                ais.getStart(), ajs.getEnd());
				v.setElementAt(alignments[j-1],j-1);
				v.removeElementAt(j);
			}
			else
				j++;
		}

		if (j < alignments.length) // there were changes
            alignments = v.toArray(new Alignment[0]);
		return alignments;
	}
		
	public static boolean verify(Alignment[] alignments) {
// verifies an array of alignments for consistent direction and non-overlapping segments
	    boolean verify = true;
	 // TO BE COMPLETED   
	    return verify;
	}
	
	private static Direction getAlignmentDirection(Range rRange,Range sRange) {
		if (rRange.getDirection() == Direction.UNKNOWN || sRange.getDirection() == Direction.UNKNOWN )
			return Direction.UNKNOWN;
		return (rRange.getDirection() == sRange.getDirection()) ? Direction.FORWARD : Direction.REVERSE;
	}
	
}