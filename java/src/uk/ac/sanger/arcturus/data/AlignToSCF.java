package uk.ac.sanger.arcturus.data;

public class AlignToSCF extends Segment {

	public AlignToSCF(int startInSequence, int startInSCF, int length) {
		super(startInSequence,startInSCF,length);
	}

	public int getStartInSequence() {
		return getReferenceStart();
	}

	public int getStartInSCF() {
		return getSubjectStart();
	}

	public String toCAFString() {
		return "Align_to_SCF " + getStartInSCF() + " " + getSubjectFinish() + " "
				+ getStartInSequence() + " " + getReferenceFinish();
	}
}
