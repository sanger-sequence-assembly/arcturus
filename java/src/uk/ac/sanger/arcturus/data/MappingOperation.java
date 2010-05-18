package uk.ac.sanger.arcturus.data;

//import java.util.*;

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
        
        Alignment[] ap = new Alignment[ar.length + at.length]; // the maximum

        int ns = 0;
        
        while (rs < ar.length && ts < at.length) {
        	int nt = t.isForward() ? ts : at.length - ts;
        	
        	Range rx = ar[rs].getReferenceRange();
        	Range ry = ar[rs].getSubjectRange();
        	
        	Range tx = at[nt].getReferenceRange();
        	Range ty = at[nt].getSubjectRange();
        	if (tx.getDirection() == Direction.REVERSE) {
        	    tx = tx.reverse();
        	    ty = ty.reverse();
        	}
        	
        	int mxs = at[nt].getSubjectPositionForReferencePosition(ry.getStart());
            int mxf = at[nt].getSubjectPositionForReferencePosition(ry.getEnd());
       		int bxs = ar[rs].getReferencePositionForSubjectPosition(tx.getStart());
      	
       	    if (mxs > 0) {
        		if (mxf > 0) {
         		    ap[ns++] = new Alignment(rx,new Range(mxs,mxf));
        		    rs++;
        		}
        		else {
        			int bxf = ar[rs].getReferencePositionForSubjectPosition(tx.getEnd());
        			if (bxf > 0) {
        				ap[ns++] = new Alignment(new Range(rx.getStart(),bxf), new Range(mxs,ty.getEnd()));
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
         		    ap[ns++] = new Alignment(new Range(bxs,rx.getEnd()),new Range(ty.getStart(),mxf));
         		    rs++;
        		}
        		else { // should not occur
       				// dump ...
    				return null;
                }
        	}
        	else if (bxs > 0) {
        		int bxf = ar[rs].getReferencePositionForSubjectPosition(tx.getEnd());
        		if (bxf > 0) {
        			ap[ns++] = new Alignment(new Range(bxs,bxf),ty);
        			ts++;
        		}
        		else { // should not occur
      				// dump ...
    				return null;       			
        		}
        	}
        	else {
        		if (ry.getEnd() >= tx.getEnd())
        			ts++;
        		if (ry.getEnd() <= tx.getEnd())
        			rs++;
        	}
        }
// copy the output array to remove any trailing undefined elements
        Alignment[] product = new Alignment[ns];
        for (int i = 0 ; i < ns ; i++) {
        	product[i] = ap[i];
        }
        
		return product;
	}

	public static GenericMapping inverse (GenericMapping m) {
// return inverse of a mapping
		Alignment[] alignments = m.getAlignments();
		if (alignments == null)
		    return null;
		// create a new list of inverted alignments, keep existing ones
		Alignment[] stnemngila = new Alignment[alignments.length];
		
		for (int i = 0 ; i < alignments.length ; i++) {
			stnemngila[i] = alignments[i].getInverse();
		}
		
		return new GenericMapping(stnemngila);
	}
}
