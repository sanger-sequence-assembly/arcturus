package uk.ac.sanger.arcturus.smithwaterman;

public interface SmithWatermanArrayModel {
    public int getRowCount();

    public int getColumnCount();

    public boolean isBanded();

    public int getBandWidth();

    public boolean exists(int row, int column);

    public int getScore(int row, int column);

    public SmithWatermanEntry getEntry(int row, int column);

    public void setScoreAndDirection(int row, int column,
				     int score, int direction);

    public String getSubjectSequence();

    public String getQuerySequence();
}
