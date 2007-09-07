package uk.ac.sanger.arcturus.smithwaterman;

public class Segment {
    private int startA, endA, startB, endB;

    public Segment(int startA, int endA, int startB, int endB) {
	this.startA = startA;
	this.endA = endA;
	this.startB = startB;
	this.endB = endB;
    }
    
    public int getLength() { return endA - startA + 1; }
    
    public int getStartA() { return startA; }
    
    public int getEndA() { return endA; }
    
    public int getStartB() { return startB; }
    
    public int getEndB() { return endB; }
    
    public String toString() { return "Segment[" + startA + ":" + endA + ", " + startB + ":" + endB + "]"; }
}
