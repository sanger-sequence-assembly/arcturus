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

package uk.ac.sanger.arcturus.tag;

public class Tag {
	public static final int FORWARD = 1;
	public static final int REVERSE = 2;
	public static final int UNKNOWN = 3;

	protected int id;
	protected int contig_id;
	protected int parent_id;
	protected int tag_id;
	protected int cstart;
	protected int cfinal;
	protected int strand;
	protected String tagtype;
	protected String tagcomment;

	public void setStrand(String s) {
		if (s == null)
			strand = UNKNOWN;
		else if (s.equalsIgnoreCase("F"))
			strand = FORWARD;
		else if (s.equalsIgnoreCase("R"))
			strand = REVERSE;
		else
			strand = UNKNOWN;
	}
	
	public String getStrandAsString() {
		switch (strand) {
			case FORWARD:
				return "F";
				
			case REVERSE:
				return "R";
				
			default:
				return "U";
		}
	}

	public String toString() {
		return "Tag[id=" + id + ", parent_id=" + parent_id + ", contig_id="
				+ contig_id + ", tag_id=" + tag_id + ", cstart=" + cstart
				+ ", cfinal=" + cfinal + "]";
	}
}
