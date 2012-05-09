package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.util.List;
import java.util.Vector;

import javax.swing.tree.MutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;

public class UnscaffoldedContigsNode extends SequenceNode {
	private int contigCount = 0;
	private int contigTotalLength = 0;
	private List<Contig> contigs = new Vector<Contig>();
	
	public String toString() {
		return "Unscaffolded contigs:  " + contigCount + " contigs, " + 
			formatter.format(contigTotalLength) + " bp";
	}
	
	public void add(MutableTreeNode node) {
		if (node instanceof ContigNode) {
			ContigNode cnode = (ContigNode)node;
			
			Contig contig = cnode.getContig();
			
			contigCount++;
			
			contigTotalLength += contig.getLength();
			
			contigs.add(contig);

			super.add(cnode);
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");
	}

	public List<Contig> getContigs() {
		return contigs;
	}

}
