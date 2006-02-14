package uk.ac.sanger.arcturus.gui.organismtable;

import javax.swing.table.*;
import java.awt.*;
import javax.naming.*;
import java.util.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Organism;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.gui.Minerva;

class OrganismTableModel extends AbstractTableModel implements SortableTableModel {
    protected Vector organisms = new Vector();
    protected OrganismComparator comparator;
    protected int lastSortColumn = 0;
    protected ArcturusInstance instance = null;

    public OrganismTableModel(ArcturusInstance instance) {
	this.instance = instance;
	comparator = new OrganismComparator();
	populateOrganismsArray();
    }

    protected void populateOrganismsArray() {
	try {
	    organisms = instance.getAllOrganisms();
	    comparator.setAscending(false);
	    sortOnColumn(0);
	}
	catch (NamingException ne) {
	    ne.printStackTrace();
	    System.exit(1);
	}
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

    public int getColumnCount() { return 2; }

    protected Organism getOrganismAtRow(int row) {
	return (Organism)organisms.elementAt(row);
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

    public boolean isCellEditable(int row, int col) { return false; }

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
	    comparator.setType(OrganismComparator.BY_NAME);
	    break;

	case 1:
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
	return (Organism)organisms.elementAt(index);
    }

    public ArcturusInstance getArcturusInstance() { return instance; }
}
