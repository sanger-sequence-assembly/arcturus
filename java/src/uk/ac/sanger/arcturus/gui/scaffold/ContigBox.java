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

package uk.ac.sanger.arcturus.gui.scaffold;

import uk.ac.sanger.arcturus.data.Contig;

public class ContigBox {
	protected Contig contig;
	protected int row;
	protected Range range;
	protected boolean forward;

	public ContigBox(Contig contig, int row, Range range, boolean forward) {
		this.contig = contig;
		this.row = row;
		this.range = range;
		this.forward = forward;
	}

	public Contig getContig() {
		return contig;
	}

	public int getRow() {
		return row;
	}

	public Range getRange() {
		return range;
	}

	public int getLeft() {
		return range.getStart();
	}

	public int getRight() {
		return range.getEnd();
	}

	public int getLength() {
		return range.getLength();
	}

	public boolean isForward() {
		return forward;
	}

	public String toString() {
		return "ContigBox[contig=" + contig.getID() + ", row=" + row
				+ ", range=" + range.getStart() + ".." + range.getEnd()
				+ ", " + (forward ? "forward" : "reverse") + "]";
	}
}
