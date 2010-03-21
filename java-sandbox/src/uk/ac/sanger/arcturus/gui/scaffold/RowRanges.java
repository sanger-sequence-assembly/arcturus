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
