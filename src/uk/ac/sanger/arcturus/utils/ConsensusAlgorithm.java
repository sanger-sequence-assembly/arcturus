package uk.ac.sanger.arcturus.utils;

public interface ConsensusAlgorithm {
	// Constants for strand and chemistry
	public final static int UNKNOWN = 0;
	public final static int FORWARD = 1;
	public final static int REVERSE = 2;
	public final static int PRIMER = 3;
	public final static int TERMINATOR = 4;

	public boolean reset();

	public boolean addBase(char base, int quality, int strand, int chemistry);

	public char getBestBase();

	public int getBestScore();

	public int getScoreForBase(char base);
}
