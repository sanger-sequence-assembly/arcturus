package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.MutableTreeNode;

public class SuperscaffoldNode extends SequenceNode {
	private int length = 0;
	private int contigs = 0;
	private int scaffolds = 0;
	private int myScaffolds = 0;
	
	public void add(MutableTreeNode node) {
		if (node instanceof ScaffoldNode) {
			ScaffoldNode snode = (ScaffoldNode)node;
			
			length += snode.length();
			contigs += snode.getContigCount();
			
			if (snode.hasMyContigs())
				myScaffolds++;
			
			if (snode.getContigCount() == 1) {
				ContigNode cnode = (ContigNode)snode.getFirstChild();
				
				if (!snode.isForward())
					cnode.reverse();
					
				super.add(cnode);
			} else {
				scaffolds++;
				
				super.add(snode);
			}
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");
	}
	
	public String toString() {
		return "Superscaffold of " + scaffolds + " scaffolds, " + contigs + " contigs, " + 
			formatter.format(length) + " bp";
	}
	
	public int length() {
		return length;
	}
	
	public int getContigCount() {
		return contigs;
	}
	
	public boolean hasMyScaffolds() {
		return myScaffolds > 0;
	}

	public int getScaffoldCount() {
		return scaffolds;
	}
	
	public boolean isDegenerate() {
		return scaffolds == 1 && getChildCount() == 1;
	}
}
