package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.table.*;
import java.awt.*;
import java.sql.*;
import java.util.*;
import java.util.prefs.*;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.Assembly;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import uk.ac.sanger.arcturus.gui.Minerva;
import uk.ac.sanger.arcturus.gui.SortableTableModel;

class ContigTableModel extends AbstractTableModel implements SortableTableModel {
    public final int COLUMN_ID = 0;
    public final int COLUMN_NAME = 1;
    public final int COLUMN_PROJECT = 2;
    public final int COLUMN_LENGTH = 3;
    public final int COLUMN_READS = 4;
    public final int COLUMN_CREATED = 5;

    protected Vector contigs = new Vector();
    protected ContigComparator comparator;
    protected int lastSortColumn = COLUMN_LENGTH;
    protected boolean garish;
    protected ArcturusDatabase adb = null;

    protected HashMap projectColours = new HashMap();

    protected final Color VIOLET1 = new Color(245, 245, 255);
    protected final Color VIOLET2 = new Color(238, 238, 255);
    protected final Color VIOLET3 = new Color(226, 226, 255);

    public ContigTableModel(ArcturusDatabase adb, Set contigset) {
	this.adb = adb;
	comparator = new ContigComparator(ContigComparator.BY_LENGTH, false);
	contigs.addAll(contigset);
	sortOnColumn(COLUMN_LENGTH);
    }

    public String getColumnName(int col) {
        switch (col) {
	case COLUMN_ID:
	    return "ID";

	case COLUMN_NAME:
	    return "Name";

	case COLUMN_PROJECT:
	    return "Project";

	case COLUMN_LENGTH:
	    return "Length";

	case COLUMN_READS:
	    return "Reads";

	case COLUMN_CREATED:
	    return "Created";

	default:
	    return "UNKNOWN";
	}
    }

    public Object[] getLongValues() {
	Object[] objs = {"XXXXXX", "XXXXXXXXXXXXXXXX", "XXXXXXXX",
			 new Integer(88888888), new Integer(88888888), new java.util.Date()};

	return objs;
    }

    public Class getColumnClass(int col) {
        switch (col) {
	case COLUMN_ID:
	case COLUMN_NAME:
	case COLUMN_PROJECT:
	    return String.class;

	case COLUMN_LENGTH:
	case COLUMN_READS:
	    return Integer.class;

	case COLUMN_CREATED:
	    return java.util.Date.class;

	default:
	    return null;
	}
    }

    public int getRowCount() {
	return contigs.size();
    }

    public int getColumnCount() { return 6; }

    protected Contig getContigAtRow(int row) {
	return (Contig)contigs.elementAt(row);
    }

    public Object getValueAt(int row, int col) {
        Contig contig = getContigAtRow(row);

	switch (col) {
	case COLUMN_ID:
	    return new Integer(contig.getID());

	case COLUMN_NAME:
	    return contig.getName();

	case COLUMN_PROJECT:
	    return contig.getProject().getName();

	case COLUMN_LENGTH:
	    return new Integer(contig.getLength());

	case COLUMN_READS:
	    return new Integer(contig.getReadCount());

	case COLUMN_CREATED:
	    return contig.getCreated();

	default:
	    return null;
	}
    }

    public boolean isCellEditable(int row, int col) { return false; }

    public int getProjectIDAtRow(int row) {
	return getContigAtRow(row).getProject().getID();
    }

    public Color getColourForRow(int row) {
	Project project = getContigAtRow(row).getProject();

	if (project == null)
	    return Color.WHITE;

	Assembly assembly = project.getAssembly();

	Color colour = Minerva.getInstance().getColourForProject(assembly.getName(), project.getName());

	return (colour == null) ? Color.WHITE : colour;
    }

    public boolean isColumnSortable(int col) {
	return (col != COLUMN_PROJECT);
    }

    public void sortOnColumn(int col, boolean ascending) {
	comparator.setAscending(ascending);
	sortOnColumn(col);
    }

    public void sortOnColumn(int col) {
	switch (col) {
	case COLUMN_ID:
	    comparator.setType(ContigComparator.BY_ID);
	    break;

	case COLUMN_NAME:
	    comparator.setType(ContigComparator.BY_NAME);
	    break;

	case COLUMN_LENGTH:
	    comparator.setType(ContigComparator.BY_LENGTH);
	    break;

	case COLUMN_READS:
	    comparator.setType(ContigComparator.BY_READS);
	    break;

	case COLUMN_CREATED:
	    comparator.setType(ContigComparator.BY_CREATION_DATE);
	    break;
	}

	lastSortColumn = col;

	Collections.sort(contigs, comparator);

	fireTableDataChanged();
    }

    public void setGroupByProject(boolean groupByProject) {
	comparator.setGroupByProject(groupByProject);
	sortOnColumn(lastSortColumn);
    }

    public void add(int index, Contig contig) {
	contigs.add(index, contig);
    }

    public Object remove(int index) {
	return contigs.remove(index);
    }

    public boolean remove(Contig contig) {
	return contigs.remove(contig);
    }

    public Contig elementAt(int index) {
	return (Contig)contigs.elementAt(index);
    }
}
