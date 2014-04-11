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

package uk.ac.sanger.arcturus.scaffold;

public class ReadMapping {
	protected int read_id;
	protected int cstart;
	protected int cfinish;
	protected boolean forward;

	public ReadMapping(int read_id, int cstart, int cfinish, boolean forward) {
		this.read_id = read_id;
		this.cstart = cstart;
		this.cfinish = cfinish;
		this.forward = forward;
	}

	public int getReadID() {
		return read_id;
	}

	public int getContigStart() {
		return cstart;
	}

	public int getContigFinish() {
		return cfinish;
	}

	public boolean isForward() {
		return forward;
	}

	public boolean equals(Object obj) {
		if (obj instanceof ReadMapping) {
			ReadMapping that = (ReadMapping) obj;

			return (this.read_id == that.read_id)
					&& (this.cstart == that.cstart)
					&& (this.cfinish == that.cfinish)
					&& (this.forward == that.forward);
		} else
			return false;
	}

	public String toString() {
		return "ReadMapping[read_id=" + read_id + ", cstart=" + cstart
				+ " cfinish=" + cfinish + ", "
				+ (forward ? "forward" : "reverse") + "]";
	}
}
