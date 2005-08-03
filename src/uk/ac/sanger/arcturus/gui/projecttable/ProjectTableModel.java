package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.table.*;
import java.awt.*;
import java.sql.*;
import java.util.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.gui.SortableTableModel;

class ProjectTableModel extends AbstractTableModel implements SortableTableModel {
    protected Vector projects = new Vector();
    protected ProjectComparator comparator;
    protected int lastSortColumn = 3;
    protected ArcturusDatabase adb = null;

    public ProjectTableModel(ArcturusDatabase adb) {
	this.adb = adb;
	comparator = new ProjectComparator();
	populateProjectsArray();
    }

    protected void populateProjectsArray() {
	try {
	    Set projectset = adb.getAllProjects();

	    for (Iterator iter = projectset.iterator(); iter.hasNext();) {
		Project project = (Project)iter.next();
		projects.add(new ProjectProxy(project));
	    }

	    comparator.setAscending(false);
	    sortOnColumn(2);
	}
	catch (SQLException sqle) {
	    sqle.printStackTrace();
	    System.exit(1);
	}
    }

    public String getColumnName(int col) {
        switch (col) {
	case 0:
	    return "Assembly";

	case 1:
	    return "Project";

	case 2:
	    return "Total length";

	case 3:
	    return "Contigs";

	case 4:
	    return "Max length";

	case 5:
	    return "Reads";

	case 6:
	    return "Updated";

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
	case 4:
	case 5:
	    return Integer.class;

	case 6:
	    return java.util.Date.class;

	default:
	    return null;
	}
    }

    public int getRowCount() {
	return projects.size();
    }

    public int getColumnCount() { return 7; }

    protected ProjectProxy getProjectAtRow(int row) {
	return (ProjectProxy)projects.elementAt(row);
    }

    public Object getValueAt(int row, int col) {
        ProjectProxy project = getProjectAtRow(row);

	switch (col) {
	case 0:
	    return project.getAssemblyName();

	case 1:
	    return project.getName();

	case 2:
	    return new Integer(project.getTotalLength());

	case 3:
	    return new Integer(project.getContigCount());

	case 4:
	    return new Integer(project.getMaximumLength());

	case 5:
	    return new Integer(project.getReadCount());

	case 6:
	    return project.getNewestContigCreated();

	default:
	    return null;
	}
    }

    public boolean isCellEditable(int row, int col) { return false; }

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
	    comparator.setType(ProjectComparator.BY_TOTAL_LENGTH);
	    break;

	case 3:
	    comparator.setType(ProjectComparator.BY_CONTIGS);
	    break;

	case 4:
	    comparator.setType(ProjectComparator.BY_MAXIMUM_LENGTH);
	    break;

	case 5:
	    comparator.setType(ProjectComparator.BY_READS);
	    break;

	case 6:
	    comparator.setType(ProjectComparator.BY_DATE);
	    break;
	}

	lastSortColumn = col;

	Collections.sort(projects, comparator);

	fireTableDataChanged();
    }

    public void add(int index, ProjectProxy project) {
	projects.add(index, project);
    }

    public Object remove(int index) {
	return projects.remove(index);
    }

    public boolean remove(ProjectProxy project) {
	return projects.remove(project);
    }

    public ProjectProxy elementAt(int index) {
	return (ProjectProxy)projects.elementAt(index);
    }
}
