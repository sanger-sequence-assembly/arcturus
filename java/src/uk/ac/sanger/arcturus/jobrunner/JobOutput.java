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

package uk.ac.sanger.arcturus.jobrunner;

public class JobOutput {
	public static final int STDOUT = 1;
	public static final int STDERR = 2;
	public static final int STATUS = 3;

	protected int type;
	protected String text;

	public JobOutput(int type, String text) {
		if (type != STDOUT && type != STDERR && type != STATUS)
			throw new IllegalArgumentException("Illegal type code: " + type);
		
		this.type = type;
		this.text = text;
	}

	public int getType() {
		return type;
	}
	
	public String getText() {
		return text;
	}
	
	public String getTypeName() {
		switch (type) {
		case STDOUT:
			return "STDOUT";
			
		case STDERR:
			return "STDERR";
			
		case STATUS:
			return "STATUS";
			
		default:
			return null;
		}
	}
	
	public String toString() {
		return "JobOutput[type=" + getTypeName() + ", text=" + text + "]";  
	}
}
