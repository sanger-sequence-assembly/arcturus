package uk.ac.sanger.arcturus.scaffold;

import java.util.EventObject;

public class ScaffoldEvent extends EventObject {
	public static final int UNKNOWN = -1;
	public static final int START = 0;
	public static final int FINISH = 9999;
	public static final int BEGIN_CONTIG = 1;
	public static final int CONTIG_SET_INFO = 2;
	public static final int FINDING_SUBGRAPHS = 3;

	protected int mode;
	protected String description;
	protected Object value;

	public ScaffoldEvent(Object source) {
		this(source, UNKNOWN, null, null);
	}
	
	public ScaffoldEvent(Object source, int mode, String description) {
		this(source, mode, description, null);
	}
	
	public ScaffoldEvent(Object source, int mode, String description, Object value) {
		super(source);
		this.mode = mode;
		this.description = description;
		this.value = value;
	}

	public int getMode() {
		return mode;
	}
	
	public String getModeAsString() {
		switch (mode) {
			case UNKNOWN:
				return "UNKNOWN";
				
			case START:
				return "START";
				
			case FINISH:
				return "FINISH";
				
			case BEGIN_CONTIG:
				return "BEGIN CONTIG";
				
			case CONTIG_SET_INFO:
				return "CONTIG SET INFO";
				
			case FINDING_SUBGRAPHS:
				return "FINDING SUBGRAPHS";
				
			default:
				return "UNKNOWN MODE (" + mode + ")";				
		}
	}

	public String getDescription() {
		return description;
	}
	
	public Object getValue() {
		return value;
	}
	
	public void setState(int mode, String description, Object value) {
		this.mode = mode;
		this.description = description;
		this.value = value;	
	}
	
	public void setState(int mode, String description) {
		setState(mode, description, null);
	}
}
