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

package uk.ac.sanger.arcturus.repository;

import java.util.Date;

public class Repository {
	private String name;
	
	private String path = null;
	private Date date = null;
	private boolean online = false;
	private boolean writable = false;
	private long expires = 0L;
	
	public Repository(String name) {
		this.name = name;
	}
	
	public String getName() {
		return name;
	}
	
	public void setPath(String path) {
		this.path = path;
	}
	
	public String getPath() {
		return path;
	}
	
	public void setDate(Date date) {
		this.date = date;
	}
	
	public Date getDate() {
		return date;
	}
	
	public void setOnline(boolean online) {
		this.online = online;
	}
	
	public boolean isOnline() {
		return online;
	}
	
	public void setWritable(boolean writable) {
		this.writable = writable;
	}
	
	public boolean isWritable() {
		return writable;
	}
	
	public void setExpires(long expires) {
		this.expires = expires;
	}
	
	public boolean isExpired() {
		return System.currentTimeMillis() > expires;
	}
	
	public String toString() {
		return "Repository[name=\"" + name + "\", path=\"" + path +
			"\", date=\"" + date + "\", " + (online ? "ONLINE" : "OFFLINE") +
			", " + (writable ? "R/W" : "R/O") + "]";
	}
}
