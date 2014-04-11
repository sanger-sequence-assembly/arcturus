// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.smithwaterman;

public class ScoringMatrix {
	public static final int DEFAULT_MATCH_SCORE = 1;
	public static final int DEFAULT_MISMATCH_PENALTY = -2;
	public static final int DEFAULT_GAP_INIT_PENALTY = -4;
	public static final int DEFAULT_GAP_EXTEND_PENALTY = -3;

	protected final int scoreMatch;
	protected final int penaltyMismatch;
	protected final int penaltyGapInit;
	protected final int penaltyGapExtend;

	public ScoringMatrix(int scoreMatch, int penaltyMismatch, int penaltyGapInit,
			int penaltyGapExtend) {
		this.scoreMatch = scoreMatch;
		this.penaltyMismatch = penaltyMismatch;
		this.penaltyGapInit = penaltyGapInit;
		this.penaltyGapExtend = penaltyGapExtend;
	}

	public ScoringMatrix() {
		this(DEFAULT_MATCH_SCORE, DEFAULT_MISMATCH_PENALTY,
				DEFAULT_GAP_INIT_PENALTY, DEFAULT_GAP_EXTEND_PENALTY);
	}

	public int getMatchScore() {
		return scoreMatch;
	}

	public int getMismatchPenalty() {
		return penaltyMismatch;
	}

	public int getGapInitPenalty() {
		return penaltyGapInit;
	}

	public int getGapExtendPenalty() {
		return penaltyGapExtend;
	}
}
