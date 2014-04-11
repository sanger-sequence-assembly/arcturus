// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
