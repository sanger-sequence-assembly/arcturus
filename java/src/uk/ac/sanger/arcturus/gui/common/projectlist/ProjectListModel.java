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

package uk.ac.sanger.arcturus.gui.common.projectlist;

import java.sql.SQLException;
import java.util.Arrays;
import java.util.Set;

import javax.swing.AbstractListModel;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ProjectListModel extends AbstractListModel {
	ProjectProxy[] projects;
	ArcturusDatabase adb;

	public ProjectListModel(ArcturusDatabase adb) {
		this.adb = adb;
		try {
			refresh();
		} catch (SQLException sqle) {
			Arcturus.logWarning(
					"An error occurred when initialising the project list",
					sqle);
		}
	}

	public void refresh() throws SQLException {
		Set<Project> projectset = adb.getAllProjects();
		
		int activeCount = 0;
		
		for (Project project : projectset)
			if (project.isActive())
				activeCount++;

		projects = new ProjectProxy[activeCount];

		int i = 0;

		for (Project project : projectset)
			if (project.isActive())
			  projects[i++] = new ProjectProxy(project);

		Arrays.sort(projects);
		
		fireContentsChanged(this, 0, projects.length);
	}

	public Object getElementAt(int index) {
		return projects[index];
	}

	public int getSize() {
		return projects.length;
	}

	public ProjectProxy getProjectProxyByName(String name) {
		for (int i = 0; i < projects.length; i++)
			if (projects[i].toString().equalsIgnoreCase(name))
				return projects[i];

		return null;
	}
}
