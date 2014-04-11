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

package uk.ac.sanger.arcturus.tag;

public class Segment {
	protected int cstart;
	protected int pstart;
	protected int pfinish;

	public Segment(int cstart, int pstart, int length, boolean forward) {
		if (forward) {
			this.cstart = cstart;
			this.pstart = pstart;
			this.pfinish = pstart + length - 1;
		} else {
			this.cstart = cstart + length - 1;
			this.pstart = pstart - length + 1;
			this.pfinish = pstart;
		}
	}

	public int mapToChild(int pos, boolean forward) {
		return mapToChild(pos, forward, false);
	}

	public int mapToChild(int pos, boolean forward, boolean force) {
		if (force || (pos >= pstart && pos <= pfinish)) {
			int offset = pos - pstart;
			return forward ? cstart + offset : cstart - offset;
		} else
			return -1;
	}

	public String toString() {
		return "Segment[pstart=" + pstart + ", pfinish=" + pfinish
				+ ", cstart=" + cstart + "]";
	}

}
