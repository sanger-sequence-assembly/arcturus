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
	protected int minlen = 0;
	protected int minreads = 0;

	public ProjectProxy(Project project) throws SQLException {
		this.project = project;
		summary = project.getProjectSummary();
	}

	public void refreshSummary(int minlen) throws SQLException {
		this.minlen = minlen;
		summary = project.getProjectSummary(minlen);
	}

	public void refreshSummary() throws SQLException {
		summary = project.getProjectSummary(minlen);
	}
	
	public void refreshSummary(int minlen, int minreads) throws SQLException {
		this.minlen = minlen;
		this.minreads = minreads;
		summary = project.getProjectSummary(minlen, minreads);
	}

	public String getName() {
		return project.getName();
	}

	public int getID() {
		return project.getID();
	}

	public Project getProject() {
		return project;
	}

	public String getAssemblyName() {
		Assembly assembly = project.getAssembly();
		return (assembly == null) ? "unknown" : assembly.getName();
	}

	public int getContigCount() {
		return summary.getNumberOfContigs();
	}

	public int getMaximumLength() {
		return summary.getMaximumConsensusLength();
	}

	public int getTotalLength() {
		return summary.getTotalConsensusLength();
	}

	public int getReadCount() {
		return summary.getNumberOfReads();
	}

	public Date getNewestContigCreated() {
		return summary.getNewestContigCreated();
	}

	public Date getMostRecentContigUpdated() {
		return summary.getMostRecentContigUpdated();
	}

	public Date getProjectUpdated() {
		return project.getUpdated();
	}

	public Person getOwner() {
		return project.getOwner();
	}
}
