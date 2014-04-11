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

package uk.ac.sanger.arcturus.oligo;

public class OligoMatch {
	private Oligo oligo;
	private DNASequence sequence;
	private int offset;
	private boolean forward;
	
	public OligoMatch(Oligo oligo, DNASequence sequence, int offset, boolean forward) {
		this.oligo = oligo;
		this.sequence = sequence;
		this.offset = offset;
		this.forward = forward;
	}
	
	public Oligo getOligo() { return oligo; }
	
	public DNASequence getDNASequence() { return sequence; }
	
	public int getOffset() { return offset; }
	
	public boolean isForward() { return forward; }
}
