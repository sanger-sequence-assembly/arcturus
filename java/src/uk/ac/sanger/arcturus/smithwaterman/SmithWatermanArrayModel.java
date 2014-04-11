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

    public char[] getSubjectSequence();
    
    public int getSubjectOffset();
    
    public int getSubjectLength();

    public char[] getQuerySequence();
    
    public int getQueryOffset();
    
    public int getQueryLength();
    
    public int[] getMaximalEntry();
    
    public void setMaximalEntry(int row, int column);
    
    public void resetOnBestAlignment();
}
