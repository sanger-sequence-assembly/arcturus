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

public class Segment {
	private int startA, endA, startB, endB;

	public Segment(int startA, int endA, int startB, int endB) {
		this.startA = startA;
		this.endA = endA;
		this.startB = startB;
		this.endB = endB;
	}

	public int getLength() {
		return endA - startA + 1;
	}

	public int getStartA() {
		return startA;
	}

	public int getEndA() {
		return endA;
	}

	public int getStartB() {
		return startB;
	}

	public int getEndB() {
		return endB;
	}

	public String toString() {
		return "Segment[" + startA + ":" + endA + ", " + startB + ":" + endB
				+ "]";
	}
}
