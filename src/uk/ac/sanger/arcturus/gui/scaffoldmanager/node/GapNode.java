package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.DefaultMutableTreeNode;

public class GapNode extends DefaultMutableTreeNode {
	private int length;
	private int bridges = 0;
	
	public GapNode(int length) {
		this.length = length;
	}
	
	public int length() {
		return length;
	}
	
	public void incrementBridgeCount() {
		bridges++;
	}
	
	public int getBridgeCount() {
		return bridges;
	}
	
	public String toString() {
		return "Gap of " + length + " bp" +(bridges > 0 ? " with " + bridges + " bridges" : "");
	}
}
