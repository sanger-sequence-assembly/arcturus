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

package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

import java.util.*;
import java.sql.SQLException;

/**
 * This class represents a assembly, which is a set of projects.
 */

public class Assembly extends Core implements Comparable {
	protected Date updated = null;
	protected Date created = null;
	protected String creator = null;

	protected Set<Project> projects = null;

	/**
	 * Constructs a Assembly which does not yet have an ID. This constructor
	 * will typically be used to create a Assembly <EM>ab initio</EM> prior to
	 * putting it into an Arcturus database.
	 */

	public Assembly() {
		super();
	}

	/**
	 * Constructs a Assembly which has an ID. This constructor will typically be
	 * used when a Assembly is retrieved from an Arcturus database.
	 * 
	 * @param ID
	 *            the ID of the Assembly.
	 * @param adb
	 *            the Arcturus database to which this Assembly belongs.
	 */

	public Assembly(int ID, ArcturusDatabase adb) {
		super(ID, adb);
	}

	/**
	 * Constructs a Assembly with basic properties. This constructor will
	 * typically be used when a Assembly is retrieved from an Arcturus database.
	 * 
	 * @param name
	 *            the name of the Assembly.
	 * @param ID
	 *            the ID of the Assembly.
	 * @param updated
	 *            the date and time whne this Assembly was last updated.
	 * @param created
	 *            the date and time when this Assembly was created.
	 * @param creator
	 *            the creator of this Assembly.
	 * @param adb
	 *            the Arcturus database to which this Assembly belongs.
	 */

	public Assembly(String name, int ID, Date updated, Date created,
			String creator, ArcturusDatabase adb) {
		super(name, ID, adb);

		this.updated = updated;
		this.created = created;
		this.creator = creator;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public Date getUpdated() {
		return updated;
	}

	public void setUpdated(Date updated) {
		this.updated = updated;
	}

	public Date getCreated() {
		return created;
	}

	public void setCreated(Date created) {
		this.created = created;
	}

	public String getCreator() {
		return creator;
	}

	public void setCreator(String creator) {
		this.creator = creator;
	}

	/**
	 * Returns the number of projects currently contained in this Assembly
	 * object.
	 * 
	 * @return the number of projects currently contained in this Assembly
	 *         object.
	 */

	public int getProjectCount() {
		return (projects == null) ? 0 : projects.size();
	}

	/**
	 * Returns the Vector containing the projects currently in this Assembly
	 * object.
	 * 
	 * @return the Vector containing the projects currently in this Assembly
	 *         object.
	 */

	public Set<Project> getProjects() {
		return projects;
	}

	public void setProjects(Set<Project> projects) {
		this.projects = projects;
	}

	public void addProject(Project project) {
		if (projects == null)
			projects = new HashSet<Project>();

		projects.add(project);
	}

	public boolean removeProject(Project project) {
		if (projects == null)
			return false;
		else
			return projects.remove(project);
	}

	public void refresh() throws SQLException {
		if (adb != null)
			adb.refreshAssembly(this);
	}
	
	public String toString() {
		return name;
	}

	public int compareTo(Object o) {
		if (o instanceof Assembly) {
			Assembly that = (Assembly)o;
			
			return name.compareTo(that.name);
		} else 
			return 0;
	}
}
