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

package uk.ac.sanger.arcturus.gui.scaffoldmanager.node;

import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.MutableTreeNode;

public class AssemblyNode extends DefaultMutableTreeNode {
	private final String caption;
	
	public AssemblyNode(String created) {
		super();
		caption = "Assembly (created " + created + ")";
	}
	
	public void add(MutableTreeNode node) {
		if (node instanceof SuperscaffoldNode) {
			SuperscaffoldNode ssnode = (SuperscaffoldNode)node;
			
			if (ssnode.isDegenerate())
				super.add((MutableTreeNode)(ssnode.getFirstChild()));
			else
				super.add(ssnode);
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");
	}
	
	public String toString() {
		return caption;
	}
}
