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

package uk.ac.sanger.arcturus.gui.organismtable;

import java.util.Comparator;
import uk.ac.sanger.arcturus.data.Organism;

public class OrganismComparator implements Comparator {
	public static final int BY_NAME = 1;
	public static final int BY_DESCRIPTION = 2;

	protected boolean ascending;
	protected int type;

	public OrganismComparator() {
		this(BY_NAME, true);
	}

	public OrganismComparator(int type, boolean ascending) {
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
		return (that instanceof OrganismComparator && (OrganismComparator) that == this);
	}

	public int compare(Object o1, Object o2) {
		Organism org1 = (Organism) o1;
		Organism org2 = (Organism) o2;

		switch (type) {
			case BY_NAME:
				return compareByName(org1, org2);

			case BY_DESCRIPTION:
				return compareByDescription(org1, org2);

			default:
				return compareByName(org1, org2);
		}
	}

	protected int compareByName(Organism org1, Organism org2) {
		int diff = org2.getName().compareToIgnoreCase(org1.getName());

		return ascending ? diff : -diff;
	}

	protected int compareByDescription(Organism org1, Organism org2) {
		int diff = org2.getDescription().compareToIgnoreCase(
				org1.getDescription());

		return ascending ? diff : -diff;
	}
}
