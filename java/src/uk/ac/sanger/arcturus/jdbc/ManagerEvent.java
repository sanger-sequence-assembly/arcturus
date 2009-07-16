package uk.ac.sanger.arcturus.jdbc;

import java.util.EventObject;

public class ManagerEvent extends EventObject {
	/**
	 * 
	 */
	private static final long serialVersionUID = -4589934060008880812L;
	public static final int START = 1;
	public static final int WORKING = 2;
	public static final int END = 3;

	protected String message = null;

	protected int state;
	protected int maxvalue;
	protected int value;

	public ManagerEvent(Object source) {
		super(source);
	}

	public ManagerEvent(Object source, String message, int state, int value,
			int maxvalue) {
		super(source);

		this.message = message;
		this.state = state;
		this.value = value;
		this.maxvalue = maxvalue;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String message) {
		this.message = message;
	}

	public int getState() {
		return state;
	}

	public void setState(int state) {
		this.state = state;
	}

	public int getValue() {
		return value;
	}

	public void setValue(int value) {
		this.value = value;
	}

	public int getMaximumValue() {
		return maxvalue;
	}

	public void setMaximumValue(int maxvalue) {
		this.maxvalue = maxvalue;
	}

	public void begin(String message, int maxvalue) {
		this.message = message;
		this.state = START;
		this.value = 0;
		this.maxvalue = maxvalue;
	}

	public void working(int value) {
		this.state = WORKING;
		this.value = value;
	}

	public void end() {
		this.state = END;
		this.value = maxvalue;
	}
}
