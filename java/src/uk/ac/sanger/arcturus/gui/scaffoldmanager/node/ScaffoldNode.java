package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.MutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

public class ScaffoldNode extends DefaultMutableTreeNode {
	private MutableTreeNode lastNode = null;
	private int length = 0;
	private int contigs = 0;
	private int myContigs = 0;
	private int reads = 0;
	private boolean forward;
	
	private Map<Project, Integer> projectWeightByLength = new HashMap<Project, Integer>();

	public ScaffoldNode(boolean forward) {
		this.forward = forward;
	}
	
	public void add(MutableTreeNode node) {
		if (node instanceof ContigNode) {
			if (lastNode == null || lastNode instanceof GapNode) {
				addContigNode((ContigNode)node);
			} else
				throw new IllegalArgumentException("Cannot add a ContigNode at this point.");
		} else if (node instanceof GapNode) {
			if (lastNode != null && lastNode instanceof ContigNode) {
				addGapNode((GapNode)node);
			} else
				throw new IllegalArgumentException("Cannot add a GapNode at this point.");
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");

		super.add(node);
		
		lastNode = node;
	}
	
	private void addContigNode(ContigNode node) {
		Contig contig = node.getContig();
		Project project = contig.getProject();
		
		int contigLength = contig.getLength();
		int contigReads = contig.getReadCount();
		
		length += contigLength;
		reads += contigReads;
		
		contigs++;
		
		if (project.isMine())
			myContigs++;
		
		incrementMapEntry(projectWeightByLength, project, contigLength);
	}
	
	private void incrementMapEntry(Map<Project, Integer> map, Project project, int delta) {
		Integer oldValue = map.get(project);
		
		int newValue = (oldValue == null) ? delta : oldValue + delta;
		
		map.put(project, newValue);
	}
	
	private void addGapNode(GapNode node) {
		length += node.length();
	}
	
	public int length() {
		return length;
	}
	
	public int getContigCount() {
		return contigs;
	}
	
	public int getMyContigCount() {
		return myContigs;
	}
	
	public boolean hasMyContigs() {
		return myContigs > 0;
	}
	
	public boolean isForward() {
		return forward;
	}
		
	private class ProjectAndValue implements Comparable<ProjectAndValue> {
		private Project project;
		private int value;
		
		public ProjectAndValue(Map.Entry<Project, Integer> entry) {
			this.project = entry.getKey();
			this.value = entry.getValue();
		}

		public int compareTo(ProjectAndValue that) {
			return that.value - this.value;
		}
		
		public Project getProject() {
			return project;
		}
		
		public int getValue() {
			return value;
		}
	}
	
	private String getProjectWeightsString() {
		StringBuilder sb = new StringBuilder();
		
		sb.append(" [");
		
		ProjectAndValue[] array = new ProjectAndValue[projectWeightByLength.size()];
		
		int i = 0;
		
		for (Map.Entry<Project, Integer> entry : projectWeightByLength.entrySet())
			array[i++] = new ProjectAndValue(entry);
			
		Arrays.sort(array);
		
		for (i = 0; i < array.length; i++) {
			Project project = array[i].getProject();
			int value = array[i].getValue();
			
			if (i > 0)
				sb.append(", ");
			
			sb.append(project.getName() + " : " + value + " bp");
		}
		
		sb.append("]");
		
		return sb.toString();
	}
	
	private String cachedToString = null;

	public String toString() {
		if (cachedToString == null)
			cachedToString =  "Scaffold of " + contigs + " contigs, " + length + " bp" + getProjectWeightsString();
		
		return cachedToString;
	}
}
