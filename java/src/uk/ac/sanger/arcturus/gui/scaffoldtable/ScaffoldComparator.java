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

package uk.ac.sanger.arcturus.gui.scaffoldtable;

import java.util.Comparator;
import uk.ac.sanger.arcturus.scaffold.Scaffold;

public class ScaffoldComparator implements Comparator {
	public static final int BY_LENGTH = 1;
	public static final int BY_CONTIG_COUNT = 2;

	protected boolean ascending;
	protected int type;

	public ScaffoldComparator() {
		this(BY_LENGTH, true);
	}

	public ScaffoldComparator(int type, boolean ascending) {
		this.type = type;
		this.ascending = ascending;
	}

	public void setType(int type) {
		this.type = type;
	}

	public int getType() {
		return type;
	}

	public void setAscending(boolean ascending) {
		this.ascending = ascending;
	}

	public boolean isAscending() {
		return ascending;
	}

	public boolean equals(Object that) {
		return (that instanceof ScaffoldComparator && (ScaffoldComparator) that == this);
	}

	public int compare(Object o1, Object o2) {
		Scaffold scaffold1 = (Scaffold) o1;
		Scaffold scaffold2 = (Scaffold) o2;
		
		switch (type) {
			case BY_LENGTH:
				return compareByLength(scaffold1, scaffold2);

			case BY_CONTIG_COUNT:
				return compareByContigCount(scaffold1, scaffold2);

			default:
				return compareByLength(scaffold1, scaffold2);
		}
	}

	protected int compareByLength(Scaffold scaffold1, Scaffold scaffold2) {
		int diff = scaffold1.getTotalLength() - scaffold2.getTotalLength();

		return ascending ? diff : -diff;
	}

	protected int compareByContigCount(Scaffold scaffold1, Scaffold scaffold2) {
		int diff = scaffold1.getContigCount() - scaffold2.getContigCount();

		if (diff != 0)
			return ascending ? diff : -diff;
		else
			return compareByLength(scaffold1, scaffold2);
	}
}
