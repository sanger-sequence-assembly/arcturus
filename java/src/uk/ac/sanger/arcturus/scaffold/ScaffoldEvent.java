package uk.ac.sanger.arcturus.scaffold;

import java.util.EventObject;

public class ScaffoldEvent extends EventObject {
	public static final int UNKNOWN = -1;
	public static final int START = 0;
	public static final int FINISH = 9999;
	public static final int BEGIN_CONTIG = 1;
	public static final int CONTIG_SET_INFO = 2;
	public static final int FINDING_SUBGRAPHS = 3;
	public static final int LINKS_EXAMINED = 4;
	public static final int CONTIGS_EXAMINED = 5;

	protected int mode;
	protected String description;
	protected int value;

	public ScaffoldEvent(Object source) {
		this(source, UNKNOWN, null, -1);
	}
	
	public ScaffoldEvent(Object source, int mode, String description) {
		this(source, mode, description, -1);
	}
	
	public ScaffoldEvent(Object source, int mode, String description, int value) {
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
				
			case LINKS_EXAMINED:
				return "LINKS_EXAMINED";
				
			case CONTIGS_EXAMINED:
				return "CONTIGS_EXAMINED";
				
			default:
				return "UNKNOWN MODE (" + mode + ")";				
		}
	}

	public String getDescription() {
		return description;
	}
	
	public int getValue() {
		return value;
	}
	
	public void setState(int mode, String description, int value) {
		this.mode = mode;
		this.description = description;
		this.value = value;	
	}
	
	public void setState(int mode, String description) {
		setState(mode, description, -1);
	}
	
	public String toString() {
		return "ScaffoldEvent[mode=" + getModeAsString() + ", description=\"" + description +
			"\", value=" + value + "]";
	} 
}
