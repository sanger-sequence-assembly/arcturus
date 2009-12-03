package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Vector;

import javax.swing.tree.MutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

public class ScaffoldNode extends SequenceNode {
	private MutableTreeNode lastNode = null;
	private int length = 0;
	private int reads = 0;
	private boolean forward;
	private List<Contig> contigs = new Vector<Contig>();
	
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
		
		contigs.add(node.getContig());
		
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
		return contigs.size();
	}
	
	public boolean hasMyContigs() {
		for (Contig contig : contigs)
			if (contig.getProject().isMine())
				return true;
		
		return false;
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
	
	private void calculateProjectWeights() {
		projectWeightByLength.clear();
		
		for (Contig contig : contigs) {
			Project project = contig.getProject();
			int contigLength = contig.getLength();
			
			incrementMapEntry(projectWeightByLength, project, contigLength);
		}
	}
	
	private String getProjectWeightsString() {
		calculateProjectWeights();
		
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
			
			sb.append(project.getName() + " : " + formatter.format(value) + " bp");
		}
		
		sb.append("]");
		
		return sb.toString();
	}

	public String toString() {
		return "Scaffold of " + contigs.size() + " contigs, " +
			formatter.format(length) + " bp" + getProjectWeightsString();		
	}

	public List<Contig> getContigs() {
		return contigs;
	}
}
