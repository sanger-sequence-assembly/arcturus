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
