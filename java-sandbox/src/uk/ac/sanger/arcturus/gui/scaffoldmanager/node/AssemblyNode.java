package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.MutableTreeNode;

public class AssemblyNode extends DefaultMutableTreeNode {
	private final String caption;
	
	public AssemblyNode(String created) {
		super();
		caption = "Assembly (created " + created + ")";
	}
	
	public void add(MutableTreeNode node) {
		if (node instanceof SuperscaffoldNode) {
			SuperscaffoldNode ssnode = (SuperscaffoldNode)node;
			
			if (ssnode.isDegenerate())
				super.add((MutableTreeNode)(ssnode.getFirstChild()));
			else
				super.add(ssnode);
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");
	}
	
	public String toString() {
		return caption;
	}
}
