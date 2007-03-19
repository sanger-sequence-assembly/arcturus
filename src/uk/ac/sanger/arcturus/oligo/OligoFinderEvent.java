package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.data.Contig;

public class OligoFinderEvent {
	public static final int UNKNOWN = 0;
	public static final int START = 1;
	public static final int START_CONTIG = 2;
	public static final int FOUND_MATCH = 3;
	public static final int FINISH_CONTIG = 4;
	public static final int FINISH = 5;
	public static final int HASH_MATCH = 6;
	
	private OligoFinder source;
	private int type = UNKNOWN;
	private Oligo oligo;
	private Contig contig;
	private int offset;
	private boolean forward;
	
	public OligoFinderEvent(OligoFinder source) {
		this.source = source;
	}
	
	public void setEvent(int type, Oligo oligo, Contig contig, int offset, boolean forward) {
		this.type = type;
		this.oligo = oligo;
		this.contig = contig;
		this.offset = offset;
		this.forward = forward;
	}
	
	public OligoFinder getSource() { return source; }
	
	public int getType() { return type; }
	
	public Oligo getOligo() { return oligo; }
	
	public Contig getContig() { return contig; }
	
	public int getOffset() { return offset; }
	
	public boolean isForward() { return forward; } 
}
