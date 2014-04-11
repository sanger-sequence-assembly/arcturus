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

package uk.ac.sanger.arcturus.consistencychecker;

class Test {
	
	
	private final String description;
	private final String query;
	private final String format;
	private final boolean critical;
	
	public Test(String description, String query, String format, boolean critical) {
		this.description = description;
		this.query = query;
		this.format = format;
		this.critical = critical;
	}
	
	public String getDescription() {
		return description;
	}
	
	public String getQuery() {
		return query;
	}
	
	public String getFormat() {
		return format;
	}
	
	public boolean isCritical() {
		return critical;
	}
	
	public String toString() {
		return "Test[description=\"" + description +
			"\", query=\"" + query +
			"\", format=\"" + format + "\"" +
			", critical=" + (critical ? "YES" : "NO") +
			"]";
	}

}