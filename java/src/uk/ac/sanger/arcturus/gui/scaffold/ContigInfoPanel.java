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

package uk.ac.sanger.arcturus.gui.scaffold;

import java.awt.*;
import java.text.SimpleDateFormat;
import java.text.DecimalFormat;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ContigInfoPanel extends GenericInfoPanel {
	/**
	 * 
	 */
	private static final long serialVersionUID = 2607529098192287436L;
	protected SimpleDateFormat dateformat = new SimpleDateFormat(
			"yyyy MMM dd HH:mm");
	protected DecimalFormat decimalformat = new DecimalFormat();

	public ContigInfoPanel(PopupManager myparent) {
		super(myparent);
		labels = new String[] { "CONTIG", "Name:", "Length:", "Reads:",
				"Created:", "Project:" };
		lines = new String[labels.length];
	}

	public void setClientObject(Object o) throws InvalidClientObjectException {
		if (o != null && o instanceof ContigFeature) {
			setContigFeature((ContigFeature) o);
		} else
			throw new InvalidClientObjectException(
					"Expecting a ContigFeature, got "
							+ ((o == null) ? "null" : o.getClass().getName()));
	}

	protected void setContigFeature(ContigFeature cf) {
		createStrings(cf);

		FontMetrics fm = getFontMetrics(boldFont);

		valueOffset = 0;

		for (int i = 1; i < labels.length; i++) {
			int k = fm.stringWidth(labels[i]);
			if (k > valueOffset)
				valueOffset = k;
		}

		valueOffset += fm.stringWidth("    ");

		int txtheight = lines.length * fm.getHeight();

		int txtwidth = 0;

		for (int j = 0; j < lines.length; j++) {
			int sw = fm.stringWidth(lines[j]);
			if (sw > txtwidth)
				txtwidth = sw;
			if (j == 0)
				fm = getFontMetrics(boldFont);
		}

		setPreferredSize(new Dimension(valueOffset + txtwidth, txtheight + 5));
	}

	private void createStrings(ContigFeature cf) {
		Contig contig = (Contig) cf.getClientObject();

		lines[0] = "" + contig.getID();

		lines[1] = contig.getName();

		lines[2] = decimalformat.format(contig.getLength());

		lines[3] = decimalformat.format(contig.getReadCount());

		lines[4] = dateformat.format(contig.getCreated());

		Project project = contig.getProject();

		lines[5] = (project == null) ? "(unknown)" : project.getName();
	}
}
