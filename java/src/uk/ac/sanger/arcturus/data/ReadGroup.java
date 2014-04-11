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

import java.util.Vector;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ReadGroup extends Core {

	public ReadGroup( int read_group_line_id, int import_id, String tag_name, String tag_value) {
		
		this.read_group_line_id = read_group_line_id;
		this.import_id = import_id;
		this.tag_name = tag_name;
		this.tag_value = tag_value;
	}

	protected int read_group_line_id  = 0;
	protected int import_id = 0;
	
	protected String tag_name = null;
	protected String tag_value = null;

	public int getImport_id() {
		return import_id;
	}

	public void setImport_id(int import_id) {
		this.import_id = import_id;
	}

	public int getRead_group_line_id() {
		return read_group_line_id;
	}

	public void setRead_group_line_id(int read_group_line_id) {
		this.read_group_line_id = read_group_line_id;
	}

	public String getTag_name() {
		return tag_name;
	}

	public void setTag_name(String tag_name) {
		this.tag_name = tag_name;
	}

	public String getTag_value() {
		return tag_value;
	}

	public void setTag_value(String tag_value) {
		this.tag_value = tag_value;
	}

}
