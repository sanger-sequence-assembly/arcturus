package uk.ac.sanger.arcturus.scaffold;

import java.util.EventObject;

public class ScaffoldEvent extends EventObject {
	public static final int UNKNOWN = -1;
	public static final int START = 0;
	public static final int FINISH = 9999;
	public static final int BEGIN_CONTIG = 1;
	public static final int CONTIG_SET_INFO = 2;

	protected int mode;
	protected String description;
	protected Object value;

	ScaffoldEvent(Object source) {
		this(source, UNKNOWN, null, null);
	}
	
	ScaffoldEvent(Object source, int mode, String description) {
		this(source, mode, description, null);
	}
	
	ScaffoldEvent(Object source, int mode, String description, Object value) {
		super(source);
		this.mode = mode;
		this.description = description;
		this.value = value;
	}

	public int getMode() {
		return mode;
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
