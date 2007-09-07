package uk.ac.sanger.arcturus.smithwaterman;

public class BandedSmithWatermanArray implements SmithWatermanArrayModel {
    private SmithWatermanEntry sw[][] = null;

    String subjectSequence;
    String querySequence;

    private int nrows;
    private int ncols;

    private int bandwidth;

    public BandedSmithWatermanArray(String subjectSequence, String querySequence, int bandwidth) {
	this.subjectSequence = subjectSequence;
	this.querySequence = querySequence;

	nrows = subjectSequence.length();
	ncols = querySequence.length();

	this.bandwidth = bandwidth;

	createNewArray();
    }

    private void createNewArray() {
	int rowsize = 2 * bandwidth + 1;

	sw = new SmithWatermanEntry[nrows][rowsize];

	for (int row = 0; row < nrows; row++)
	    for (int col = 0; col < rowsize; col++)
		sw[row][col] = new SmithWatermanEntry();
    }

    public int getRowCount() { return nrows; }

    public int getColumnCount() { return ncols; }

    public boolean isBanded() { return true; }

    public int getBandWidth() { return bandwidth; }

    public boolean exists(int row, int column) {
	int offset = (row < column) ? column - row : row - column;

	return (row >= 0 && row < nrows && column >= 0 && column < ncols && offset <= bandwidth);
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

    public void setScoreAndDirection(int row, int column,
				     int score, int direction) {
	SmithWatermanEntry entry = getEntry(row, column);

	if (entry != null)
	    entry.setScoreAndDirection(score, direction);
    }

    public String getSubjectSequence() { return subjectSequence; }

    public String getQuerySequence() { return querySequence; }
}
