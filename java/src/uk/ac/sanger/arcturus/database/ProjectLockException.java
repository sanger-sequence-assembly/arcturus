package uk.ac.sanger.arcturus.database;


public class ProjectLockException extends ArcturusDatabaseException {
	public static final int OK = 0;
	public static final int PROJECT_IS_LOCKED = 1;
	public static final int PROJECT_IS_UNLOCKED = 2;
	public static final int OPERATION_NOT_PERMITTED = 3;
	public static final int PROJECT_HAS_NO_OWNER = 4;
	
	protected int type = OK;
	
	public ProjectLockException(String message, int type) {
		super(message);
		this.type = type;
	}
	
	public ProjectLockException(int type) {
		this(null, type);
	}
	
	public int getType() {
		return type;
	}
	
	public String getTypeAsString() {
		switch (type) {
			case OK:
				return "OK";
				
			case PROJECT_IS_LOCKED:
				return "The project is already locked";
				
			case PROJECT_IS_UNLOCKED:
				return "The project is already unlocked";
				
			case OPERATION_NOT_PERMITTED:
				return "The operation is not permitted";
				
			case PROJECT_HAS_NO_OWNER:
				return "The project has no owner";
				
			default:
				return "(Unknown type code: " + type + ")";
		}
	}
	
	public String getMessage() {
		String message = super.getMessage();
		
		return message == null ? getTypeAsString() : message;
	}
}
