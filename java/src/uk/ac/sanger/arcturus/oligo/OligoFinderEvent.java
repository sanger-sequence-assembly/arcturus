package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.data.*;

public class OligoFinderEvent {
	public static final int UNKNOWN = 0;
	public static final int START_CONTIGS = 1;
	public static final int START_READS = 2;
	public static final int START_SEQUENCE = 3;
	public static final int FOUND_MATCH = 4;
	public static final int FINISH_SEQUENCE = 5;
	public static final int FINISH_CONTIGS = 6;
	public static final int FINISH_READS = 7; 
	public static final int HASH_MATCH = 8;
	public static final int ENUMERATING_FREE_READS = 9;
	public static final int FINISH = 10;
	
	private OligoFinder source;
	private int type = UNKNOWN;
	private Oligo oligo;
	private DNASequence sequence;
	private int value;
	private boolean forward;
	
	public OligoFinderEvent(OligoFinder source) {
		this.source = source;
	}
	
	public void setEvent(int type, Oligo oligo, DNASequence sequence, int value, boolean forward) {
		this.type = type;
		this.oligo = oligo;
		this.value = value;
		this.forward = forward;
		this.sequence = sequence;
	}
	
	public OligoFinder getSource() { return source; }
	
	public int getType() { return type; }
	
	public Oligo getOligo() { return oligo; }
	
	public boolean isContig() {
		return sequence != null && sequence instanceof Contig;
	}
	
	public Contig getContig() { 
		return (sequence != null && sequence instanceof Contig) ? (Contig)sequence : null;
	}
	
	public boolean isRead() {
		return sequence != null && sequence instanceof Read;
	}
	
	public Read getRead() {
		return (sequence != null && sequence instanceof Read) ? (Read)sequence : null;
	}
	
	public DNASequence getDNASequence() {
		return sequence;
	}
	
	public int getValue() { return value; }
	
	public boolean isForward() { return forward; } 
}
