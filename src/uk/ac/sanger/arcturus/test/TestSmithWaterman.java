package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.utils.*;

public class TestSmithWaterman {
    private static long lasttime;

    public static void main(String args[]) {
	lasttime = System.currentTimeMillis();

	System.out.println("TestSmithWaterman");
	System.out.println("===============");
	System.out.println();

	if (args.length < 2) {
	    System.out.println("Argument(s) missing: seqA seqB");
	    System.exit(1);
	}

	byte[] seqA = args[0].getBytes();

	int startA = 1;
	int endA = seqA.length;

	byte[] seqB = args[1].getBytes();

	int startB = 1;
	int endB = seqB.length;

	int matchScore = Integer.getInteger("match", 1).intValue();
	int mismatchScore = Integer.getInteger("mismatch", -1).intValue();
	int gapinitScore = Integer.getInteger("gapinit", -3).intValue();
	int gapextScore = Integer.getInteger("gapext", -2).intValue();

	ScoringMatrix defaultMatrix = new ScoringMatrix(matchScore, mismatchScore,
							gapinitScore, gapextScore);

	report("Starting Smith-Waterman calculation.");

	SmithWatermanEntry[][] sw = SmithWaterman.calculateMatrix(seqA, startA, endA,
								  seqB, startB, endB,
								  defaultMatrix);

	report("Done.");

	int nrows = sw.length;
	int ncols = sw[0].length;

	int maxScore = 0;
	int maxRow = 0;
	int maxCol = 0;

	for (int row = 1; row < nrows; row++) {
	    for (int col = 1; col < ncols; col++) {
		int score = sw[row][col].getScore();

		if (score > maxScore) {
		    maxRow = row;
		    maxCol = col;
		    maxScore = score;
		}
	    }
	}
 
	System.out.println("Maximum score (" + maxScore + ") found at row " + maxRow + ", column " +
			   maxCol);

	System.out.println();

	System.out.println("Starting traceback ...");
	
	int col = maxCol;
	int row = maxRow;
	int score = maxScore;
	char lastdir = ' ';
	
	while (score > 0 && col > 0 && row > 0) {
	    char baseA = Character.toUpperCase((char)seqA[startA + row - 2]);
	    char baseB = Character.toUpperCase((char)seqB[startB + col - 2]);

	    char dir;

	    int direction = sw[row][col].getDirection();

	    switch (direction) {
	    case SmithWatermanEntry.UNDEFINED: dir = '?'; break;
	    case SmithWatermanEntry.DIAGONAL:  dir = (baseA == baseB) ? ' ' : '*'; break;
	    case SmithWatermanEntry.UP:        dir = 'U'; break;
	    case SmithWatermanEntry.LEFT:      dir = 'L'; break;
	    default: dir = '!';
	    }

	    if (dir != ' ' && lastdir == ' ')
		System.out.println();

	    System.out.println(score + " " + row + " " + baseA + " " + col + " " + baseB + " " + dir);

	    if (dir != ' ')
		System.out.println();

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

	    score = sw[row][col].getScore();
	    lastdir = dir;
	}
    }

    public static void report(String message) {
	long timenow = System.currentTimeMillis();

	System.err.println("******************** REPORT ********************");
	System.err.println("Message: " + message);
	System.err.println("Time: " + (timenow - lasttime));

	lasttime = timenow;

	Runtime runtime = Runtime.getRuntime();

	System.err.println("Memory (kb): (free/total) " + runtime.freeMemory()/1024 + "/" + runtime.totalMemory()/1024);
	System.err.println("************************************************");
	System.err.println();
    }
}
