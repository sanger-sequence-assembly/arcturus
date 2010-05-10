package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class CanonicalSegment extends BasicSegment {
	
	public CanonicalSegment(int cstart, int rstart, int length) {
		super(cstart,rstart,length);
	}
	
/**
  *the remaining methods may be redundant; this functionality -> Alignment class
	
	*public boolean containsContigPosition(int cpos) {
	*	return cstart <= cpos && cpos < cstart + length;
	*}
	
	public boolean isLeftOfContigPosition(int cpos) {
		return cstart <= cpos;
	}
	
	public int getReadOffset(int cpos) {
		if (cpos < cstart || cpos >= cstart + length)
			return -1;
		else
			return rstart + (cpos - cstart);
	}
*/
	
}
