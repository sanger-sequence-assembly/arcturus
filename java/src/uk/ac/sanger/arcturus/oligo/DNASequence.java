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

public class DNASequence {
	public static final int READ = 1;
	public static final int CONTIG = 2;
	
	private int type;
	private int ID;
	private String name;
	private int sequenceLength;
	private String projectName;
	
	private DNASequence(int type, int ID, String name, int sequenceLength, String projectName) {
		this.type = type;
		this.ID = ID;
		this.name = name;
		this.sequenceLength = sequenceLength;
		this.projectName = projectName;
	}
	
	public static DNASequence createContigInstance(int ID, String name, int sequenceLength, String projectName) {
		return new DNASequence(CONTIG, ID, name, sequenceLength, projectName);
	}
	
	public static DNASequence createReadInstance(int ID, String name) {
		return new DNASequence(READ, ID, name, 0, null);
	}
	
	public int getType() {
		return type;
	}
	
	public boolean isContig() {
		return type == CONTIG;
	}
	
	public boolean isRead() {
		return type == READ;
	}
	
	public int getID() {
		return ID;
	}
	
	public String getName() {
		return name;
	}
	
	public int getSequenceLength() {
		return sequenceLength;
	}
	
	public String getProjectName() {
		return projectName;
	}
	
	public String toString() {
		switch (type) {
			case CONTIG:
				return "Contig " + ID + " (" + name + ", " + sequenceLength + " bp, in " + projectName + ")";
				
			case READ:
				return "Read " + name;
				
			default:
				return "DNASequence object of unknown origin";
		}
	}
}
