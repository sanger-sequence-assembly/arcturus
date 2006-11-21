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

	public ScaffoldTableModel(Set scaffoldSet) {
		comparator = new ScaffoldComparator();
		populateScaffoldsArray(scaffoldSet);
	}

	protected void populateScaffoldsArray(Set scaffoldSet) {
		for (Iterator iterator = scaffoldSet.iterator(); iterator.hasNext();) {
			Set bs = (Set) iterator.next();
			Scaffold scaffold = new Scaffold(bs);
			scaffolds.add(scaffold);
			comparator.setAscending(false);
			sortOnColumn(0);
		}
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
