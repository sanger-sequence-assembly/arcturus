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
