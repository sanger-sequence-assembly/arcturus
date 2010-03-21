package uk.ac.sanger.arcturus.gui.organismtree;

import java.util.Comparator;

public class OrganismTreeNodeComparator  implements Comparator<OrganismTreeNode> {
	public int compare(OrganismTreeNode node1, OrganismTreeNode node2) {
		if (node1 instanceof InstanceNode && node2 instanceof OrganismNode)
			return -1;
		else if (node1 instanceof OrganismNode
				&& node2 instanceof InstanceNode)
			return 1;
		else
			return node1.getName().compareTo(node2.getName());
	}

}
