package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.MutableTreeNode;

public class ScaffoldNode extends DefaultMutableTreeNode {
	private MutableTreeNode lastNode = null;
	private int length = 0;
	private int contigs = 0;
	private boolean forward;
	
	public ScaffoldNode(boolean forward) {
		this.forward = forward;
	}
	
	public void add(MutableTreeNode node) {
		if (node instanceof ContigNode) {
			if (lastNode == null || lastNode instanceof GapNode) {
				length += ((ContigNode)node).getContig().getLength();
				contigs++;
			} else
				throw new IllegalArgumentException("Cannot add a ContigNode at this point.");
		} else if (node instanceof GapNode) {
			if (lastNode != null && lastNode instanceof ContigNode) {
				length += ((GapNode)node).length();
			} else
				throw new IllegalArgumentException("Cannot add a GapNode at this point.");
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");

		super.add(node);
		
		lastNode = node;
	}
	
	public int length() {
		return length;
	}
	
	public int getContigCount() {
		return contigs;
	}
	
	public boolean isForward() {
		return forward;
	}
	
	public String toString() {
		return "Scaffold of " + contigs + " contigs, " + length + " bp";
	}
}
