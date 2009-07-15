package uk.ac.sanger.arcturus.gui.organismtree;

import javax.swing.tree.DefaultMutableTreeNode;

public class OrganismTreeNode extends DefaultMutableTreeNode {
	private String name;

	public OrganismTreeNode(Object userObject, boolean allowsChildren,
			String name) {
		super(userObject, allowsChildren);
		this.name = name;
	}

	public String getName() {
		return name;
	}

	public String toString() {
		return name;
	}
}
