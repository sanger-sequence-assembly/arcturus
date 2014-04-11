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

package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.data.*;
import java.util.*;

public class Scaffold {
	protected int totalLength = 0;
	protected int contigCount = 0;
	protected Set bridgeSet = null;
	protected Set contigSet = new HashSet();
	
	public Scaffold(Set bridgeSet) {
		this.bridgeSet = bridgeSet;
		
		for (Iterator iterator = bridgeSet.iterator(); iterator.hasNext();) {
			Bridge bridge = (Bridge) iterator.next();
			
			Contig contiga = bridge.getContigA();
			contigSet.add(contiga);
			
			Contig contigb = bridge.getContigB();
			contigSet.add(contigb);
		}
		
		contigCount = contigSet.size();
		
		for (Iterator iterator = contigSet.iterator(); iterator.hasNext();) {
			Contig contig = (Contig) iterator.next();
			totalLength += contig.getLength();
		}
	}

	public int getContigCount() {
		return contigCount;
	}
	
	public int getTotalLength() {
		return totalLength;
	}
	
	public Set getContigSet() {
		return new HashSet(contigSet);
	}
	
	public boolean containsContig(Contig contig) {
		return contigSet.contains(contig);
	}
	
	public String toString() {
		return "Scaffold[contigs=" + contigCount + ", total length=" + totalLength + "]";
	}
}
