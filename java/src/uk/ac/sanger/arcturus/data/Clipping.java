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

/**
 * An object which represents sequence clipping.
 */

public class Clipping {
	public final static int QUAL = 1;
	public final static int SVEC = 2;
	public final static int CVEC = 3;

	protected int type;
	protected String name;
	protected int left;
	protected int right;

	public Clipping(int type, String name, int left, int right) {
		this.type = type;
		this.name = name;
		this.left = left;
		this.right = right;
	}

	public Clipping(int type, int left, int right) {
		this(type, null, left, right);
	}

	public int getType() {
		return type;
	}

	public String getName() {
		return name;
	}

	public int getLeft() {
		return type;
	}

	public int getRight() {
		return right;
	}

	public String toString() {
		String strtype;

		switch (type) {
			case QUAL:
				strtype = "QUAL";
				break;
			case SVEC:
				strtype = "SVEC";
				break;
			case CVEC:
				strtype = "CVEC";
				break;
			default:
				strtype = "UNKNOWN";
				break;
		}

		return getClass().getName() + "[type=" + strtype + ", name=" + name
				+ ", left=" + left + ", right=" + right + "]";
	}

	public String toCAFString() {
		String cafstring = null;

		switch (type) {
			case QUAL:
				cafstring = "Clipping QUAL";
				break;
			case SVEC:
				cafstring = "Seq_vec SVEC";
				break;
			case CVEC:
				cafstring = "Clone_vec CVEC";
				break;
			default:
				return null;
		}

		cafstring += " " + left + " " + right;

		if (name != null)
			cafstring += " \"" + name + "\"";

		return cafstring;
	}

	public boolean equals(Object obj) {
		if (!(obj instanceof Clipping))
			return false;

		Clipping that = (Clipping) obj;

		if (this.type != that.type || this.left != that.left
				|| this.right != that.right)
			return false;

		if (this.name != null && that.name != null
				&& !this.name.equalsIgnoreCase(that.name))
			return false;

		if (!(this.name == null && that.name == null))
			return false;

		return true;
	}
}
