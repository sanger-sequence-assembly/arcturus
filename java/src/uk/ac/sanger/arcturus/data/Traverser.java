package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.Traversable.Placement;

import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class Traverser {
	
	// TO BE TESTED: quick location of array element for position

    public static int locateElement(Traversable[] alignmentsegments, int rpos) {
	    return locateElement(alignmentsegments, rpos, Direction.FORWARD);
	}
	
	public static int locateElement(Traversable[] alignmentsegments, int rpos, Direction direction) {
		int element = 0;
		int increment = 2 * alignmentsegments.length;
		int last = alignmentsegments.length - 1;
		while (increment != 0) {
	    	if (element < 0) element = 0;
	    	if (element > last) element = last;
		    Placement placement = alignmentsegments[element].getPlacementOfPosition(rpos);
		    	
		    if (placement == Placement.INSIDE)
		    	return element;
		    else if (direction == Direction.FORWARD && placement == Placement.AT_LEFT ||
		    		 direction != Direction.FORWARD && placement == Placement.AT_RIGHT) {
		    	if (element == 0)
		    		return -1;
		    	if (increment > 0) 
		    		increment = -increment/2;
			    element += increment;			    
		    }
		    else if (direction == Direction.FORWARD && placement == Placement.AT_RIGHT ||
		    		 direction != Direction.FORWARD && placement == Placement.AT_LEFT) {
		    	if (element == last)
		    		return -1;
		    	if (increment < 0)
		    		increment = -increment/2;
			    element += increment;
		    }
		}
		return -1;
//		return (element > 0) ? -element : element;
	}

}
