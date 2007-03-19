package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.data.Contig;

public class OligoMatch {
	private Oligo oligo;
	private Contig contig;
	private int offset;
	private boolean forward;
	
	public OligoMatch(Oligo oligo, Contig contig, int offset, boolean forward) {
		this.oligo = oligo;
		this.contig = contig;
		this.offset = offset;
		this.forward = forward;
	}
	
	public Oligo getOligo() { return oligo; }
	
	public Contig getContig() { return contig; }
	
	public int getOffset() { return offset; }
	
	public boolean isForward() { return forward; }
}
