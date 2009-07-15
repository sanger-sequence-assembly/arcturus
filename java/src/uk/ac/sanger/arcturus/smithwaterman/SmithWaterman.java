package uk.ac.sanger.arcturus.smithwaterman;

import java.util.*;

public class SmithWaterman {
	public static SmithWatermanArrayModel calculateMatrix(
			char[] subjectSequence, int subjectOffset, int subjectLength,
			char[] querySequence, int queryOffset, int queryLength,
			ScoringMatrix smat, int bandwidth) {
		if (subjectSequence == null || querySequence == null || smat == null)
			return null;

		int sMatch = smat.getMatchScore();
		int sMismatch = smat.getMismatchScore();
		int sGapInit = smat.getGapInitScore();
		//int sGapExtend = smat.getGapExtendScore();
		
		int bestScore = -1;

		SmithWatermanArrayModel sw;

		if (bandwidth > 0)
			sw = new BandedSmithWatermanArray(subjectSequence, subjectOffset,
					subjectLength, querySequence, queryOffset, queryLength,
					bandwidth);
		else
			sw = new SimpleSmithWatermanArray(subjectSequence, subjectOffset,
					subjectLength, querySequence, queryOffset, queryLength);

		for (int row = 0; row < subjectLength; row++) {
			char baseA = Character.toUpperCase(subjectSequence[subjectOffset
					+ row]);

			int colstart;
			int colfinish;

			if (bandwidth > 0) {
				colstart = max(0, row - bandwidth);
				colfinish = min(queryLength, row + bandwidth + 1);
			} else {
				colstart = 0;
				colfinish = queryLength;
			}

			for (int col = colstart; col < colfinish; col++) {
				char baseB = Character.toUpperCase(querySequence[queryOffset
						+ col]);

				boolean isMatch = baseA == baseB;
				boolean isN = baseA == 'N' || baseB == 'N';
				boolean isX = baseA == 'X' || baseB == 'X';

				int score = isMatch ? sMatch : sMismatch;

				if (isX)
					score = sMismatch;

				if (isN)
					score = 0;

				int diagonal = sw.getScore(row - 1, col - 1) + score;
				int up = sw.getScore(row - 1, col) + sGapInit;
				int left = sw.getScore(row, col - 1) + sGapInit;

				int maxGapScore = (up > left) ? up : left;

				if (diagonal > 0 || maxGapScore > 0) {
					if (diagonal >= maxGapScore) {
						sw.setScoreAndDirection(row, col, diagonal,
								isMatch ? SmithWatermanEntry.MATCH : SmithWatermanEntry.SUBSTITUTION);
					} else {
						if (up > left)
							sw.setScoreAndDirection(row, col, up,
									SmithWatermanEntry.UP);
						else
							sw.setScoreAndDirection(row, col, left,
									SmithWatermanEntry.LEFT);
					}
					
					score = (diagonal >= maxGapScore) ? diagonal : maxGapScore;
					
					if (score > bestScore) {
						bestScore = score;
						sw.setMaximalEntry(row, col);
					}
				} else {
					sw.setScoreAndDirection(row, col, 0,
							SmithWatermanEntry.UNDEFINED);
				}
			}
		}

		return sw;
	}

	public static SmithWatermanArrayModel calculateMatrix(
			char[] subjectSequence, char[] querySequence, ScoringMatrix smat,
			int bandwidth) {
		return calculateMatrix(subjectSequence, 0, subjectSequence.length,
				querySequence, 0, querySequence.length, smat, bandwidth);
	}

	private static int min(int i, int j) {
		return (i < j) ? i : j;
	}

	private static int max(int i, int j) {
		return (i > j) ? i : j;
	}
	
	public static Segment[] traceBack(SmithWatermanArrayModel sw) throws SmithWatermanException {
		if (sw == null)
			return null;
		
		int[] maximal = sw.getMaximalEntry();
		
		int col = maximal[0];
		int row = maximal[1];
		
		return traceBack(sw, row, col);
	}
	
