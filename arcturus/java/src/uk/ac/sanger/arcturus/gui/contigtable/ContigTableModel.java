package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.table.*;
import java.awt.*;
import java.sql.*;
import java.util.*;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import uk.ac.sanger.arcturus.gui.Minerva;
import uk.ac.sanger.arcturus.gui.SortableTableModel;

class ContigTableModel extends AbstractTableModel implements SortableTableModel {
    protected Vector contigs = new Vector();
    protected ContigComparator comparator;
    protected int lastSortColumn = 3;
    protected boolean garish;
    protected ArcturusDatabase adb = null;

    protected final Color VIOLET1 = new Color(245, 245, 255);
    protected final Color VIOLET2 = new Color(238, 238, 255);
    protected final Color VIOLET3 = new Color(226, 226, 255);

    public ContigTableModel(Minerva minerva, Project[] projects) {
	adb = minerva.getArcturusDatabase();
	comparator = new ContigComparator();
	populateContigsArray(projects);
	garish = Boolean.getBoolean("garish");
    }

    protected void populateContigsArray(Project[] projects) {
	try {
	    for (int i = 0; i < projects.length; i++)
		addContigs(projects[i]);

	    System.err.println("Total number of contigs: " + contigs.size());
	    comparator.setAscending(false);
	    sortOnColumn(2);
	}
	catch (SQLException sqle) {
	    sqle.printStackTrace();
	    System.exit(1);
	}
    }

    private void addContigs(Project project) throws SQLException {
	if (project != null) {
	    Set contigset = project.getContigs(true);
	    System.err.println("Got " + contigset.size() + " contigs for project " + project.getName());
	    contigs.addAll(contigset);
	}
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
	    return String.class;

	case 1:
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
	    return new Integer(contig.getProject().getID());

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
	int projid = getContigAtRow(row).getProject().getID();

	if (projid == 0)
	    return Color.WHITE;

	if (garish) {
	    switch (projid%5) {
	    case 0:
		return Color.CYAN;
		
	    case 1:
		return Color.YELLOW;
		
	    case 2:
		return Color.RED;
		
	    case 3:
		return Color.GREEN;
		
	    case 4:
		return Color.BLUE;
		
	    default:
		return Color.LIGHT_GRAY;
	    }
	} else
	    return (projid % 2 == 0) ? VIOLET1 : VIOLET3;
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
