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

import uk.ac.sanger.arcturus.data.Contig;

public class ContigNode extends SequenceNode {
	private Contig contig;
	private boolean forward;
	private boolean current;
	private List<Contig> contigs = null;
	
	public ContigNode(Contig contig, boolean forward, boolean current) {
		this.contig = contig;
		this.forward = forward;
		this.current = current;
	}

	public Contig getContig() {
		return contig;
	}
	
	public boolean isForward() {
		return forward;
	}
	
	public void reverse() {
		forward = !forward;
	}
	
	public boolean isCurrent() {
		return current;
	}
	
	public boolean isMine() {
		return contig.getProject().isMine();
	}
	
	public String toString() {
		return "Contig " + contig.getID() + " (" + formatter.format(contig.getLength()) + " bp, project "
			+ contig.getProject().getName() + ")" + (current ? "" : " *** NOT CURRENT ***");
	}

	public List<Contig> getContigs() {
		if (contigs == null) {
			contigs = new Vector<Contig>(1);
			contigs.add(contig);
		}
		
		return contigs;
	}
}
