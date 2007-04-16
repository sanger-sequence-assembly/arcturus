package uk.ac.sanger.arcturus.gui.projecttable;

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

import uk.ac.sanger.arcturus.people.Person;

import java.sql.SQLException;
import java.util.Date;

public class ProjectProxy {
	protected Project project = null;
	protected ProjectSummary summary = null;
	
	public ProjectProxy(Project project, ProjectSummary summary) {
		this.project = project;
		this.summary = summary;
	}

	public ProjectProxy(Project project) throws SQLException {
		this.project = project;
		
		if (project != null)
			summary = project.getProjectSummary();
	}

	public void refreshSummary(int minlen) throws SQLException {		
		if (project != null)
			summary = project.getProjectSummary(minlen);
	}

	public void refreshSummary() throws SQLException {
		if (project != null)
			summary = project.getProjectSummary();
	}
	
	public void refreshSummary(int minlen, int minreads) throws SQLException {
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
		return (summary == null) ? -1 : summary.getNumberOfContigs();
	}

	public int getMaximumLength() {
		return (summary == null) ? -1 : summary.getMaximumConsensusLength();
	}

	public int getTotalLength() {
		return (summary == null) ? -1 : summary.getTotalConsensusLength();
	}

	public int getReadCount() {
		return (summary == null) ? -1 : summary.getNumberOfReads();
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
}
