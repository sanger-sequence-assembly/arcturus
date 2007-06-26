package uk.ac.sanger.arcturus.projectchange;

import java.util.EventObject;

import uk.ac.sanger.arcturus.data.Project;

public class ProjectChangeEvent extends EventObject {
	public static final int CONTIGS_CHANGED = 1;
	public static final int LOCK_CHANGED = 2;
	public static final int OWNER_CHANGED = 3;

	protected Project project;
	protected int type;

	public ProjectChangeEvent(Object source, Project project, int type) {
		super(source);

		this.project = project;
		this.type = type;
	}

	public Project getProject() {
		return project;
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
				
			default:
				return "UNKNOWN(" + type + ")";
		}
	}

	public String toString() {
		return "ProjectChangeEvent[source=" + source + ", project="
				+ (project == null ? "null" : project.getName()) + ", type=" + getTypeAsString() + "]";
	}
}
