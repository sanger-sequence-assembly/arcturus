package uk.ac.sanger.arcturus.jobrunner;

public class JobOutput {
	public static final int STDOUT = 1;
	public static final int STDERR = 2;
	public static final int STATUS = 3;

	protected int type;
	protected String text;

	public JobOutput(int type, String text) {
		if (type != STDOUT && type != STDERR && type != STATUS)
			throw new IllegalArgumentException("Illegal type code: " + type);
		
		this.type = type;
		this.text = text;
	}

	public int getType() {
		return type;
	}
	
	public String getText() {
		return text;
	}
	
	public String getTypeName() {
		switch (type) {
		case STDOUT:
			return "STDOUT";
			
		case STDERR:
			return "STDERR";
			
		case STATUS:
			return "STATUS";
			
		default:
			return null;
		}
	}
	
	public String toString() {
		return "JobOutput[type=" + getTypeName() + ", text=" + text + "]";  
	}
}
