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

import javax.swing.AbstractAction;
import javax.swing.ImageIcon;
import javax.swing.KeyStroke;

public abstract class MinervaAbstractAction extends AbstractAction {
	public MinervaAbstractAction(String text, ImageIcon icon,
			String description, Integer mnemonic, KeyStroke accelerator) {
		super(text, icon);

		if (description != null)
			putValue(SHORT_DESCRIPTION, description);

		if (mnemonic != null)
			putValue(MNEMONIC_KEY, mnemonic);

		if (accelerator != null)
			putValue(ACCELERATOR_KEY, accelerator);
	}	
}
