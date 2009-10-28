package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.text.DecimalFormat;

import javax.swing.tree.DefaultMutableTreeNode;

public abstract class SequenceNode extends DefaultMutableTreeNode {
	protected static final DecimalFormat formatter = new DecimalFormat();
	
	static {
		formatter.setGroupingSize(3);
	}
}
