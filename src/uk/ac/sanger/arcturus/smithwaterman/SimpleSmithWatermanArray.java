package uk.ac.sanger.arcturus.smithwaterman;

public class SimpleSmithWatermanArray implements SmithWatermanArrayModel {
    SmithWatermanEntry sw[][] = null;

    String subjectSequence;
    String querySequence;

    int nrows;
    int ncols;

    public SimpleSmithWatermanArray(String subjectSequence, String querySequence) {
	this.subjectSequence = subjectSequence;
	this.querySequence = querySequence;

	nrows = subjectSequence.length();
	ncols = querySequence.length();

	sw = new SmithWatermanEntry[nrows][ncols];

	for (int row = 0; row < nrows; row++)
	    for (int col = 0; col < ncols; col++)
		sw[row][col] = new SmithWatermanEntry();
    }

    public int getRowCount() { return nrows; }

    public int getColumnCount() { return ncols; }

    public boolean isBanded() { return false; }

    public int getBandWidth() { return -1; }

    public boolean exists(int row, int column) {
	return (row >= 0 && row < nrows && column >= 0 && column < ncols);
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

    public void setScoreAndDirection(int row, int column,
				     int score, int direction) {
	if (exists(row, column))
	    sw[row][column].setScoreAndDirection(score, direction);
    }

    public String getSubjectSequence() { return subjectSequence; }

    public String getQuerySequence() { return querySequence; }
}
