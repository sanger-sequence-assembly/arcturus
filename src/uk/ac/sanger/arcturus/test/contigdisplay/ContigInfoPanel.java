package contigdisplay;

import java.awt.*;
import javax.swing.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ContigInfoPanel extends InfoPanel {
    protected String[] lines = new String[3];
    protected Font plainFont = new Font("SansSerif", Font.PLAIN, 14);
    protected Font boldFont = new Font("SansSerif", Font.BOLD, 14);

    protected String[] labels = {"CONTIG", "Length:", "Position:"};

    protected int valueOffset;

    public ContigInfoPanel(PopupManager myparent) {
	super(myparent);

	setBackground(new Color(255, 204, 0));
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

    public void paintComponent(Graphics g) {
	Dimension size = getSize();
	g.setColor(getBackground());
	g.fillRect(0, 0, size.width, size.height);
	
	g.setColor(Color.black);
	
	FontMetrics fm = getFontMetrics(plainFont);
	
	int y0 = fm.getAscent();
	int dy = fm.getHeight();
	
	g.setFont(boldFont);
	
	for (int j = 0; j < lines.length; j++) {
	    int x = 0;
	    int y = y0 + j * dy;
	    g.drawString(labels[j], x, y);
	    g.drawString(lines[j], valueOffset + x, y);
	    if (j == 0) {
		g.setFont(plainFont);
		g.drawLine(0, y + 5, size.width, y + 5);
		y0 += 5;
	    }
	}
    }
}
