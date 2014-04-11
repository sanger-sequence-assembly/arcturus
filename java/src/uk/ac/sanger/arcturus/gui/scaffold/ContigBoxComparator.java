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

import java.util.Comparator;

public class ContigBoxComparator implements Comparator<ContigBox> {
	public int compare(ContigBox box1, ContigBox box2) {
		int diff = box1.getLeft() - box2.getLeft();

		if (diff != 0)
			return diff;

		diff = box1.getRight() - box2.getRight();

		if (diff != 0)
			return diff;
		else
			return box1.getRow() - box2.getRow();
	}
}
