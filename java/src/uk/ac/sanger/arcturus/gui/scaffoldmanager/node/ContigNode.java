package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.util.List;
import java.util.Vector;

import uk.ac.sanger.arcturus.data.Contig;

public class ContigNode extends SequenceNode {
	private Contig contig;
	private boolean forward;
	private boolean current;
	private List<Contig> contigs = null;
	
	public ContigNode(Contig contig, boolean forward, boolean current) {
		this.contig = contig;
		this.forward = forward;
		this.current = current;
	}

	public Contig getContig() {
		return contig;
	}
	
	public boolean isForward() {
		return forward;
	}
	
	public void reverse() {
		forward = !forward;
	}
	
	public boolean isCurrent() {
		return current;
	}
	
	public boolean isMine() {
		return contig.getProject().isMine();
	}
	
	public String toString() {
		return "Contig " + contig.getID() + " (" + formatter.format(contig.getLength()) + " bp, project "
			+ contig.getProject().getName() + ")" + (current ? "" : " *** NOT CURRENT ***");
	}

	public List<Contig> getContigs() {
		if (contigs == null) {
			contigs = new Vector<Contig>(1);
			contigs.add(contig);
		}
		
		return contigs;
	}
}
