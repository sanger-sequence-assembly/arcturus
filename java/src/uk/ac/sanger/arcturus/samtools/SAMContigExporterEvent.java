package uk.ac.sanger.arcturus.samtools;

public class SAMContigExporterEvent {
	public enum Type { UNKNOWN, START_CONTIG_SET, FINISH_CONTIG_SET,
		START_CONTIG, FINISH_CONTIG, READ_COUNT_UPDATE };
	
	private SAMContigExporter source;
	private Type type = Type.UNKNOWN;
	private int value = 0;
	
	public SAMContigExporterEvent(SAMContigExporter source) {
		this.source = source;
	}
	
	public void setTypeAndValue(Type type, int value) {
		this.type = type;
		this.value = value;
	}
	
	public SAMContigExporter getSource() {
		return source;
	}
	
	public Type getType() {
		return type;
	}
	
	public int getValue() {
		return value;
	}
}
