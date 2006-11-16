package uk.ac.sanger.arcturus.scaffold;

import java.util.EventObject;

public class ScaffoldEvent extends EventObject {
	/**
	 * 
	 */
	private static final long serialVersionUID = 3438567157606714638L;
	public static final int START = 0;
	public static final int FINISH = 9999;
	public static final int BEGIN_CONTIG = 1;
	public static final int CONTIG_SET_INFO = 2;

	protected int mode;
	protected String description;
	protected int iValue;

	ScaffoldEvent(Object source, int mode, String description) {
		super(source);
		this.mode = mode;
		this.description = description;
	}
	
	ScaffoldEvent(Object source, int mode, String description, int iValue) {
		super(source);
		this.mode = mode;
		this.description = description;
		this.iValue = iValue;
	}

	public int getMode() {
		return mode;
	}

	public String getDescription() {
		return description;
	}
	
	public int getIntegerValue() {
		return iValue;
	}
}
