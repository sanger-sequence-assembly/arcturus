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

package uk.ac.sanger.arcturus.scaffold;

public class GapSize {
	private int minsize = -1;
	private int maxsize = -1;

	public GapSize() {
	}

	public GapSize(int minsize, int maxsize) {
		this.minsize = minsize;
		this.maxsize = maxsize;
	}

	public GapSize(int size) {
		this(size, size);
	}

	public int getMinimum() {
		return minsize;
	}

	public int getMaximum() {
		return maxsize;
	}

	public void add(int value) {
		if (minsize < 0 || value < minsize)
			minsize = value;

		if (maxsize < 0 || value > maxsize)
			maxsize = value;
	}

	public void add(GapSize that) {
		if (minsize < 0 || (that.minsize >= 0 && that.minsize < minsize))
			minsize = that.minsize;

		if (maxsize < 0 || (that.maxsize >= 0 && that.maxsize > maxsize))
			maxsize = that.maxsize;
	}

	public String toString() {
		return "GapSize[" + minsize + ":" + maxsize + "]";
	}
}
