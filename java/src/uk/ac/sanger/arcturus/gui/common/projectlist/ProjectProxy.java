package uk.ac.sanger.arcturus.gui.common.projectlist;

import uk.ac.sanger.arcturus.data.Project;

public class ProjectProxy implements Comparable {
	protected final Project project;

	public ProjectProxy(Project project) {
		this.project = project;
	}

	public Project getProject() {
		return project;
	}

	public String toString() {
		return project.getName();
	}

	public int compareTo(Object o) {
		ProjectProxy that = (ProjectProxy) o;
		return project.getName()
				.compareToIgnoreCase(that.project.getName());
	}
}
