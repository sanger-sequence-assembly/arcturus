package uk.ac.sanger.arcturus.smithwaterman;

public class BandedSmithWatermanArray implements SmithWatermanArrayModel {
	private SmithWatermanEntry sw[][] = null;

	private char[] subjectSequence;
	private int subjectOffset;
	private int subjectLength;

	private char[] querySequence;
	private int queryOffset;
	private int queryLength;

	private int bandwidth;
	
	private int bestRow = -1;
	private int bestColumn = -1;

	public BandedSmithWatermanArray(char[] subjectSequence, int subjectOffset,
			int subjectLength, char[] querySequence, int queryOffset,
			int queryLength, int bandwidth) {
		this.subjectSequence = subjectSequence;
		this.subjectOffset = subjectOffset;
		this.subjectLength = subjectLength;

		this.querySequence = querySequence;
		this.queryOffset = queryOffset;
		this.queryLength = queryLength;

		this.bandwidth = bandwidth;

		createNewArray();
	}

	public BandedSmithWatermanArray(char[] subjectSequence,
			char[] querySequence, int bandwidth) {
		this(subjectSequence, 0, subjectSequence.length, querySequence, 0,
				querySequence.length, bandwidth);
	}

	private void createNewArray() {
		int rowsize = 2 * bandwidth + 1;

		sw = new SmithWatermanEntry[subjectLength][rowsize];

		for (int row = 0; row < subjectLength; row++)
			for (int col = 0; col < rowsize; col++)
				sw[row][col] = new SmithWatermanEntry();
	}

	public int getRowCount() {
		return subjectLength;
	}

	public int getColumnCount() {
		return queryLength;
	}

	public boolean isBanded() {
		return true;
	}

	public int getBandWidth() {
		return bandwidth;
	}

	public boolean exists(int row, int column) {
		int offset = (row < column) ? column - row : row - column;

		return (row >= 0 && row < subjectLength && column >= 0
				&& column < queryLength && offset <= bandwidth);
	}

	public int getScore(int row, int column) {
		SmithWatermanEntry entry = getEntry(row, column);

		return (entry == null) ? 0 : entry.getScore();
	}

	public SmithWatermanEntry getEntry(int row, int column) {
		if (exists(row, column)) {
			int offset = bandwidth + column - row;

			return sw[row][offset];
		} else
			return null;
	}

	public void setScoreAndDirection(int row, int column, int score,
			int direction) {
		SmithWatermanEntry entry = getEntry(row, column);

		if (entry != null)
			entry.setScoreAndDirection(score, direction);
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
