package uk.ac.sanger.arcturus.oligo;

public class OligoMatch {
	private Oligo oligo;
	private DNASequence sequence;
	private int offset;
	private boolean forward;
	
	public OligoMatch(Oligo oligo, DNASequence sequence, int offset, boolean forward) {
		this.oligo = oligo;
		this.sequence = sequence;
		this.offset = offset;
		this.forward = forward;
	}
	
	public Oligo getOligo() { return oligo; }
	
	public DNASequence getDNASequence() { return sequence; }
	
	public int getOffset() { return offset; }
	
	public boolean isForward() { return forward; }
}
