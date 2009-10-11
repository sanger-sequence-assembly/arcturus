package uk.ac.sanger.arcturus.gui.organismtree;

import javax.naming.directory.DirContext;

public class InstanceNode extends OrganismTreeNode{
	public InstanceNode(DirContext context, String name) {
		super(context, true, name);
	}
}
