package uk.ac.sanger.arcturus.utils;

public class SmithWaterman {
    public static SmithWatermanEntry[][] calculateMatrix(byte[] sequenceA, int starta, int enda,
							 byte[] sequenceB, int startb, int endb,
							 ScoringMatrix smat) {
	int sMatch = smat.getMatchScore();
	int sMismatch = smat.getMismatchScore();
	int sGapInit = smat.getGapInitScore();
	int sGapExtend = smat.getGapExtendScore();

	int nrows = enda - starta + 2;
	int ncols = endb - startb + 2;

	SmithWatermanEntry[][] sw = new SmithWatermanEntry[nrows][ncols];

	for (int row = 0; row < nrows; row++)
	    for (int col = 0; col < ncols; col++)
		sw[row][col] = new SmithWatermanEntry();

	for (int row = 1; row < nrows; row++) {
	    char baseA = Character.toUpperCase((char)sequenceA[starta + row - 2]);

	    for (int col = 1; col < ncols; col++) {
		char baseB = Character.toUpperCase((char)sequenceB[startb + col - 2]);

		boolean isMatch = baseA == baseB;
		boolean isN = baseA == 'N' || baseB == 'N';

		int score = isN ? 0 : (isMatch ? sMatch : sMismatch);

		int diagonal = sw[row - 1][col - 1].getScore() + score;
		int up       = sw[row - 1][col].getScore() + sGapInit;
		int left     = sw[row][col - 1].getScore() + sGapInit;

		int maxGapScore = (up > left) ? up : left;

		if (diagonal > 0 || maxGapScore > 0) {
		    if (diagonal >= maxGapScore) {
			sw[row][col].setScoreAndDirection(diagonal, SmithWatermanEntry.DIAGONAL);
		    } else {
			if (up > left)
			    sw[row][col].setScoreAndDirection(up, SmithWatermanEntry.UP);
			else
			    sw[row][col].setScoreAndDirection(left, SmithWatermanEntry.LEFT);
		    }
		} else {
		    sw[row][col].setScoreAndDirection(0, SmithWatermanEntry.UNDEFINED);
		}
	    }
	}

	return sw;
    }
}
