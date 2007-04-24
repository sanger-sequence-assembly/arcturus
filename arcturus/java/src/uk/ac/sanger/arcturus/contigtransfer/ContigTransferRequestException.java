package uk.ac.sanger.arcturus.contigtransfer;

public class ContigTransferRequestException extends Exception {
	public static final int UNKNOWN = -1;
	public static final int OK = 0;
	public static final int USER_NOT_AUTHORISED = 1;
	public static final int USER_NOT_AUTHORIZED = USER_NOT_AUTHORISED;
	public static final int CONTIG_NOT_CURRENT = 2;
	public static final int NO_SUCH_CONTIG = 3;
	public static final int NO_SUCH_PROJECT = 4;
	public static final int CONTIG_HAS_MOVED = 5;
	public static final int PROJECT_IS_LOCKED = 6;
	public static final int CONTIG_ALREADY_REQUESTED = 7;
	public static final int NO_SUCH_REQUEST = 8;
	public static final int USER_IS_NULL = 9;
	public static final int SQL_INSERT_FAILED = 10;
	public static final int SQL_UPDATE_FAILED = 11;
	
	protected int type = UNKNOWN;
	
	public ContigTransferRequestException(int type, String message) {
		super(message);
		this.type = type;
	}
	
	public ContigTransferRequestException(int type) {
		this.type = type;
	}
	
	public int getType() {
		return type;
	}
	
	public String getTypeAsString() {
		switch (type) {
			case USER_NOT_AUTHORISED:
				return "User not authorised";
				
			case CONTIG_NOT_CURRENT:
				return "Cntig not current";
				
			case NO_SUCH_CONTIG:
				return "No such contig";
				
			case NO_SUCH_PROJECT:
				return "No such project";
				
			case CONTIG_HAS_MOVED:
				return "Contig has moved";
				
			case PROJECT_IS_LOCKED:
				return "Project is locked";
				
			case CONTIG_ALREADY_REQUESTED:
				return "Contig already requested";
				
			case NO_SUCH_REQUEST:
				return "No such request";
				
			case USER_IS_NULL:
				return "User is null";
				
			case SQL_INSERT_FAILED:
				return "SQL INSERT failed";
				
			case SQL_UPDATE_FAILED:
				return "SQL UPDATE failed";
				
			default:
				return "Unknown (code=" + type + ")";
		}
	}
}
