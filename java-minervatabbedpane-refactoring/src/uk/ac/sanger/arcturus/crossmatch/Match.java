package uk.ac.sanger.arcturus.crossmatch;

public class Match {
	protected int score = 0;
	protected double insertionRate = 0.0;
	protected double deletionRate = 0.0;
	protected double substitutionRate = 0.0;

	protected String seqname1 = null;
	protected int start1 = -1;
	protected int end1 = -1;
	protected int tail1 = -1;

	protected String seqname2 = null;
	protected int start2 = -1;
	protected int end2 = -1;
	protected int tail2 = -1;
	protected boolean reverseComplement = false;

	public Match(int score, double insertionRate, double deletionRate,
			double substitutionRate, String seqname1, int start1, int end1,
			int tail1, String seqname2, int start2, int end2, int tail2,
			boolean reverseComplement) {
		this.score = score;

		this.insertionRate = insertionRate;
		this.deletionRate = deletionRate;
		this.substitutionRate = substitutionRate;

		this.seqname1 = seqname1;
		this.start1 = start1;
		this.end1 = end1;
		this.tail1 = tail1;

		this.seqname2 = seqname2;
		this.start2 = start2;
		this.end2 = end2;
		this.tail2 = tail2;

		this.reverseComplement = reverseComplement;
	}

	public int getScore() {
		return score;
	}

	public double getInsertionRate() {
		return insertionRate;
	}

	public double getDeletionrate() {
		return deletionRate;
	}

	public double getSubstitutionRate() {
		return substitutionRate;
	}

	public String getSequenceName1() {
		return seqname1;
	}

	public int getStart1() {
		return start1;
	}

	public int getEnd1() {
		return end1;
	}

	public int getTail1() {
		return tail1;
	}

	public String getSequenceName2() {
		return seqname2;
	}

	public int getStart2() {
		return start2;
	}

	public int getEnd2() {
		return end2;
	}

	public int getTail2() {
		return tail2;
	}

	public boolean isReverseComplement() {
		return reverseComplement;
	}
	
	public String toString() {
		return "Match[score=" + score + ", Sequence1=\"" + seqname1 + "\" from " + start1 + " to " + end1
		 + " (tail " + tail1 + "), Sequence2=\"" + seqname2 + "\" from " + start2 + " to " + end2
		 + " (tail " + tail2 + ") in " + (reverseComplement ? "reverse" : "forward") + " sense, insertion rate "
		 + insertionRate + ", deletion rate " + deletionRate + ", substitution rate " + substitutionRate
		 + "]";
	}
}
