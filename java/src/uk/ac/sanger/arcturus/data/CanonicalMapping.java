package uk.ac.sanger.arcturus.data;

import java.util.*;

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
    	if (segments == null && extendedCigarString != null)
    		makeSegmentsFromCigarString();
        return segments;
    }
   
    public void setSubjectSpan(int subjectSpan) {
       this.subjectSpan = subjectSpan;
    }
    
    public int getSubjectSpan() {
//       	if (segments == null && extendedCigarString != null)
//    		makeSegmentsFromCigarString();
        return subjectSpan;
    }
    
    public void setReferenceSpan(int referenceSpan) {
        this.referenceSpan = referenceSpan;
    }
    
    public int getReferenceSpan() {
 //      	if (segments == null && extendedCigarString != null)
 //   		makeSegmentsFromCigarString();
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
    	if (extendedCigarString == null && segments != null)
    		makeCigarStringFromSegments();
        return this.extendedCigarString;
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
 *  methods dealing with cigar stuff    
 */
    private static final byte D = 68;
    private static final byte H = 72;
    private static final byte I = 73;
    private static final byte M = 77;
    private static final byte N = 78;
    private static final byte P = 80;
    private static final byte S = 83;
    private static final byte X = 88;
       
    private void makeSegmentsFromCigarString() {
    	// take cigar string and generate segments TO BE TESTED
    	referenceSpan = 0;
    	subjectSpan = 0;

		Vector<BasicSegment> BS = new Vector<BasicSegment>();
		Vector<Integer>      PI = new Vector<Integer>();

    	byte[] cigar = extendedCigarString.getBytes();
    	
    	int number = 0;
    	int offset = 0;
   	    for (int i=0 ; i < cigar.length ; i++) {
   	    	System.out.println("next byte " + i + " : " + cigar[i]);
    	    if (cigar[i] >= 30 && cigar[i] <= 39) 
    	    	number = number*10 + cigar[i] - 30;
    	    else {
    	        if (cigar[i] == D)
    	    	    referenceSpan += number;
    	        else if (cigar[i] == I)
    	    	    subjectSpan += number;
    	        else if (cigar[i] == S)
    	    	    offset += number;
    	        else if (cigar[i] == N || cigar[i] == X) {
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
    }

/**
 *     
 * these methods are probably redundant, some functionality has to be put in Alignment Class
 */
    
    public int getSubjectPositionFromReferencePosition(int rpos) {
//        report("CanonicalMapping.getReadPositionFromContigPosition(" + rpos + ")");
     	int element = Traverser.locateElement(segments,rpos);
    	if (element >= 0) 
    		return segments[element].getSubjectPositionForReferencePosition(rpos);
    	else 
    		return -1;
    }
     
/*  public int getReferencePositionForSubjectPosition(int spos) {
	return -1;
    }
*/
    
    public float getPadPositionFromReferencePosition(int deltaC) {
        return 0;
    }
 
}
