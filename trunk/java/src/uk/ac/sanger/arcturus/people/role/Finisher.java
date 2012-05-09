package uk.ac.sanger.arcturus.people.role;

public final class Finisher implements Role {
	private Finisher() {	
	}
	
	private static final Finisher instance = new Finisher();
	
	public static Finisher getInstance() {
		return instance;
	}
	
	public boolean canAssignProject() {
		return false;
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