	public static Segment[] traceBack(SmithWatermanArrayModel sw, int row, int col)
	throws SmithWatermanException {
		if (sw == null)
			return null;
		
		sw.resetOnBestAlignment();

		char[] subjectSequence = sw.getSubjectSequence();
		int subjectOffset = sw.getSubjectOffset();

		char[] querySequence = sw.getQuerySequence();
		int queryOffset = sw.getQueryOffset();

		int score = sw.getScore(row, col);

		Vector<Segment> segments = new Vector<Segment>();

		int startA = 0, endA = 0, startB = 0, endB = 0;
		boolean inSegment = false;

		while (score > 0 && col >= 0 && row >= 0) {
			SmithWatermanEntry entry = sw.getEntry(row, col);
			
			if (entry == null)
				throw new SmithWatermanException("No such entry at (" + row + ", " + col + ")");

			entry.setOnBestAlignment(true);
			int direction = entry.getDirection();

			char baseA = Character.toUpperCase(subjectSequence[subjectOffset
					+ row]);
			char baseB = Character
					.toUpperCase(querySequence[queryOffset + col]);

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
			case SmithWatermanEntry.MATCH:
			case SmithWatermanEntry.SUBSTITUTION:
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
				throw new SmithWatermanException("Undefined direction: " + direction);
			}

			score = sw.getScore(row, col);
		}

		if (inSegment)
			segments.add(new Segment(startA, endA, startB, endB));

		Segment[] array = new Segment[segments.size()];
		
		Collections.reverse(segments);

		return (Segment[]) segments.toArray(array);
	}
	
	public static Alignment getAlignment(SmithWatermanArrayModel sw) throws SmithWatermanException {
		if (sw == null)
			return null;

		int[] maximal = sw.getMaximalEntry();

		int col = maximal[0];
		int row = maximal[1];
		
		return getAlignment(sw, row, col);
	}

	public static Alignment getAlignment(SmithWatermanArrayModel sw, int row, int col)
	throws SmithWatermanException {
		if (sw == null)
			return null;
		
		if (sw.getScore(row, col) == 0)
			return null;
		
		sw.resetOnBestAlignment();
			
		Vector<EditEntry> edits = new Vector<EditEntry>();
		
		EditEntry currentEntry = null;
		int lastDirection = SmithWatermanEntry.UNDEFINED;
		int entryLength = 0;
		
		int lastRow = row;
		int lastColumn = col;
		
		do {
			SmithWatermanEntry entry = sw.getEntry(row, col);
			
			if (entry == null)
				throw new SmithWatermanException("No such entry at (" + row + ", " + col + ")");

			entry.setOnBestAlignment(true);
			
			int direction = entry.getDirection();
	
			if (direction == lastDirection && currentEntry != null) {
				currentEntry.setCount(++entryLength);
			} else {
				char editType;
				
				switch (direction) {
				case SmithWatermanEntry.MATCH:
					editType = EditEntry.MATCH;
					break;
					
				case SmithWatermanEntry.SUBSTITUTION:
					editType = EditEntry.SUBSTITUTION;
					break;
					
				case SmithWatermanEntry.UP:
					editType = EditEntry.DELETION;
					break;
					
				case SmithWatermanEntry.LEFT:
					editType = EditEntry.INSERTION;
					break;
					
				default:
					editType = EditEntry.UNKNOWN;
				break;
				}
				
				entryLength = 1;
				
				currentEntry = new EditEntry(editType, entryLength);
				
				edits.add(currentEntry);
			}
			
			lastDirection = direction;
			
			lastRow = row;
			lastColumn = col;
			
			switch (direction) {
			case SmithWatermanEntry.MATCH:
			case SmithWatermanEntry.SUBSTITUTION:
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
				throw new SmithWatermanException("Undefined direction: " + direction);
			}
		} while (sw.getScore(row, col) > 0);

		Collections.reverse(edits);

		return new Alignment(lastRow, lastColumn, edits.toArray(new EditEntry[0]));
	}
}
