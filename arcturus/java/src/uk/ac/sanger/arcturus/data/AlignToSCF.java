package uk.ac.sanger.arcturus.data;

public class AlignToSCF {
    protected int startInSequence;
    protected int startInSCF;
    protected int length;

    public AlignToSCF(int startInSequence, int startInSCF, int length) {
	this.startInSequence = startInSequence;
	this.startInSCF = startInSCF;
	this.length = length;
    }

    public int getStartInSequence() { return startInSequence; }

    public int getStartInSCF() { return startInSCF; }

    public int length() { return length; }

    public String toCAFString() {
	int endInSCF = startInSCF + length - 1;
	int endInSequence = startInSequence + length - 1;
	return "Align_to_SCF " + startInSCF + " " + endInSCF + " " + startInSequence +
	    " " + endInSequence;
    }
}
