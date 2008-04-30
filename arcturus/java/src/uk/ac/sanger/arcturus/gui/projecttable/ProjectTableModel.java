package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.table.*;
import java.sql.*;
import java.util.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.utils.ProjectSummary;
import uk.ac.sanger.arcturus.Arcturus;

class ProjectTableModel extends AbstractTableModel implements
		SortableTableModel {
	public static final int PROJECT_UPDATED_DATE = 1;
	public static final int CONTIG_CREATED_DATE = 2;
	public static final int CONTIG_UPDATED_DATE = 3;

	protected Vector<ProjectProxy> projects = new Vector<ProjectProxy>();
	protected ProjectComparator comparator;
	protected int lastSortColumn = 3;
	protected ArcturusDatabase adb = null;
	protected int dateColumnType = CONTIG_UPDATED_DATE;
	protected int minreads = 0;
	protected int minlen = 0;
	protected boolean canEditUser = false;
	protected boolean displayRetiredProjects = false;

	protected static final int ASSEMBLY_COLUMN = 0;
	protected static final int PROJECT_COLUMN = 1;
	protected static final int TOTAL_LENGTH_COLUMN = 2;
	protected static final int CONTIG_COUNT_COLUMN = 3;
	protected static final int MAXIMUM_LENGTH_COLUMN = 4;
	protected static final int READ_COUNT_COLUMN = 5;
	protected static final int DATE_COLUMN = 6;
	protected static final int OWNER_COLUMN = 7;
	protected static final int LOCKED_COLUMN = 8;

	public ProjectTableModel(ArcturusDatabase adb) {
		this.adb = adb;
		canEditUser = adb.isCoordinator();
		comparator = new ProjectComparator();
		comparator.setAscending(false);
		populateProjectsArray();
	}

	protected void populateProjectsArray() {
		refresh();
		sortOnColumn(TOTAL_LENGTH_COLUMN);
	}

	public void refresh() {
		projects.clear();

		try {
			Map map = adb.getProjectSummary(minlen, minreads);

			Set<Project> projectset = adb.getAllProjects();

			for (Project project : projectset) {
				if (displayRetiredProjects || !project.isRetired()) {
					ProjectSummary summary = (ProjectSummary) map
							.get(new Integer(project.getID()));

					projects.add(new ProjectProxy(project, summary));
				}
			}

			resort();
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error whilst refreshing project table", sqle);
		}
	}

	private void resort() {
		sortOnColumn(lastSortColumn);
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

			case LOCKED_COLUMN:
				return "Lock status";

			default:
				return "UNKNOWN";
		}
	}

	public Class<?> getColumnClass(int col) {
		switch (col) {
			case ASSEMBLY_COLUMN:
			case PROJECT_COLUMN:
			case LOCKED_COLUMN:
				return String.class;

			case OWNER_COLUMN:
				return Person.class;

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
		return 9;
	}

	public ProjectProxy getProjectAtRow(int row) {
		return (ProjectProxy) projects.elementAt(row);
	}

	public Object getValueAt(int row, int col) {
		ProjectProxy project = getProjectAtRow(row);

		switch (col) {
			case ASSEMBLY_COLUMN:
				return project.getAssemblyName();

			case PROJECT_COLUMN:
				return project.getName();

			case TOTAL_LENGTH_COLUMN:
				return new Integer(project.getTotalLength());

			case CONTIG_COUNT_COLUMN:
				return new Integer(project.getContigCount());

			case MAXIMUM_LENGTH_COLUMN:
				return new Integer(project.getMaximumLength());

			case READ_COUNT_COLUMN:
				return new Integer(project.getReadCount());

			case DATE_COLUMN:
				switch (dateColumnType) {
					case PROJECT_UPDATED_DATE:
						return project.getProjectUpdated();

					case CONTIG_CREATED_DATE:
						return project.getNewestContigCreated();

					case CONTIG_UPDATED_DATE:
						return project.getMostRecentContigChange();

					default:
						return null;
				}

			case OWNER_COLUMN:
				return project.getOwner();
				// return owner == null ? null : owner.getName();

			case LOCKED_COLUMN:
				Person lockowner = project.getLockOwner();
				return (lockowner == null || lockowner.getName() == null ? null
						: "Locked by " + lockowner.getName());

			default:
				return null;
		}
	}

	public boolean isCellEditable(int row, int col) {
		return canEditUser && col == OWNER_COLUMN;
	}

	public void setValueAt(Object value, int row, int col) {
		if (col == OWNER_COLUMN && value instanceof Person) {
			Person person = (Person) value;

			ProjectProxy project = getProjectAtRow(row);

			project.setOwner(person);

			fireTableCellUpdated(row, col);
		}
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
		this.minreads = minreads;
		refresh();
	}

	public void showRetiredProjects(boolean show) {
		this.displayRetiredProjects = show;
		refresh();
	}
}
