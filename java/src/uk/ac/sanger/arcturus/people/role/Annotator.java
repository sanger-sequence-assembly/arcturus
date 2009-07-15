package uk.ac.sanger.arcturus.people.role;

public final class Annotator implements Role {
	private Annotator() {	
	}
	
	private static final Annotator instance = new Annotator();
	
	public static Annotator getInstance() {
		return instance;
	}
	
	public boolean canAssignProject() {
		return false;
	}

	public boolean canCreateProject() {
		return false;
	}

	public boolean canLockProject() {
		return false;
	}

	public boolean canMoveAnyContig() {
		return false;
	}
}
