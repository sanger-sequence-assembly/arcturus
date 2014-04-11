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

public class SmithWatermanEntry {
	public final static int UNDEFINED = 0;
	public final static int MATCH = 1;
	public final static int LEFT = 2;
	public final static int UP = 3;
	public final static int SUBSTITUTION = 4;

	protected int score;
	protected int direction;
	protected boolean onBestAlignment;

	public SmithWatermanEntry(int score, int direction) {
		this.score = score;
		this.direction = direction;
		this.onBestAlignment = false;
	}

	public SmithWatermanEntry() {
		this(0, UNDEFINED);
	}

	public void setScore(int score) {
		this.score = score;
	}

	public int getScore() {
		return score;
	}

	public void setDirection(int direction) {
		this.direction = direction;
	}

	public int getDirection() {
		return direction;
	}

	public void setScoreAndDirection(int score, int direction) {
		this.score = score;
		this.direction = direction;
	}

	public void setOnBestAlignment(boolean onBestAlignment) {
		this.onBestAlignment = onBestAlignment;
	}

	public boolean isOnBestAlignment() {
		return onBestAlignment;
	}
}
