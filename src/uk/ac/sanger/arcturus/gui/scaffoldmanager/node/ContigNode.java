package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.DefaultMutableTreeNode;

public class ContigNode extends DefaultMutableTreeNode {
	private int ID;
	private int projectID;
	private int length;
	private boolean forward;
	
	public ContigNode(int ID, int projectID, int length, boolean forward) {
		this.ID = ID;
		this.projectID = projectID;
		this.length = length;
		this.forward = forward;
	}
	
	public int length() {
		return length;
	}
	
	public boolean isForward() {
		return forward;
	}
	
	public void reverse() {
		forward = !forward;
	}
	
	public String toString() {
		return "Contig " + ID + " (" + length + " bp, project " + projectID + ")";
	}
}
