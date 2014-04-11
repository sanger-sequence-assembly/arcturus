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

import java.util.List;
import java.util.Vector;

import javax.swing.tree.MutableTreeNode;

import uk.ac.sanger.arcturus.data.Contig;

public class SuperscaffoldNode extends SequenceNode {
	private int length = 0;
	private int scaffolds = 0;
	private List<Contig> contigs = new Vector<Contig>();
	
	public void add(MutableTreeNode node) {
		if (node instanceof ScaffoldNode) {
			ScaffoldNode snode = (ScaffoldNode)node;
			
			length += snode.length();
			
			if (snode.getContigCount() == 1) {
				ContigNode cnode = (ContigNode)snode.getFirstChild();
				
				if (!snode.isForward())
					cnode.reverse();
					
				contigs.add(cnode.getContig());
				
				super.add(cnode);
			} else {
				scaffolds++;
				
				contigs.addAll(snode.getContigs());
				
				super.add(snode);
			}
		} else
			throw new IllegalArgumentException("Cannot add a " + node.getClass().getName() + " to this node.");
	}
	
	public String toString() {
		return "Superscaffold of " + scaffolds + " scaffolds, " + contigs.size() + " contigs, " + 
			formatter.format(length) + " bp";
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

	public int getScaffoldCount() {
		return scaffolds;
	}
	
	public boolean isDegenerate() {
		return scaffolds == 1 && getChildCount() == 1;
	}

	public List<Contig> getContigs() {
		return contigs;
	}
}
