package uk.ac.sanger.arcturus.people.role;

public interface Role {
	public boolean canCreateProject();
	public boolean canLockProject();
	public boolean canMoveAnyContig();
	public boolean canAssignProject();
}
