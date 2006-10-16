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

	protected static final int DATE_COLUMN = 6;

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
			sortOnColumn(2);
		} catch (SQLException sqle) {
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

			case 7:
				return "Owner";

			default:
				return "UNKNOWN";
		}
	}

	public Class getColumnClass(int col) {
		switch (col) {
			case 0:
			case 1:
			case 7:
				return String.class;

			case 2:
			case 3:
			case 4:
			case 5:
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
			case 1:
				comparator.setType(ProjectComparator.BY_NAME);
				break;

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

			case 7:
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
}
