// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.event.TableModelEvent;
import javax.swing.table.*;
import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.people.Person;

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
	
	protected boolean displayProjectStatus = false;

	protected static final int ASSEMBLY_COLUMN = 0;
	protected static final int PROJECT_COLUMN = 1;
	protected static final int TOTAL_LENGTH_COLUMN = 2;
	protected static final int CONTIG_COUNT_COLUMN = 3;
	protected static final int MAXIMUM_LENGTH_COLUMN = 4;
	protected static final int READ_COUNT_COLUMN = 5;
	protected static final int DATE_COLUMN = 6;
	protected static final int OWNER_COLUMN = 7;
	protected static final int LOCKED_COLUMN = 8;
	protected static final int STATUS_COLUMN = 9;

	public ProjectTableModel(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;
		canEditUser = adb.isCoordinator();
		comparator = new ProjectComparator();
		comparator.setAscending(false);
		populateProjectsArray();
	}

	protected void populateProjectsArray() throws ArcturusDatabaseException {
		refresh();
		sortOnColumn(TOTAL_LENGTH_COLUMN);
	}

	public void refresh() throws ArcturusDatabaseException {
		projects.clear();


		Set<Project> projectset = adb.getAllProjects();

		for (Project project : projectset) {
			if (displayRetiredProjects || !project.isRetired())				
				projects.add(new ProjectProxy(project, minlen, minreads));
		}

		resort();
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
				
			case STATUS_COLUMN:
				return "Status";

			default:
				return "UNKNOWN";
		}
	}

	public Class<?> getColumnClass(int col) {
		switch (col) {
			case ASSEMBLY_COLUMN:
			case PROJECT_COLUMN:
			case LOCKED_COLUMN:
			case STATUS_COLUMN:
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
		return displayProjectStatus ? 10 : 9;
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
				
			case STATUS_COLUMN:
				return project.getProject().getStatusAsString();

			default:
				return null;
		}
	}

	public void setValueAt(Object value, int row, int col) {
		switch (col) {
			case OWNER_COLUMN:
				if (value instanceof Person) {
					Person person = (Person) value;

					ProjectProxy project = getProjectAtRow(row);

					try {
						project.setOwner(person);
					} catch (ArcturusDatabaseException e) {
						Arcturus.logWarning("Failed to set owner of project ID=" + project.getID() + " to " + person.getUID(), e);
					}

					fireTableChanged(new TableModelEvent(this, row));
					//fireTableCellUpdated(row, col);				
				}
				break;
				
			case LOCKED_COLUMN:
				if (value == null || value instanceof Person) {
					Person person = value == null ? null : (Person) value;

					ProjectProxy project = getProjectAtRow(row);

					try {
						project.setLockOwner(person);
					} catch (ArcturusDatabaseException e) {
						Arcturus.logWarning("Failed to set lock owner of project ID=" + project.getID() + " to " + person.getUID(), e);
					}

					fireTableChanged(new TableModelEvent(this, row));
					//fireTableCellUpdated(row, col);								
				}
				break;
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
		
		try {
			refresh();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to refresh project table model after setting minimum read count", e);
		}
	}

	public void showRetiredProjects(boolean show) {
		this.displayRetiredProjects = show;
		
		try {
			refresh();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to refresh project table model after altering show-retired-projects flag", e);
		}
	}
}
