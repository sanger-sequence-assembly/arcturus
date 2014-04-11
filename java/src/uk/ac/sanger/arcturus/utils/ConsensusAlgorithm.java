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

package uk.ac.sanger.arcturus.utils;

public interface ConsensusAlgorithm {
	// Constants for strand and chemistry
	public final static int UNKNOWN = 0;
	public final static int FORWARD = 1;
	public final static int REVERSE = 2;
	public final static int PRIMER = 3;
	public final static int TERMINATOR = 4;

	public boolean reset();

	public boolean addBase(char base, int quality, int strand, int chemistry);

	public char getBestBase();

	public int getBestScore();

	public int getScoreForBase(char base);
	
	public int getReadCount();
}
