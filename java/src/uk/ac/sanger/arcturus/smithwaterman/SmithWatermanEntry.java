package uk.ac.sanger.arcturus.smithwaterman;

public class SmithWatermanEntry {
	public final static int UNDEFINED = 0;
	public final static int MATCH = 1;
	public final static int LEFT = 2;
	public final static int UP = 3;
	public final static int SUBSTITUTION = 4;

	protected int score;
	protected int direction;
	protected boolean onBestAlignment;

	public SmithWatermanEntry(int score, int direction) {
		this.score = score;
		this.direction = direction;
		this.onBestAlignment = false;
	}

	public SmithWatermanEntry() {
		this(0, UNDEFINED);
	}

	public void setScore(int score) {
		this.score = score;
	}

	public int getScore() {
		return score;
	}

	public void setDirection(int direction) {
		this.direction = direction;
	}

	public int getDirection() {
		return direction;
	}

	public void setScoreAndDirection(int score, int direction) {
		this.score = score;
		this.direction = direction;
	}

	public void setOnBestAlignment(boolean onBestAlignment) {
		this.onBestAlignment = onBestAlignment;
	}

	public boolean isOnBestAlignment() {
		return onBestAlignment;
	}
}
