package scaffoldbuilder;

import java.awt.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class BridgeInfoPanel extends GenericInfoPanel {
    public BridgeInfoPanel(PopupManager myparent) {
	super(myparent);
	labels = null;	    
	valueOffset = 0;
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
	Bridge bridge = (Bridge)bf.getClientObject();

	Template[] templates = bridge.getTemplates();

	lines = new String[1 + templates.length];

	lines[0] = "BRIDGE";

	for (int k = 0; k < templates.length; k++)
	    lines[k+1] = templates[k].getName();
    }
}
