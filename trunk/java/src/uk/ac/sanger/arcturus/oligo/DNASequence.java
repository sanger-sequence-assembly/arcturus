package uk.ac.sanger.arcturus.oligo;

public class DNASequence {
	public static final int READ = 1;
	public static final int CONTIG = 2;
	
	private int type;
	private int ID;
	private String name;
	private int sequenceLength;
	private String projectName;
	
	private DNASequence(int type, int ID, String name, int sequenceLength, String projectName) {
		this.type = type;
		this.ID = ID;
		this.name = name;
		this.sequenceLength = sequenceLength;
		this.projectName = projectName;
	}
	
	public static DNASequence createContigInstance(int ID, String name, int sequenceLength, String projectName) {
		return new DNASequence(CONTIG, ID, name, sequenceLength, projectName);
	}
	
	public static DNASequence createReadInstance(int ID, String name) {
		return new DNASequence(READ, ID, name, 0, null);
	}
	
	public int getType() {
		return type;
	}
	
	public boolean isContig() {
		return type == CONTIG;
	}
	
	public boolean isRead() {
		return type == READ;
	}
	
	public int getID() {
		return ID;
	}
	
	public String getName() {
		return name;
	}
	
	public int getSequenceLength() {
		return sequenceLength;
	}
	
	public String getProjectName() {
		return projectName;
	}
	
	public String toString() {
		switch (type) {
			case CONTIG:
				return "Contig " + ID + " (" + name + ", " + sequenceLength + " bp, in " + projectName + ")";
				
			case READ:
				return "Read " + name;
				
			default:
				return "DNASequence object of unknown origin";
		}
	}
}
