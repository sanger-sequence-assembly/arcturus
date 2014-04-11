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

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.ClipboardOwner;
import java.awt.datatransfer.StringSelection;
import java.awt.datatransfer.Transferable;

public class BridgeInfoPanel extends GenericInfoPanel implements ClipboardOwner {
	public BridgeInfoPanel(PopupManager myparent) {
		super(myparent);
		labels = null;
		valueOffset = 0;
	}

	public void setClientObject(Object o) throws InvalidClientObjectException {
		if (o != null && o instanceof BridgeFeature) {
			setBridgeFeature((BridgeFeature) o);
		} else
			throw new InvalidClientObjectException(
					"Expecting a BridgeFeature, got "
							+ ((o == null) ? "null" : o.getClass().getName()));
	}

	protected void setBridgeFeature(BridgeFeature bf) {
		createStrings(bf);

		FontMetrics fm = getFontMetrics(boldFont);

		int txtheight = lines.length * fm.getHeight();

		int txtwidth = 0;

		for (int j = 0; j < lines.length; j++) {
			int sw = fm.stringWidth(lines[j]);
			if (sw > txtwidth)
				txtwidth = sw;
			if (j == 0)
				fm = getFontMetrics(plainFont);
		}

		setPreferredSize(new Dimension(txtwidth, txtheight + 5));
	}

	private void createStrings(BridgeFeature bf) {
		Bridge bridge = (Bridge) bf.getClientObject();

		Template[] templates = bridge.getTemplates();

		lines = new String[3 + templates.length];

		lines[0] = "BRIDGE";

		GapSize gapsize = bridge.getGapSize();

		lines[1] = "Gap Size: " + gapsize.getMinimum() + " - "
				+ gapsize.getMaximum();

		lines[2] = "SUB-CLONES:";

		for (int k = 0; k < templates.length; k++)
			lines[k + 3] = templates[k].getName();
		
		copyToClipboard(bf);
	}
	
	protected void copyToClipboard(BridgeFeature bf) {
		StringBuffer sb = new StringBuffer();
		
		int leftContigID = ((Contig)bf.getLeftContigFeature().getClientObject()).getID();
		int rightContigID = ((Contig)bf.getRightContigFeature().getClientObject()).getID();
		
		sb.append("BRIDGE between contig " + leftContigID + " and " + rightContigID + "\n");
		
		for (int i = 1; i < lines.length; i++) {
			sb.append(lines[i]);
			sb.append("\n");
		}
		
		String str = sb.toString();
		
		StringSelection contents = new StringSelection(str);

		Toolkit.getDefaultToolkit().getSystemClipboard().setContents(contents,
				this);
	}
	
	public void lostOwnership(Clipboard clipboard, Transferable contents) {};
}
