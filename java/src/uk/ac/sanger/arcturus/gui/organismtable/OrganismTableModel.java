package uk.ac.sanger.arcturus.gui.organismtable;

import javax.swing.table.*;
import javax.naming.*;
import java.util.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Organism;
import uk.ac.sanger.arcturus.gui.SortableTableModel;

class OrganismTableModel extends AbstractTableModel implements
		SortableTableModel {
	public static final int ORGANISM_NAME = 0;
	public static final int ORGANISM_DESCRIPTION= 1;
	
	protected Vector organisms = new Vector();
	protected OrganismComparator comparator;
	protected int lastSortColumn;
	protected ArcturusInstance instance = null;

	public OrganismTableModel(ArcturusInstance instance) {
		this.instance = instance;
		comparator = new OrganismComparator();
		comparator.setAscending(false);
		populateOrganismsArray();
	}

	protected void populateOrganismsArray() {
		refresh();
		sortOnColumn(ORGANISM_NAME);
	}
	
	public void refresh() {
		try {
			organisms = instance.getAllOrganisms();
			resort();
		} catch (NamingException ne) {
			ne.printStackTrace();
			System.exit(1);
		}
	}
	
	private void resort() {
		sortOnColumn(lastSortColumn);
	}

	public String getColumnName(int col) {
		switch (col) {
			case 0:
				return "Organism";

			case 1:
				return "Description";

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
		return organisms.size();
	}

	public int getColumnCount() {
		return 2;
	}

	protected Organism getOrganismAtRow(int row) {
		return (Organism) organisms.elementAt(row);
	}

	public Object getValueAt(int row, int col) {
		Organism organism = getOrganismAtRow(row);

		switch (col) {
			case 0:
				return organism.getName();

			case 1:
				return organism.getDescription();

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
			case ORGANISM_NAME:
				comparator.setType(OrganismComparator.BY_NAME);
				break;

			case ORGANISM_DESCRIPTION:
				comparator.setType(OrganismComparator.BY_DESCRIPTION);
				break;
		}

		lastSortColumn = col;

		Collections.sort(organisms, comparator);

		fireTableDataChanged();
	}

	public void add(int index, Organism organism) {
		organisms.add(index, organism);
	}

	public Object remove(int index) {
		return organisms.remove(index);
	}

	public boolean remove(Organism organism) {
		return organisms.remove(organism);
	}

	public Organism elementAt(int index) {
		return (Organism) organisms.elementAt(index);
	}

	public ArcturusInstance getArcturusInstance() {
		return instance;
	}
}
