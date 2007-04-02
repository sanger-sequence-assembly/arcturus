package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.data.*;

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
	
	public Contig getContig() {
		return (sequence != null && sequence instanceof Contig) ? (Contig)sequence : null;
	}
	
	public Read getRead() {
		return (sequence != null && sequence instanceof Read) ? (Read)sequence : null;
	}
	
	public int getOffset() { return offset; }
	
	public boolean isForward() { return forward; }
}
