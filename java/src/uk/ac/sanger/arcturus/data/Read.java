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

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class Read extends Core {
	private int flags = 0;
	
	public Read(String name) {
		this(name, 0);
	}
	
	public Read(String name, int flags) {
		super(name);
		
		setFlags(flags);
	}
	
	public Read(String name, int ID, ArcturusDatabase adb) {
		super(name, ID, adb);
	}

	public Read(int id, String name, int flags) {
		super(name, id, null);
		
		setFlags(flags);
	}

	public void setFlags(int flags) {
		this.flags = flags;
	}
	
	public int getFlags() {
		return flags;
	}
	
	public String getUniqueName() {
		return flags == 0 ? name : name + "/" + flags;
	}
}
