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

import java.util.*;

public class RowRanges {
	Vector rangesets = new Vector();

	public int addRange(Range range, int tryrow) {
		for (int row = tryrow; row < rangesets.size(); row++) {
			Set ranges = (Set) rangesets.elementAt(row);

			if (!overlaps(range, ranges)) {
				ranges.add(range);
				return row;
			}
		}

		for (int row = tryrow - 1; row >= 0; row--) {
			Set ranges = (Set) rangesets.elementAt(row);

			if (!overlaps(range, ranges)) {
				ranges.add(range);
				return row;
			}
		}

		Set ranges = new HashSet();
		ranges.add(range);

		rangesets.add(ranges);
		return rangesets.indexOf(ranges);
	}

	private boolean overlaps(Range range, Set ranges) {
		for (Iterator iterator = ranges.iterator(); iterator.hasNext();) {
			Range rangeInRow = (Range) iterator.next();
			if (range.overlaps(rangeInRow))
				return true;
		}

		return false;
	}
}
