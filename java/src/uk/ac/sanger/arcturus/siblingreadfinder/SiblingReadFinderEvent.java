package uk.ac.sanger.arcturus.siblingreadfinder;

public class SiblingReadFinderEvent {
	public enum Status { UNKNOWN, STARTED, COUNTED_SUBCLONES, IN_PROGRESS, FINISHED };
	
	protected Status status = Status.UNKNOWN;
	protected int value = 0;
	
	public void setStatus(Status status) {
		this.status = status;
	}
	
	public Status getStatus() {
		return status;
	}
	
	public void setValue(int value) {
		this.value = value;
	}
	
	public int getValue() {
		return value;
	}
}
