package uk.ac.sanger.arcturus.test.contigdisplay;

public class Bridge {
	protected int score;

	public Bridge(int score) {
		this.score = score;
	}

	public int getScore() {
		return score;
	}

	public String toString() {
		return "Bridge[score=" + score + "]";
	}
}
