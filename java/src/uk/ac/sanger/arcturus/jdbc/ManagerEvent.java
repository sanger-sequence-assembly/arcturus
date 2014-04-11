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

package uk.ac.sanger.arcturus.jdbc;

import java.util.EventObject;

public class ManagerEvent extends EventObject {
	/**
	 * 
	 */
	private static final long serialVersionUID = -4589934060008880812L;
	public static final int START = 1;
	public static final int WORKING = 2;
	public static final int END = 3;

	protected String message = null;

	protected int state;
	protected int maxvalue;
	protected int value;

	public ManagerEvent(Object source) {
		super(source);
	}

	public ManagerEvent(Object source, String message, int state, int value,
			int maxvalue) {
		super(source);

		this.message = message;
		this.state = state;
		this.value = value;
		this.maxvalue = maxvalue;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String message) {
		this.message = message;
	}

	public int getState() {
		return state;
	}

	public void setState(int state) {
		this.state = state;
	}

	public int getValue() {
		return value;
	}

	public void setValue(int value) {
		this.value = value;
	}

	public int getMaximumValue() {
		return maxvalue;
	}

	public void setMaximumValue(int maxvalue) {
		this.maxvalue = maxvalue;
	}

	public void begin(String message, int maxvalue) {
		this.message = message;
		this.state = START;
		this.value = 0;
		this.maxvalue = maxvalue;
	}

	public void working(int value) {
		this.state = WORKING;
		this.value = value;
	}

	public void end() {
		this.state = END;
		this.value = maxvalue;
	}
}
