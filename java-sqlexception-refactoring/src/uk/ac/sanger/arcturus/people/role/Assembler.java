package uk.ac.sanger.arcturus.people.role;

public final class Assembler implements Role {
	private Assembler() {	
	}
	
	private static final Assembler instance = new Assembler();
	
	public static Assembler getInstance() {
		return instance;
	}
	
	public boolean canAssignProject() {
		return false;
	}

	public boolean canCreateProject() {
		return false;
	}

	public boolean canLockProject() {
		return true;
	}

	public boolean canMoveAnyContig() {
		return false;
	}
}
