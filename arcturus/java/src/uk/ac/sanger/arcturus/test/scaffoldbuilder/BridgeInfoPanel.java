package scaffoldbuilder;

import java.awt.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class BridgeInfoPanel extends GenericInfoPanel {
    public BridgeInfoPanel(PopupManager myparent) {
	super(myparent);
	lines = new String[2];
	labels =  new String[] {"BRIDGE", "Links:"};
    }

    public void setClientObject(Object o) throws InvalidClientObjectException {
	if (o != null && o instanceof BridgeFeature) {
	    setBridgeFeature((BridgeFeature)o);
	} else
	    throw new InvalidClientObjectException("Expecting a BridgeFeature, got " +
						   ((o == null) ? "null" : o.getClass().getName()));
    }

    protected void setBridgeFeature(BridgeFeature bf) {
	createStrings(bf);
	
	FontMetrics fm = getFontMetrics(boldFont);
	    
	valueOffset = fm.stringWidth(labels[0]) + fm.stringWidth("    ");

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
    
    private void createStrings(BridgeFeature bf) {
	Bridge bridge = (Bridge)bf.getClientObject();

	lines[0] = "";

	lines[1] = "" + bridge.getLinkCount();
    }
}
