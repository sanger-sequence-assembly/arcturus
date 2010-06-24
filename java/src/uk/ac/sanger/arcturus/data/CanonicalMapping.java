package uk.ac.sanger.arcturus.data;

import java.util.*;
import java.lang.Character;

import uk.ac.sanger.arcturus.data.Utility;

public class CanonicalMapping {
    protected int ID;
    protected int referenceSpan;
    protected int subjectSpan;
    protected String extendedCigarString;
    protected BasicSegment[] segments;
    protected Integer[] padlist;
    protected byte[] checksum;
    
    protected boolean isValid = false;
    
   public CanonicalMapping(int ID, BasicSegment[] segments) {
        setMappingID(ID);
        setSegments(segments);
        // missing here: calculate subjectSpan and referenceSpan
    }
 
    public CanonicalMapping(BasicSegment[] segments) {
    	this(0,segments);
    }
   
    public CanonicalMapping(int ID, int rs, int ss, String extendedCigarString) {
    	// constructor using ID from database and e.g. delayed loading segments
        setMappingID(ID);
        setReferenceSpan(rs);
        setSubjectSpan(ss);
        this.extendedCigarString = extendedCigarString;
    }
    
    public CanonicalMapping(String extendedCigarString) {
        this.extendedCigarString = extendedCigarString;
    }

    
    public void setMappingID(int ID) {
        this.ID = ID;
    }
    
    public int getMappingID() {
    	return ID;
    }
    
    public void setSegments(BasicSegment[] segments) {
        this.segments = segments;
        if (this.segments == null) return;
        
        Arrays.sort(this.segments);
        // test first segment // test on valid segments to be done by invoking class ? 
        isValid = true;
        BasicSegment firstSegment = segments[0];
        if (firstSegment.getReferenceStart() != 1 || firstSegment.getSubjectStart() != 1) {
            isValid = false;            
        }
        
        BasicSegment lastSegment = segments[segments.length - 1];
            
        setSubjectSpan(lastSegment.getSubjectFinish());
        setReferenceSpan(lastSegment.getReferenceFinish());
    }
    
    public BasicSegment[] getSegments() {
    	if (segments == null)
    		initialise();
        return segments;
    }
   
    public void setSubjectSpan(int subjectSpan) {
       this.subjectSpan = subjectSpan;
    }
    
    public int getSubjectSpan() {
        if (subjectSpan == 0)
        	initialise();
        return subjectSpan;
    }
    
    public void setReferenceSpan(int referenceSpan) {
        this.referenceSpan = referenceSpan;
    }
    
    public int getReferenceSpan() {
        if (referenceSpan == 0)
        	initialise();
        return referenceSpan;
    }  
    
    public boolean equals(CanonicalMapping that) {
        // two canonical mappings are equal if their checksums are identical
    	if (that == null) 
    		return false;
    	byte[] thisCheckSum = this.getCheckSum();
     	byte[] thatCheckSum = that.getCheckSum();
       	if (thisCheckSum == null || thatCheckSum == null) 
       		return false;
       	if (thisCheckSum.length != thatCheckSum.length)
       		return false;
    	for (int i = 0 ; i < thisCheckSum.length ; i++) {
    		if (thisCheckSum[i] != thatCheckSum[i])
    			return false;
    	}
    	return true;
    }
    
    public String getExtendedCigarString() {
    	if (extendedCigarString == null)
    		initialise();
        return extendedCigarString;
    }
    
    public void setCheckSum(byte[] checksum) {
        this.checksum = checksum;
    }
    
    public static byte[] getCheckSum(String cigar) {
        if (cigar == null) 
        	return null;
        else if (cigar.length() < 16)
        	return cigar.getBytes();
        else 
    		return Utility.calculateMD5Hash(cigar);
    }

    public byte[] getCheckSum() {
        if (checksum == null) 
        	getExtendedCigarString(); // forces build if needed and possible
            checksum = getCheckSum(extendedCigarString);
        return checksum;
    }
    
/*
 *  private methods dealing with conversion of cigar string into segments and vice versa    
 */
    
