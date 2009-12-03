package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.util.List;
import java.util.Vector;

import javax.swing.tree.MutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;

public class SuperscaffoldNode extends SequenceNode {
	private int length = 0;
	private int scaffolds = 0;
	private List<Contig> contigs = new Vector<Contig>();
	
	public void add(MutableTreeNode node) {
		if (node instanceof ScaffoldNode) {
			ScaffoldNode snode = (ScaffoldNode)node;
			
			length += snode.length();
			
			if (snode.getContigCount() == 1) {
				ContigNode cnode = (ContigNode)snode.getFirstChild();
				
				if (!snode.isForward())
					cnode.reverse();
					
				contigs.add(cnode.getContig());
				
				super.add(cnode);
			} else {
				scaffolds++;
				
				contigs.addAll(snode.getContigs());
				
				super.add(snode);
			}
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");
	}
	
	public String toString() {
		return "Superscaffold of " + scaffolds + " scaffolds, " + contigs.size() + " contigs, " + 
			formatter.format(length) + " bp";
	}
	
	public int length() {
		return length;
	}
	
	public int getContigCount() {
		return contigs.size();
	}
	
	public boolean hasMyContigs() {
		for (Contig contig : contigs)
			if (contig.getProject().isMine())
				return true;
		
		return false;
	}

	public int getScaffoldCount() {
		return scaffolds;
	}
	
	public boolean isDegenerate() {
		return scaffolds == 1 && getChildCount() == 1;
	}

	public List<Contig> getContigs() {
		return contigs;
	}
}
