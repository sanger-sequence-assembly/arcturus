package uk.ac.sanger.arcturus.people.role;

public final class Coordinator implements Role {
	private Coordinator() {	
	}
	
	private static final Coordinator instance = new Coordinator();
	
	public static Coordinator getInstance() {
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
