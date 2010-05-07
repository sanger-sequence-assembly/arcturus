package uk.ac.sanger.arcturus.data;

import java.io.*;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.data.Traversable.Placement;

public class Utility {
    private static MessageDigest digester;

    public static byte[] calculateMD5Hash(String data) {
    	byte [] dataAsByte = null;
        try {
        	 dataAsByte = data.getBytes("US-ASCII");
        } catch (UnsupportedEncodingException e) {
        	Arcturus.logWarning(e);
        }
        return calculateMD5Hash(dataAsByte);
	}

    public static byte[] calculateMD5Hash(byte[] data) {
    	if (digester == null) {
		    try {
			    digester = MessageDigest.getInstance("MD5");
		    } catch (NoSuchAlgorithmException e) {
			    Arcturus.logWarning(e);
			    return null;
		    }			
	    }
   	    digester.reset();
	    return digester.digest(data);
    }
    
    public static char complement(char base) {
		switch (base) {
			case 'a':
				return 't';
				
			case 'A':
				return 'T';
				
			case 'c':
				return 'g';
				
			case 'C':
				return 'G';
				
			case 'g':
				return 'c';
				
			case 'G':
				return 'C';
				
			case 't':
				return 'a';
				
			case 'T':
				return 'A';
				
			default:
				return base;
		}
    }
    
    // TO BE TESTED: quick location of array element for position
	private static int locateElement(Traversable[] alignmentsegments, int rpos) {
		int element = 0;
		int increment = 2 * alignmentsegments.length;
		int last = alignmentsegments.length - 1;
		while (increment != 0) {
	    	if (element < 0) element = 0;
	    	if (element > last) element = last;
		    Placement placement = alignmentsegments[element].getPlacementOfPosition(rpos);
		    if (placement == Placement.INSIDE)
		    	return element;
		    else if (placement == Placement.AT_LEFT) {
		    	if (element == 0)
		    		return -1;
		    	if (increment > 0) 
		    		increment = -increment/2;
			    element += increment;			    
		    }
		    else if (placement == Placement.AT_RIGHT) {
		    	if (element == last)
		    		return -1;
		    	if (increment < 0)
		    		increment = -increment/2;
			    element += increment;
		    }
		}
		return (element > 0) ? -element : element;
	}
}