    private void initialise() {
/*
    	if (segments == null && extendedCigarString != null)
    		makeSegmentsFromCigarString();
*/
    	if (extendedCigarString == null && segments != null)
    		makeCigarStringFromSegments();
// stubs to be removed later
    	if (referenceSpan == 0) {
     	    this.referenceSpan = 1;
    	    this.subjectSpan = 1;
    	}
    }
    
    private static final byte D = (byte)'D'; // insertion on reference (deletion with respect to)
    private static final byte H = (byte)'H'; // hard-clipping (of no effect here)
    private static final byte I = (byte)'I'; // insertion on subject
    private static final byte M = (byte)'M'; // match with reference
    private static final byte N = (byte)'N'; // long skip on reference
    private static final byte P = (byte)'P'; // pad in both reference and subject
    private static final byte S = (byte)'S'; // soft clip of subject (zero-point shift)
    private static final byte X = (byte)'X'; // substitution 
       
    private void makeSegmentsFromCigarString() {
    	// take cigar string and generate segments TO BE TESTED and DEVELOPED
    	referenceSpan = 0;
    	subjectSpan = 0;

		Vector<BasicSegment> BS = new Vector<BasicSegment>();
		Vector<Integer>      PI = new Vector<Integer>();

    	byte[] cigar = extendedCigarString.getBytes();
    	
    	int number = 0;
    	int offset = 0;
   	    for (int i=0 ; i < cigar.length ; i++) {
   	    	if (Character.isDigit((char)cigar[i])) {
   	    		int value = Character.getNumericValue((char)cigar[i]);
   	   	    	number = number*10 + value;
   	    	}
//    	    if (cigar[i] >= 48 && cigar[i] <= 57) 
//    	    	number = number*10 + cigar[i] - 48;
    	    else {
    	        if (cigar[i] == D)
    	    	    referenceSpan += number;
    	        else if (cigar[i] == I)
    	    	    subjectSpan += number;
    	        else if (cigar[i] == S)
    	    	    offset += number;
    	        else if (cigar[i] == N) {
	    	    	referenceSpan += number;
    	        }
    	        else if (cigar[i] == X) {
	    	    	referenceSpan += number;
 	    	        subjectSpan += number;
    	        }
    	        else if (cigar[i] == M) { // add a segment to the segment list
    	        	BasicSegment s = new BasicSegment(referenceSpan+1,subjectSpan+offset+1,number);
    	    	    BS.add(s);
    	    	    referenceSpan += number;
    	    	    subjectSpan += number;
    	        }
    	   	    else if (cigar[i] == P) { // add pad position(s) to the pad list	
    	    	    for (int j=1 ; j <= number ; j++) {
    	    	  	    Integer pad = new Integer(subjectSpan+j);
    	                PI.add(pad);
    	    	    }
    	    	    referenceSpan += number;
    	    	    subjectSpan += number;
    	   	    }
    	   	    else if (cigar[i] != H) { // H is silent
                    System.err.println("invalid cigar string " + extendedCigarString);
 //                   return;
    	   	    }
      	    	number = 0;
    	    }
    	}
    	if (BS.size() > 0)
    		segments = BS.toArray(new BasicSegment[0]);
    	if (PI.size() > 0)
    		padlist = PI.toArray(new Integer[0]);
    }

    private void makeCigarStringFromSegments() {
    	// take segments string and generate cigar string TO BE COMPLETED
    	System.out.println("makeCigarStringFromSegments NOT YET OPERATIONAL");
    	// Add stubs until this method completed
    	this.extendedCigarString = "DUMMY";
    }

/**
 *     
 * these methods are probably redundant, some functionality has to be put in Alignment Class
 * the methods are used in the SequenceToContigMapping class  
 */
  
    public int getSubjectPositionFromReferencePosition(int rpos) {
//        report("CanonicalMapping.getReadPositionFromContigPosition(" + rpos + ")");
     	int element = Traverser.locateElement(segments,rpos);
    	if (element >= 0) 
    		return segments[element].getSubjectPositionForReferencePosition(rpos);
    	else 
    		return -1;
    }

    public float getPadPositionFromReferencePosition(int deltaC) {
        return 0;
    }
}
