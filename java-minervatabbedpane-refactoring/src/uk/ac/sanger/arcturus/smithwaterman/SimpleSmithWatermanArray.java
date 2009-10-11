package uk.ac.sanger.arcturus.smithwaterman;

public class SimpleSmithWatermanArray implements SmithWatermanArrayModel {
	private SmithWatermanEntry sw[][] = null;

	private char[] subjectSequence;
	private int subjectOffset;
	private int subjectLength;

	private char[] querySequence;
	private int queryOffset;
	private int queryLength;
	
	private int bestRow = -1;
	private int bestColumn = -1;

	public SimpleSmithWatermanArray(char[] subjectSequence, int subjectOffset, int subjectLength,
			char[] querySequence, int queryOffset, int queryLength) {
		this.subjectSequence = subjectSequence;
		this.subjectOffset = subjectOffset;
		this.subjectLength = subjectLength;
		
		this.querySequence = querySequence;
		this.queryOffset = queryOffset;
		this.queryLength = queryLength;

		int nrows = subjectLength;
		int ncols = queryLength;

		sw = new SmithWatermanEntry[nrows][ncols];

		for (int row = 0; row < nrows; row++)
			for (int col = 0; col < ncols; col++)
				sw[row][col] = new SmithWatermanEntry();
	}
	
	public SimpleSmithWatermanArray(char[] subjectSequence, char[] querySequence) {
		this(subjectSequence, 0, subjectSequence.length, querySequence, 0, querySequence.length);
	}

	public int getRowCount() {
		return subjectLength;
	}

	public int getColumnCount() {
		return queryLength;
	}

	public boolean isBanded() {
		return false;
	}

	public int getBandWidth() {
		return -1;
	}

	public boolean exists(int row, int column) {
		return (row >= 0 && row < subjectLength && column >= 0 && column < queryLength);
	}

	public int getScore(int row, int column) {
		if (exists(row, column))
			return sw[row][column].getScore();
		else
			return 0;
	}

	public SmithWatermanEntry getEntry(int row, int column) {
		if (exists(row, column))
			return sw[row][column];
		else
			return null;
	}

	public void setScoreAndDirection(int row, int column, int score,
			int direction) {
		if (exists(row, column))
			sw[row][column].setScoreAndDirection(score, direction);
	}

	public char[] getSubjectSequence() {
		return subjectSequence;
	}

	public int getSubjectOffset() {
		return subjectOffset;
	}
	
	public int getSubjectLength() {
		return subjectLength;
	}

	public char[] getQuerySequence() {
		return querySequence;
	}
	
	public int getQueryOffset() {
		return queryOffset;
	}
	
	public int getQueryLength() {
		return queryLength;
	}
	
	public void resetOnBestAlignment() {
		for (int row = 0; row < sw.length; row++)
			for (int col = 0; col < sw[row].length; col++)
				sw[row][col].setOnBestAlignment(false);
	}
	
	public void setMaximalEntry(int row, int column) {
		bestRow = row;
		bestColumn = column;
	}
	
	public int[] getMaximalEntry() {
		int[] pos = new int[2];
		
		pos[0] = bestRow;
		pos[1] = bestColumn;
		
		return pos;
	}
}
