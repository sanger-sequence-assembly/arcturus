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
