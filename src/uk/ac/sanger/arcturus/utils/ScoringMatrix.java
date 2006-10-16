package uk.ac.sanger.arcturus.utils;

public class ScoringMatrix {
	protected final int scoreMatch;
	protected final int scoreMismatch;
	protected final int scoreGapInit;
	protected final int scoreGapExtend;

	public ScoringMatrix(int scoreMatch, int scoreMismatch, int scoreGapInit,
			int scoreGapExtend) {
		this.scoreMatch = scoreMatch;
		this.scoreMismatch = scoreMismatch;
		this.scoreGapInit = scoreGapInit;
		this.scoreGapExtend = scoreGapExtend;
	}

	public ScoringMatrix() {
		this(1, -2, -4, -3);
	}

	public int getMatchScore() {
		return scoreMatch;
	}

	public int getMismatchScore() {
		return scoreMismatch;
	}

	public int getGapInitScore() {
		return scoreGapInit;
	}

	public int getGapExtendScore() {
		return scoreGapExtend;
	}
}
