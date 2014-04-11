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

package uk.ac.sanger.arcturus.gui.genericdisplay;

public class DisplayMode {
	public static final int ZOOM_IN = 1;
	public static final int ZOOM_OUT = 2;
	public static final int DRAG = 3;
	public static final int INFO = 4;

	protected final int mode;

	public DisplayMode(int mode) {
		this.mode = mode;
	}

	public int getMode() {
		return mode;
	}

	public String toString() {
		switch (mode) {
			case ZOOM_IN:
				return "Zoom in";
			case ZOOM_OUT:
				return "Zoom out";
			case DRAG:
				return "Drag objects";
			case INFO:
				return "Show object info";
			default:
				return "(Nothing)";
		}
	}
}
