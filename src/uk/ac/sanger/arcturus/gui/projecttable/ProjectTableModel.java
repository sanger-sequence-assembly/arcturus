package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.table.*;
import java.sql.*;
import java.util.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.people.Person;

class ProjectTableModel extends AbstractTableModel implements
		SortableTableModel {
	/**
	 * 
	 */
	private static final long serialVersionUID = -3721116652612453485L;
	public static final int PROJECT_UPDATED_DATE = 1;
	public static final int CONTIG_CREATED_DATE = 2;
	public static final int CONTIG_UPDATED_DATE = 3;

	protected Vector projects = new Vector();
	protected ProjectComparator comparator;
	protected int lastSortColumn = 3;
	protected ArcturusDatabase adb = null;
	protected int dateColumnType = CONTIG_UPDATED_DATE;

	protected static final int ASSEMBLY_COLUMN = 0;
	protected static final int PROJECT_COLUMN = 1;
	protected static final int TOTAL_LENGTH_COLUMN = 2;
	protected static final int CONTIG_COUNT_COLUMN = 3;
	protected static final int MAXIMUM_LENGTH_COLUMN = 4;
	protected static final int READ_COUNT_COLUMN = 5;
	protected static final int DATE_COLUMN = 6;
	protected static final int OWNER_COLUMN = 7;

	public ProjectTableModel(ArcturusDatabase adb) {
		this.adb = adb;
		comparator = new ProjectComparator();
		populateProjectsArray();
	}

	protected void populateProjectsArray() {
		try {
			Set projectset = adb.getAllProjects();

			for (Iterator iter = projectset.iterator(); iter.hasNext();) {
				Project project = (Project) iter.next();
				projects.add(new ProjectProxy(project));
			}

			comparator.setAscending(false);
			sortOnColumn(TOTAL_LENGTH_COLUMN);
		} catch (SQLException sqle) {
			sqle.printStackTrace();
			System.exit(1);
		}
	}

	public String getColumnName(int col) {
		switch (col) {
			case ASSEMBLY_COLUMN:
				return "Assembly";

			case PROJECT_COLUMN:
				return "Project";

			case TOTAL_LENGTH_COLUMN:
				return "Total length";

			case CONTIG_COUNT_COLUMN:
				return "Contigs";

			case MAXIMUM_LENGTH_COLUMN:
				return "Max length";

			case READ_COUNT_COLUMN:
				return "Reads";

			case DATE_COLUMN:
				switch (dateColumnType) {
					case PROJECT_UPDATED_DATE:
						return "Project updated";

					case CONTIG_CREATED_DATE:
						return "Newest contig";

					case CONTIG_UPDATED_DATE:
						return "Last contig update";

					default:
						return "UNKNOWN";
				}

			case OWNER_COLUMN:
				return "Owner";

			default:
				return "UNKNOWN";
		}
	}

	public Class getColumnClass(int col) {
		switch (col) {
			case ASSEMBLY_COLUMN:
			case PROJECT_COLUMN:
			case OWNER_COLUMN:
				return String.class;

			case TOTAL_LENGTH_COLUMN:
			case CONTIG_COUNT_COLUMN:
			case MAXIMUM_LENGTH_COLUMN:
			case READ_COUNT_COLUMN:
				return Integer.class;

			case DATE_COLUMN:
				return java.util.Date.class;

			default:
				return null;
		}
	}

	public int getRowCount() {
		return projects.size();
	}

	public int getColumnCount() {
		return 8;
	}

	protected ProjectProxy getProjectAtRow(int row) {
		return (ProjectProxy) projects.elementAt(row);
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

			case DATE_COLUMN:
				switch (dateColumnType) {
					case PROJECT_UPDATED_DATE:
						return project.getProjectUpdated();

					case CONTIG_CREATED_DATE:
						return project.getNewestContigCreated();

					case CONTIG_UPDATED_DATE:
						return project.getMostRecentContigUpdated();

					default:
						return null;
				}

			case 7:
				Person owner = project.getOwner();
				String name = owner.getName();
				if (name == null)
					name = owner.getUID();

				return name;

			default:
				return null;
		}
	}

	public boolean isCellEditable(int row, int col) {
		return false;
	}

	public boolean isColumnSortable(int col) {
		return (col > 0);
	}

	public void sortOnColumn(int col, boolean ascending) {
		comparator.setAscending(ascending);
		sortOnColumn(col);
	}

	public void sortOnColumn(int col) {
		switch (col) {
			case PROJECT_COLUMN:
				comparator.setType(ProjectComparator.BY_NAME);
				break;

			case TOTAL_LENGTH_COLUMN:
				comparator.setType(ProjectComparator.BY_TOTAL_LENGTH);
				break;

			case CONTIG_COUNT_COLUMN:
				comparator.setType(ProjectComparator.BY_CONTIGS);
				break;

			case MAXIMUM_LENGTH_COLUMN:
				comparator.setType(ProjectComparator.BY_MAXIMUM_LENGTH);
				break;

			case READ_COUNT_COLUMN:
				comparator.setType(ProjectComparator.BY_READS);
				break;

			case DATE_COLUMN:
				switch (dateColumnType) {
					case PROJECT_UPDATED_DATE:
						comparator
								.setType(ProjectComparator.BY_PROJECT_UPDATED_DATE);
						break;

					case CONTIG_CREATED_DATE:
						comparator
								.setType(ProjectComparator.BY_CONTIG_CREATED_DATE);
						break;

					case CONTIG_UPDATED_DATE:
						comparator
								.setType(ProjectComparator.BY_CONTIG_UPDATED_DATE);
						break;
				}
				break;

			case OWNER_COLUMN:
				comparator.setType(ProjectComparator.BY_OWNER);
				break;
		}

		lastSortColumn = col;

		Collections.sort(projects, comparator);

		fireTableDataChanged();
	}

	public void setDateColumn(int dateColumnType) {
		this.dateColumnType = dateColumnType;

		fireTableStructureChanged();

		if (lastSortColumn == DATE_COLUMN)
			sortOnColumn(DATE_COLUMN);
		else
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
		return (ProjectProxy) projects.elementAt(index);
	}

	public ArcturusDatabase getArcturusDatabase() {
		return adb;
	}

	public void showMultiReadContigs() {
		setMinimumReads(2);
	}

	public void showAllContigs() {
		setMinimumReads(0);
	}
	
	protected void setMinimumReads(int minreads) {
		for (Enumeration e = projects.elements(); e.hasMoreElements();) {
			ProjectProxy proxy = (ProjectProxy) e.nextElement();
			try {
				proxy.refreshSummary(0, minreads);
			}
			catch (SQLException sqle) {}
		}

		sortOnColumn(lastSortColumn);	
	}
}
