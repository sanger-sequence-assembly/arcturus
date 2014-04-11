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
