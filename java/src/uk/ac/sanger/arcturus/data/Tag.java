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

package uk.ac.sanger.arcturus.data;

public class Tag extends Core {
	protected int start;
	protected int end;
	protected String type;
	protected String comment;

	public Tag(String type, int start, int end, String comment) {
		this.start = start;
		this.end = end;
		this.type = type;
		this.comment = comment;
	}

	public int getStart() {
		return start;
	}

	public int getEnd() {
		return end;
	}

	public String getType() {
		return type;
	}

	public String getComment() {
		return comment;
	}

	public String toCAFString() {
		return "Tag " + type + " " + start + " " + end
				+ (comment == null ? "" : " \"" + comment + "\"");
	}
}
