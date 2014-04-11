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

package uk.ac.sanger.arcturus.projectchange;

import java.util.EventObject;

import uk.ac.sanger.arcturus.data.Project;

public class ProjectChangeEvent extends EventObject {
	public static final int CONTIGS_CHANGED = 1;
	public static final int LOCK_CHANGED = 2;
	public static final int OWNER_CHANGED = 3;
	public static final int IMPORTED = 4;
	public static final int CREATED = 5;

	protected Project project;
	protected int type;

	public ProjectChangeEvent(Object source, Project project, int type) {
		super(source);

		this.project = project;
		this.type = type;
	}

	public void setProject(Project project) {
		this.project = project;
	}
	
	public Project getProject() {
		return project;
	}

	public void setType(int type) {
		this.type = type;
	}
	
	public int getType() {
		return type;
	}
	
	public String getTypeAsString() {
		switch (type) {
			case CONTIGS_CHANGED:
				return "CONTIGS_CHANGED";
				
			case LOCK_CHANGED:
				return "LOCK_CHANGED";
				
			case OWNER_CHANGED:
				return "OWNER_CHANGED";
				
			case IMPORTED:
				return "IMPORTED";
				
			case CREATED:
				return "CREATED";
				
			default:
				return "UNKNOWN(" + type + ")";
		}
	}

	public String toString() {
		return "ProjectChangeEvent[source=" + source + ", project="
				+ (project == null ? "null" : project.getName()) + ", type=" + getTypeAsString() + "]";
	}
}
