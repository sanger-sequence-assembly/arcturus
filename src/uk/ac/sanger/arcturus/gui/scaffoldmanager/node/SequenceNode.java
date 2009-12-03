package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.text.DecimalFormat;
import java.util.List;

import javax.swing.tree.DefaultMutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;

public abstract class SequenceNode extends DefaultMutableTreeNode {
	protected static final DecimalFormat formatter = new DecimalFormat();
	
	static {
		formatter.setGroupingSize(3);
	}
	
	public abstract List<Contig> getContigs();
}
