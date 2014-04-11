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

package uk.ac.sanger.arcturus.gui;

import javax.swing.table.*;
import java.text.*;

public class ISODateRenderer extends DefaultTableCellRenderer {
	/**
	 * 
	 */
	private static final long serialVersionUID = -4674507936665605972L;
	private final DateFormat formatter = new SimpleDateFormat(
			"yyyy MMM dd HH:mm");

	public ISODateRenderer() {
		super();

		setHorizontalAlignment(DefaultTableCellRenderer.CENTER);
	}

	public void setValue(Object value) {
		setText((value == null) ? "" : formatter.format(value));
	}
}
