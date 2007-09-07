package uk.ac.sanger.arcturus.smithwaterman;

import java.util.*;

public class SmithWaterman {
    public static SmithWatermanArrayModel calculateMatrix(String subjectSequence, String querySequence,
							  ScoringMatrix smat, int bandwidth) {
	if (subjectSequence == null || querySequence == null || smat == null)
	    return null;

	int sMatch = smat.getMatchScore();
	int sMismatch = smat.getMismatchScore();
	int sGapInit = smat.getGapInitScore();
	int sGapExtend = smat.getGapExtendScore();

	int nrows = subjectSequence.length();
	int ncols = querySequence.length();

	SmithWatermanArrayModel sw;

	if (bandwidth > 0)
	    sw = new BandedSmithWatermanArray(subjectSequence, querySequence, bandwidth);
	else
	    sw = new SimpleSmithWatermanArray(subjectSequence, querySequence);

	for (int row = 0; row < nrows; row++) {
	    char baseA = Character.toUpperCase(subjectSequence.charAt(row));

	    int colstart;
	    int colfinish;

	    if (bandwidth > 0) {
		colstart = max(0, row - bandwidth);
		colfinish = min(ncols, row + bandwidth + 1);
	    } else {
		colstart = 0;
		colfinish = ncols;
	    }

	    for (int col = colstart; col < colfinish; col++) {
		char baseB = Character.toUpperCase(querySequence.charAt(col));

		boolean isMatch = baseA == baseB;
		boolean isN = baseA == 'N' || baseB == 'N';
		boolean isX = baseA == 'X' || baseB == 'X';

		int score = isMatch ? sMatch : sMismatch;

		if (isX)
		    score = sMismatch;

		if (isN)
		    score = 0;

		int diagonal = sw.getScore(row - 1, col - 1) + score;
		int up       = sw.getScore(row - 1, col) + sGapInit;
		int left     = sw.getScore(row, col - 1) + sGapInit;

		int maxGapScore = (up > left) ? up : left;

		if (diagonal > 0 || maxGapScore > 0) {
		    if (diagonal >= maxGapScore) {
			sw.setScoreAndDirection(row, col, diagonal, SmithWatermanEntry.DIAGONAL);
		    } else {
			if (up > left)
			    sw.setScoreAndDirection(row, col, up, SmithWatermanEntry.UP);
			else
			    sw.setScoreAndDirection(row, col, left, SmithWatermanEntry.LEFT);
		    }
		} else {
		    sw.setScoreAndDirection(row, col, 0, SmithWatermanEntry.UNDEFINED);
		}
	    }
	}

	return sw;
    }

    private static int min(int i, int j) {
	return (i < j) ? i : j;
    }

    private static int max(int i, int j) {
	return (i > j) ? i : j;
    }

    public static Segment[] traceBack(SmithWatermanArrayModel sw) {
	if (sw == null)
	    return null;

	int nrows = sw.getRowCount();
	int ncols = sw.getColumnCount();

	String subjectSequence = sw.getSubjectSequence();
	String querySequence = sw.getQuerySequence();

	int maxScore = 0;
	int maxRow = 0;
	int maxCol = 0;

	for (int row = 0; row < nrows; row++) {
	    for (int col = 0; col < ncols; col++) {
		int score = sw.getScore(row, col);

		if (score >= maxScore) {
		    maxRow = row;
		    maxCol = col;
		    maxScore = score;
		}
	    }
	}
	
	int col = maxCol;
	int row = maxRow;
	int score = maxScore;

	Vector segments = new Vector();

	int startA = 0, endA = 0, startB = 0, endB = 0;
	boolean inSegment = false;
	
	while (score > 0 && col >= 0 && row >= 0) {
	    SmithWatermanEntry entry = sw.getEntry(row, col);

	    entry.setOnBestAlignment(true);
	    int direction = entry.getDirection();

	    char baseA = Character.toUpperCase(subjectSequence.charAt(row));
	    char baseB = Character.toUpperCase(querySequence.charAt(col));

	    boolean match = baseA == baseB;

	    if (match) {
		startA = row;
		startB = col;

		if (!inSegment) {
		    endA = row;
		    endB = col;
		    inSegment = true;
		}
	    } else {
		if (inSegment) {
		    segments.add(new Segment(startA, endA, startB, endB));
		    inSegment = false;
		}
	    }

	    switch (direction) {
	    case SmithWatermanEntry.DIAGONAL:
		row--;
		col--;
		break;

	    case SmithWatermanEntry.UP:
		row--;
		break;

	    case SmithWatermanEntry.LEFT:
		col--;
		break;

	    default:
		System.err.println("Undefined direction: " + direction + " -- cannot continue");
		System.exit(1);
	    }

	    score = sw.getScore(row, col);
	}

	if (inSegment)
	    segments.add(new Segment(startA, endA, startB, endB));

	Segment[] array = new Segment[segments.size()];

	return (Segment[])segments.toArray(array);
    }
}
