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

package uk.ac.sanger.arcturus.sequencingproject;

import javax.sql.DataSource;

public class SequencingProject implements Comparable<SequencingProject> {
	protected String instance;
	protected String path;
	protected String name;
	protected String description;
	protected DataSource datasource;
	
	public SequencingProject(String instance, String path, String name, String description, DataSource datasource) {
		this.instance = instance;
		this.path = path;
		this.name = name;
		this.description = description;
		this.datasource = datasource;
	}
	
	public String getInstance() {
		return instance;
	}
	
	public String getPath() {
		return path;
	}
	
	public String getName() {
		return name;
	}
	
	public String getDescription() {
		return description;
	}
	
	public DataSource getDataSource() {
		return datasource;
	}

	public int compareTo(SequencingProject that) {
		int diff = compareString(this.instance, that.instance);
		
		if (diff != 0)
			return diff;
		
		diff = compareString(this.path, that.path);
		
		if (diff != 0)
			return diff;
		
		return compareString(this.name, that.name);
	}
	
	private int compareString(String str1, String str2) {
		if (str1 == null && str2 == null)
			return 0;
		
		if (str1 == null && str2 != null)
			return -1;
		
		if (str1 != null && str2 == null)
			return 1;
		
		return str1.compareTo(str2);
	}

	public String toString() {
		return "SequencingProject[instance=" + instance + ", path=" + path + ", name=" + name +
			", description=" + description + ", datasource=" + datasource + "]";
	}
}
