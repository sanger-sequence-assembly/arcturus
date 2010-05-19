package uk.ac.sanger.arcturus.data;

import java.util.Arrays;

//import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;
import uk.ac.sanger.arcturus.data.Utility;

public class CanonicalMapping {
    protected int ID;
    protected int referenceSpan;
    protected int subjectSpan;
    protected BasicSegment[] segments;
    protected byte[] checksum;
    
    protected boolean isValid = false;
    
   public CanonicalMapping(int ID, BasicSegment[] segments) {
        setMappingID(ID);
        setSegments(segments);
    }
 
    public CanonicalMapping(BasicSegment[] segments) {
    	this(0,segments);
    }
   
    public CanonicalMapping(int ID,int rs, int ss, byte[] checksum) {
    	// constructor using ID from database and e.g. delayed loading segments
        setMappingID(ID);
        setReferenceSpan(rs);
        setSubjectSpan(ss);
        setCheckSum(checksum);
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
        return segments;
    }
   
    public void setSubjectSpan(int subjectSpan) {
        this.subjectSpan = subjectSpan;
    }
    
    public int getSubjectSpan() {
        return subjectSpan;
    }
    
    public void setReferenceSpan(int referenceSpan) {
        this.referenceSpan = referenceSpan;
    }
    
    public int getReferenceSpan() {
        return referenceSpan;
    }

    public Alignment[] getAlignments (int referenceOffset, int subjectOffset, Direction direction) {
        if (this.segments == null) return null;
        int numberOfSegments = segments.length;
        Alignment[] alignments = new Alignment[numberOfSegments];
        for (int i = 0 ; i < numberOfSegments ; i++) {
            alignments[i] = segments[i].getAlignment();
            alignments[i].applyOffsetsAndDirection(referenceOffset, subjectOffset, direction);
        }
        return alignments;
    }
    
    public int getSubjectPositionFromReferencePosition(int rpos) {
//        report("CanonicalMapping.getReadPositionFromContigPosition(" + rpos + ")");
     	int element = Utility.locateElement(segments,rpos);
    	if (element >= 0) 
    		return segments[element].getSubjectPositionForReferencePosition(rpos);
    	else 
    		return -1;
    }
     
/*  public int getReferencePositionForSubjectPosition(int spos) {
	return -1;
    }

    public int getReadPositionFromContigPosition(int cpos) {
        if (segments == null)
            return -1;
        
        report("CanonicalMapping.getReadPositionFromContigPosition(" + cpos + ")");
        
        Segment segments = getSegments();
        Utility.locateElement(cpos);
        for (CanonicalSegment segment : segments) {
            report("\tExamining " + segment);
            if (segment.containsContigPosition(cpos)) {
                return segment.getReadOffset(cpos);
            }
        }
        
        return -1;
    }
 */
    public float getPadPositionFromReferencePosition(int deltaC) {
        return 0;
    }
    
    // two canonical mappings are equal if their checksums are identical
    
    public boolean equals(CanonicalMapping that) {
    	if (that == null) 
    		return false;
    	byte[] thisCheckSum = this.getCheckSum();
     	byte[] thatCheckSum = that.getCheckSum();
       	if (thisCheckSum == null || thatCheckSum == null) 
       		return false;
    	for (int i = 0 ; i < thisCheckSum.length ; i++) {
    		if (thisCheckSum[i] != thatCheckSum[i])
    			return false;
    	}
    	return true;
    }
    
    public void setCheckSum(byte[] checksum) {
        this.checksum = checksum;
    }

    public byte[] getCheckSum () {
        if (checksum == null) 
            checksum = buildCheckSum(segments);
        return checksum;
    }
    
    private byte[] buildCheckSum(BasicSegment[] segments) {
        if (segments == null) return null;
        StringBuilder sb = new StringBuilder();
        for (int i = 0 ; i < segments.length ; i++) {
            if (i > 0) sb.append(':');
            sb.append(segments[i].getReferenceStart());
            sb.append(',');
            sb.append(segments[i].getSubjectStart());
            sb.append(',');
            sb.append(segments[i].getLength());
        }
        
        return Utility.calculateMD5Hash(sb.toString());
    }
}
