package uk.ac.sanger.arcturus.smithwaterman;

public class ScoringMatrix {
	public static final int DEFAULT_MATCH_SCORE = 1;
	public static final int DEFAULT_MISMATCH_PENALTY = -2;
	public static final int DEFAULT_GAP_INIT_PENALTY = -4;
	public static final int DEFAULT_GAP_EXTEND_PENALTY = -3;

	protected final int scoreMatch;
	protected final int penaltyMismatch;
	protected final int penaltyGapInit;
	protected final int penaltyGapExtend;

	public ScoringMatrix(int scoreMatch, int penaltyMismatch, int penaltyGapInit,
			int penaltyGapExtend) {
		this.scoreMatch = scoreMatch;
		this.penaltyMismatch = penaltyMismatch;
		this.penaltyGapInit = penaltyGapInit;
		this.penaltyGapExtend = penaltyGapExtend;
	}

	public ScoringMatrix() {
		this(DEFAULT_MATCH_SCORE, DEFAULT_MISMATCH_PENALTY,
				DEFAULT_GAP_INIT_PENALTY, DEFAULT_GAP_EXTEND_PENALTY);
	}

	public int getMatchScore() {
		return scoreMatch;
	}

	public int getMismatchPenalty() {
		return penaltyMismatch;
	}

	public int getGapInitPenalty() {
		return penaltyGapInit;
	}

	public int getGapExtendPenalty() {
		return penaltyGapExtend;
	}
}
