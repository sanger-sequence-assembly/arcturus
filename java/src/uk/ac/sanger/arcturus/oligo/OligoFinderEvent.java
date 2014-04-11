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
	public enum Type { UNKNOWN, START_CONTIGS, START_READS, START_SEQUENCE, FOUND_MATCH, FINISH_SEQUENCE, FINISH_CONTIGS, FINISH_READS,
		ENUMERATING_FREE_READS, FINISH, MESSAGE, EXCEPTION
	}
		
	private OligoFinder source;
	private Type type = Type.UNKNOWN;
	private Oligo oligo;
	private DNASequence sequence;
	private int value;
	private boolean forward;
	private String message;
	private Exception exception;
	
	public OligoFinderEvent(OligoFinder source) {
		this.source = source;
	}
	
	public void setEvent(Type type, Oligo oligo, DNASequence sequence, int value, boolean forward) {
		this.type = type;
		this.oligo = oligo;
		this.value = value;
		this.forward = forward;
		this.sequence = sequence;
	}
	
	public void setEvent(Type type, Oligo oligo, int value, boolean forward) {
		this.type = type;
		this.oligo = oligo;
		this.value = value;
		this.forward = forward;
	}
	
	public void setEvent(Type type, String message) {
		this.type = type;
		this.message = message;
	}
	
	public void setException(Exception exception) {
		this.exception = exception;
	}

	public OligoFinder getSource() { return source; }
	
	public Type getType() { return type; }
	
	public Oligo getOligo() { return oligo; }
	
	public DNASequence getDNASequence() {
		return sequence;
	}
	
	protected void setDNASequence(DNASequence sequence) {
		this.sequence = sequence;
	}
	
	public int getValue() { return value; }
	
	public boolean isForward() { return forward; } 
	
	public String getMessage() {
		return message;
	}
	
	public Exception getException() {
		return exception;
	}
}
