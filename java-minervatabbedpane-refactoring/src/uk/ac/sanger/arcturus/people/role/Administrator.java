package uk.ac.sanger.arcturus.people.role;

public final class Administrator implements Role {
	private Administrator() {	
	}
	
	private static final Administrator instance = new Administrator();
	
	public static Administrator getInstance() {
		return instance;
	}
	
	public boolean canAssignProject() {
		return true;
	}

	public boolean canCreateProject() {
		return true;
	}

	public boolean canLockProject() {
		return true;
	}

	public boolean canMoveAnyContig() {
		return true;
	}
}
