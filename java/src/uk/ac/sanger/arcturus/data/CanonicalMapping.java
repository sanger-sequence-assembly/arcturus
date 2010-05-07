package uk.ac.sanger.arcturus.data;

import java.util.Arrays;

//import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.ReadToContigMapping.Direction;
import uk.ac.sanger.arcturus.data.Utility;

public class CanonicalMapping {
    protected int ID;
    protected int referenceSpan;
    protected int subjectSpan;
    protected Segment[] segments;
    protected byte[] checksum;
    
    protected boolean isValid = false;
    
    // constructor using info from database
    
    public CanonicalMapping(int ID, Segment[] segments) {
        setMappingID(ID);
        setSegments(segments);
    }
 
    public CanonicalMapping(Segment[] segments) {
    	this(0,segments);
    }
   
    // constructor using ID from database and e.g. delayed loading segments

    public CanonicalMapping(int ID) {
        setMappingID(ID);        
    }
    
    public void setMappingID(int ID) {
        this.ID = ID;
    }
    
    public void setSegments(Segment[] segments) {
        this.segments = segments;
        if (this.segments == null) return;
        
        Arrays.sort(this.segments);
        // test first segment // test on valid segments to be done by invoking class ? 
        isValid = true;
        Segment firstSegment = segments[0];
        if (firstSegment.getReferenceStart() != 1 || firstSegment.getSubjectStart() != 1) {
            isValid = false;            
        }
        
        Segment lastSegment = segments[segments.length - 1];
            
        setSubjectSpan(lastSegment.getSubjectFinish());
        setReferenceSpan(lastSegment.getReferenceFinish());
    }
    
    public Segment[] getSegments() {
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
/*    
 *  public int getSubjectPositionForReferencePosition(int pos) {
*   public int getReferencePositionForSubjectPosition(int pos) {

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
    
    private void report(String message) {
        //System.err.println(message);
    }

    public float getPadPositionFromContigPosition(int deltaC) {
        return 0;
    }
*/
    // two canonical mapping are equal if their checksums are identical
    
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
    
    private byte[] buildCheckSum(Segment[] segments) {
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
