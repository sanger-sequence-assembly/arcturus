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

import javax.swing.table.*;
import java.util.*;

import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.scaffold.*;

class ScaffoldTableModel extends AbstractTableModel implements
		SortableTableModel {
	private static final long serialVersionUID = 4187549881840298164L;
	protected Vector scaffolds = new Vector();
	protected ScaffoldComparator comparator;
	protected int lastSortColumn = 0;
	protected Set scaffoldSet;

	public ScaffoldTableModel(Set scaffoldSet) {
		this.scaffoldSet = scaffoldSet;
		comparator = new ScaffoldComparator();
		populateScaffoldsArray();
	}

	protected void populateScaffoldsArray() {
		refresh();
	}
	
	public void refresh() {
		for (Iterator iterator = scaffoldSet.iterator(); iterator.hasNext();) {
			Set bs = (Set) iterator.next();
			Scaffold scaffold = new Scaffold(bs);
			scaffolds.add(scaffold);
		}
		
		comparator.setAscending(false);
		sortOnColumn(0);
	}

	public String getColumnName(int col) {
		switch (col) {
			case 0:
				return "Contigs";

			case 1:
				return "Total Length";

			default:
				return "UNKNOWN";
		}
	}

	public Class getColumnClass(int col) {
		switch (col) {
			case 0:
			case 1:
				return String.class;

			default:
				return null;
		}
	}

	public int getRowCount() {
		return scaffolds.size();
	}

	public int getColumnCount() {
		return 2;
	}

	protected Scaffold getScaffoldAtRow(int row) {
		return (Scaffold) scaffolds.elementAt(row);
	}

	public Object getValueAt(int row, int col) {
		Scaffold scaffold = getScaffoldAtRow(row);

		switch (col) {
			case 0:
				return new Integer(scaffold.getContigCount());

			case 1:
				return new Integer(scaffold.getTotalLength());

			default:
				return null;
		}
	}

	public boolean isCellEditable(int row, int col) {
		return false;
	}

	public boolean isColumnSortable(int col) {
		return true;
	}

	public void sortOnColumn(int col, boolean ascending) {
		comparator.setAscending(ascending);
		sortOnColumn(col);
	}

	public void sortOnColumn(int col) {
		switch (col) {
			case 0:
				comparator.setType(ScaffoldComparator.BY_CONTIG_COUNT);
				break;

			case 1:
				comparator.setType(ScaffoldComparator.BY_LENGTH);
				break;
		}

		lastSortColumn = col;

		Collections.sort(scaffolds, comparator);

		fireTableDataChanged();
	}

	public void add(int index, Scaffold Scaffold) {
		scaffolds.add(index, Scaffold);
	}

	public Object remove(int index) {
		return scaffolds.remove(index);
	}

	public boolean remove(Scaffold Scaffold) {
		return scaffolds.remove(Scaffold);
	}

	public Scaffold elementAt(int index) {
		return (Scaffold) scaffolds.elementAt(index);
	}
}
