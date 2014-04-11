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

/**
 * 
 * @author ejz
 * 
 * This class provides basic operations on (Generic) mappings
 * 
 */

public class MappingOperation {
	
	public static GenericMapping multiply (GenericMapping r, GenericMapping t) {
		Alignment[] alignments = getProductAsAlignments(r, t);
		return new GenericMapping(alignments);
	}
	
    public static Alignment[] getProductAsAlignments (GenericMapping r, GenericMapping t) {

        Alignment[] ar = r.getAlignments();		
        Alignment[] at = t.getAlignments();
        
        // find the starting point s in the arrays 
        
        int rs = 0;
        int ts = 0; // for the moment
        
        Vector<Alignment> av = new Vector<Alignment>();
        
        int ns = 0;
        
        while (rs < ar.length && ts < at.length) {
        	int nt = t.isForward() ? ts : at.length - ts - 1;
        	
        	Range rx = ar[rs].getReferenceRange();
        	Range ry = ar[rs].getSubjectRange();
        	
        	Range tx = at[nt].getReferenceRange();
        	Range ty = at[nt].getSubjectRange();
        	if (tx.getDirection() == Direction.REVERSE) {
        	    tx = tx.reverse();
        	    ty = ty.reverse();
        	}
System.out.println("rs " + rs + " ts " + ts + " nt " + nt);
System.out.println(ar[rs].toString());     	
System.out.println(at[nt].toString());     	
        	
        	int mxs = at[nt].getSubjectPositionForReferencePosition(ry.getStart());
            int mxf = at[nt].getSubjectPositionForReferencePosition(ry.getEnd());
       	    int bxs = ar[rs].getReferencePositionForSubjectPosition(tx.getStart());
   			int bxf = ar[rs].getReferencePositionForSubjectPosition(tx.getEnd());
System.out.println("mxs, mxf, bxs, bxf : " + mxs + " " + mxf + " " + bxs + " " + bxf );
    	
            if (mxs > 0) {
        		if (mxf > 0) {
System.out.println("case 1-1");
        			av.add(new Alignment(rx,new Range(mxs,mxf)));	
        		    rs++;
        		}
        		else {
//        			int bxf = ar[rs].getReferencePositionForSubjectPosition(tx.getEnd());
        			if (bxf > 0) {
System.out.println("case 1-2");
              			av.add(new Alignment(rx.getStart(),bxf,mxs,ty.getEnd()));
System.out.println("mxs, mxf, bxs, bxf : " + mxs + " " + mxf + " " + bxs + " " + bxf );
System.out.println(new Alignment(rx.getStart(),bxf,mxs,ty.getEnd()).toString());         			
        				ts++;
        			}
         		    else { // should not occur
        				// dump ...
        				return null;
        			}
        		}
        	}
        	else if (mxf > 0) {
       		
         		if (bxs > 0) {
        			System.out.println("case 2-1");
         			av.add(new Alignment(bxs,rx.getEnd(),ty.getStart(),mxf));
         		    rs++;
        		}
        		else { // should not occur
       				// dump ...
    				return null;
                }
        	}
        	else if (bxs > 0) {
//        		int bxf = ar[rs].getReferencePositionForSubjectPosition(tx.getEnd());
        		if (bxf > 0) {
        			System.out.println("case 3-1");
        			av.add(new Alignment(new Range(bxs,bxf),ty));
        			ts++;
        		}
        		else { // should not occur
      				// dump ...
    				return null;       			
        		}
        	}
        	else {
    			System.out.println("case 4");
        		if (ry.getEnd() >= tx.getEnd())
        			ts++;
        		if (ry.getEnd() <= tx.getEnd())
        			rs++;
        	}
        }
 
        Alignment[] product = av.toArray(new Alignment[0]);
		return product;
	}

	public static GenericMapping inverse (GenericMapping m) {
// return inverse of a mapping
		Alignment[] alignments = m.getAlignments();
		if (alignments == null)
		    return null;
		// create a new list of inverted alignments, keep existing ones
		Alignment[] alignmentsOfInverse = new Alignment[alignments.length];
		
		for (int i = 0 ; i < alignments.length ; i++) {
			alignmentsOfInverse[i] = alignments[i].getInverse();
		}
		
		return new GenericMapping(alignmentsOfInverse);
	}
}
