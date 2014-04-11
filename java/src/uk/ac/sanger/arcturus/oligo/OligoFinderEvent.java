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

public class OligoFinderEvent {
	public static final int UNKNOWN = 0;
	public static final int START_CONTIGS = 1;
	public static final int START_READS = 2;
	public static final int START_SEQUENCE = 3;
	public static final int FOUND_MATCH = 4;
	public static final int FINISH_SEQUENCE = 5;
	public static final int FINISH_CONTIGS = 6;
	public static final int FINISH_READS = 7; 
	public static final int ENUMERATING_FREE_READS = 8;
	public static final int FINISH = 9;
	
	private OligoFinder source;
	private int type = UNKNOWN;
	private Oligo oligo;
	private DNASequence sequence;
	private int value;
	private boolean forward;
	
	public OligoFinderEvent(OligoFinder source) {
		this.source = source;
	}
	
	public void setEvent(int type, Oligo oligo, DNASequence sequence, int value, boolean forward) {
		this.type = type;
		this.oligo = oligo;
		this.value = value;
		this.forward = forward;
		this.sequence = sequence;
	}
	
	public void setEvent(int type, Oligo oligo, int value, boolean forward) {
		this.type = type;
		this.oligo = oligo;
		this.value = value;
		this.forward = forward;
	}

	public OligoFinder getSource() { return source; }
	
	public int getType() { return type; }
	
	public Oligo getOligo() { return oligo; }
	
	public DNASequence getDNASequence() {
		return sequence;
	}
	
	protected void setDNASequence(DNASequence sequence) {
		this.sequence = sequence;
	}
	
	public int getValue() { return value; }
	
	public boolean isForward() { return forward; } 
}
