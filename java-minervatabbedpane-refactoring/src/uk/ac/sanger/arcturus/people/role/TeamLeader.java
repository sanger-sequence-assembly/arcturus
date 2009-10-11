package uk.ac.sanger.arcturus.people.role;

public final class TeamLeader implements Role {
	private TeamLeader() {	
	}
	
	private static final TeamLeader instance = new TeamLeader();
	
	public static TeamLeader getInstance() {
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
