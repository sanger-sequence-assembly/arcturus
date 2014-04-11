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

package uk.ac.sanger.arcturus.readfinder;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Read;

public class ReadFinderEvent {
	public static final int UNKNOWN = -1;
	public static final int START = 0;
	public static final int READ_DOES_NOT_EXIST = 1;
	public static final int READ_IS_FREE = 2;
	public static final int READ_IS_IN_CONTIG = 3;
	public static final int FINISH = 4;
	
	protected int status;
	protected String pattern;
	protected Contig contig;
	protected Read read;
	protected int cstart;
	protected int cfinish;
	protected boolean forward;
	
	public ReadFinderEvent() {
		this.status = UNKNOWN;
	}
	
	public ReadFinderEvent(String pattern, int status) {
		this.pattern = pattern;
		this.status = status;
	}
	
	public int getStatus() {
		return status;
	}
	
	public void setStatus(int status) {
		this.status = status;
	}
	
	public String getPattern() {
		return pattern;
	}
	
	public void setPattern(String pattern) {
		this.pattern = pattern;
	}
	
	public Read getRead() {
		return read;	
	}
	
	public void setRead(Read read) {
		this.read = read;
	}
	
	public void setReadAndStatus(Read read, int status) {
		this.read = read;
		this.status = status;
	}
	
	public Contig getContig() {
		return (status == READ_IS_IN_CONTIG) ? contig : null;
	}
	
	public void setContig(Contig contig) {
		this.contig = contig;
	}
	
	public int getContigStart() {
		return (status == READ_IS_IN_CONTIG) ? cstart : -1;
	}
	
	public int getContigFinish() {
		return (status == READ_IS_IN_CONTIG) ? cfinish : -1;
	}
	
	public boolean isForward() {
		return forward;
	}
	
	public void setContigAndMapping(Read read, Contig contig, int cstart, int cfinish, boolean forward) {
		this.read = read;
		this.contig = contig;
		this.cstart = cstart;
		this.cfinish = cfinish;
		this.forward = forward;
		
		this.status = (contig == null) ? READ_IS_FREE : READ_IS_IN_CONTIG;
	}
}
