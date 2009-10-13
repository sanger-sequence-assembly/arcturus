package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.DefaultMutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;

public class ContigNode extends DefaultMutableTreeNode {
	private Contig contig;
	private boolean forward;
	
	public ContigNode(Contig contig, boolean forward) {
		this.contig = contig;
		this.forward = forward;
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
	
	public String toString() {
		return "Contig " + contig.getID() + " (" + contig.getLength() + " bp, project "
			+ contig.getProject().getName() + ")";
	}
}
