package scaffoldbuilder;

import java.awt.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ContigInfoPanel extends GenericInfoPanel {
    public ContigInfoPanel(PopupManager myparent) {
	super(myparent);
	lines = new String[3];
	labels = new String[] {"CONTIG", "Length:", "Position:"};
    }

    public void setClientObject(Object o) throws InvalidClientObjectException {
	if (o != null && o instanceof ContigFeature) {
	    setContigFeature((ContigFeature)o);
	} else
	    throw new InvalidClientObjectException("Expecting a ContigFeature, got " +
						   ((o == null) ? "null" : o.getClass().getName()));
    }

    protected void setContigFeature(ContigFeature cf) {
	createStrings(cf);
	
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
    
    private void createStrings(ContigFeature cf) {
	Contig contig = (Contig)cf.getClientObject();

	lines[0] = contig.getName();

	lines[1] = "" + contig.getLength();

	Point p = cf.getPosition();

	lines[2] = "" + p.x + ", " + p.y;
    }
}
