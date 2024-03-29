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

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.database.ProjectLockException;
import uk.ac.sanger.arcturus.utils.ProjectSummary;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.people.Person;

import java.util.Date;

public class ProjectProxy {
	protected Project project = null;
	protected ProjectSummary summary = null;
	protected boolean importing = false;
	protected boolean exporting = false;

	public ProjectProxy(Project project, int minlen, int minreads) throws ArcturusDatabaseException {
		this.project = project;
		
		if (project != null)
			summary = project.getProjectSummary(minlen, minreads);
	}

	public void refreshSummary(int minlen) throws ArcturusDatabaseException {		
		if (project != null)
			summary = project.getProjectSummary(minlen);
	}

	public void refreshSummary() throws ArcturusDatabaseException {
		if (project != null)
			summary = project.getProjectSummary();
	}
	
	public void refreshSummary(int minlen, int minreads) throws ArcturusDatabaseException {
		if (project != null)
			summary = project.getProjectSummary(minlen, minreads);
	}

	public String getName() {
		return (project == null) ? null : project.getName();
	}

	public int getID() {
		return (project == null) ? -1 : project.getID();
	}

	public Project getProject() {
		return project;
	}
	
	public void setProject(Project project) {
		this.project = project;
	}
	
	public ProjectSummary getSummary() {
		return summary;
	}
	
	public void setSummary(ProjectSummary summary) {
		this.summary = summary;
	}

	public String getAssemblyName() {
		Assembly assembly = project.getAssembly();
		return (assembly == null) ? "unknown" : assembly.getName();
	}

	public int getContigCount() {
		return (summary == null) ? 0 : summary.getNumberOfContigs();
	}

	public int getMaximumLength() {
		return (summary == null) ? 0 : summary.getMaximumConsensusLength();
	}

	public int getTotalLength() {
		return (summary == null) ? 0 : summary.getTotalConsensusLength();
	}

	public int getReadCount() {
		return (summary == null) ? 0 : summary.getNumberOfReads();
	}

	public Date getNewestContigCreated() {
		return (summary == null) ? null : summary.getNewestContigCreated();
	}

	public Date getMostRecentContigUpdated() {
		return (summary == null) ? null : summary.getMostRecentContigUpdated();
	}
	
	public Date getMostRecentContigTransferOut() {
		return (summary == null) ? null : summary.getMostRecentContigTransferOut();
	}
	
	public Date getMostRecentContigChange() {
		if (summary == null)
			return null;
		
		Date contigUpdated = summary.getMostRecentContigUpdated();
		Date transferOut = summary.getMostRecentContigTransferOut();
		
		if (contigUpdated != null && transferOut != null)
			return contigUpdated.compareTo(transferOut) > 0 ? contigUpdated : transferOut;
			
		return (contigUpdated != null) ? contigUpdated : transferOut;
	}

	public Date getProjectUpdated() {
		return (project == null) ? null : project.getUpdated();
	}

	public Person getOwner() {
		return (project == null) ? null : project.getOwner();
	}
	
	public Person getLockOwner() {
		return (project == null) ? null : project.getLockOwner();
	}
	
	public boolean isMine() {
		return (project == null) ? false : project.isMine();
	}
	
	public void setImporting(boolean importing) throws IllegalStateException {
		if (exporting)
			throw new IllegalStateException("Attempted to change import state whilst exporting");
		
		this.importing = importing;
	}
	
	public boolean isImporting() {
		return importing;
	}
	
	public void setExporting(boolean exporting) throws IllegalStateException {
		if (importing)
			throw new IllegalStateException("Attempted to change export state whilst importing");
		
		this.exporting = exporting;
	}
	
	public boolean isExporting() {
		return exporting;
	}

	public void setOwner(Person person) throws ArcturusDatabaseException {
		if (project == null || project.getArcturusDatabase() == null)
			return;
		
		ArcturusDatabase adb = project.getArcturusDatabase();
		
		adb.setProjectOwner(project, person);
	}

	public void setLockOwner(Person person) throws ArcturusDatabaseException {
		if (project == null || project.getArcturusDatabase() == null)
			return;
		
		ArcturusDatabase adb = project.getArcturusDatabase();
		
		try {
			adb.setProjectLockOwner(project, person);
		} catch (ProjectLockException e) {
			Arcturus.logSevere("Unable to set lock on " + project.getName() + " for " + person, e);
		}
	
	}
}
