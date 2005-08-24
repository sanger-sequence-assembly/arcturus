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
    protected Vector contigs = new Vector();
    protected ContigComparator comparator;
    protected int lastSortColumn = 3;
    protected boolean garish;
    protected ArcturusDatabase adb = null;

    protected HashMap projectColours = new HashMap();

    protected final Color VIOLET1 = new Color(245, 245, 255);
    protected final Color VIOLET2 = new Color(238, 238, 255);
    protected final Color VIOLET3 = new Color(226, 226, 255);

    public ContigTableModel(ArcturusDatabase adb, Set contigset) {
	this.adb = adb;
	comparator = new ContigComparator();
	contigs.addAll(contigset);
    }

    public String getColumnName(int col) {
        switch (col) {
	case 0:
	    return "ID";

	case 1:
	    return "Project";

	case 2:
	    return "Length";

	case 3:
	    return "Reads";

	case 4:
	    return "Created";

	default:
	    return "UNKNOWN";
	}
    }

    public Class getColumnClass(int col) {
        switch (col) {
	case 0:
	case 1:
	    return String.class;

	case 2:
	case 3:
	    return Integer.class;

	case 4:
	    return java.util.Date.class;

	default:
	    return null;
	}
    }

    public int getRowCount() {
	return contigs.size();
    }

    public int getColumnCount() { return 5; }

    protected Contig getContigAtRow(int row) {
	return (Contig)contigs.elementAt(row);
    }

    public Object getValueAt(int row, int col) {
        Contig contig = getContigAtRow(row);

	switch (col) {
	case 0:
	    return contig.getName();

	case 1:
	    return contig.getProject().getName();

	case 2:
	    return new Integer(contig.getLength());

	case 3:
	    return new Integer(contig.getReadCount());

	case 4:
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
	return (col > 1);
    }

    public void sortOnColumn(int col, boolean ascending) {
	comparator.setAscending(ascending);
	sortOnColumn(col);
    }

    public void sortOnColumn(int col) {
	switch (col) {
	case 2:
	    comparator.setType(ContigComparator.BY_LENGTH);
	    break;

	case 3:
	    comparator.setType(ContigComparator.BY_READS);
	    break;

	case 4:
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
