package uk.ac.sanger.arcturus.test.contigdisplay;

import java.awt.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ContigFeaturePainter implements FeaturePainter {
    protected Font font = new Font("sansserif", Font.PLAIN, 12);

    public void paintFeature(Graphics2D g, Feature f, Shape s) {
	if (f instanceof ContigFeature) {
	    ContigFeature cf = (ContigFeature)f;

	    Color colour = cf.isForward() ? Color.blue : Color.red;

	    Color oldcolour = g.getColor();

	    g.setColor(colour);

	    g.fill(s);

	    Rectangle rect = s.getBounds();

	    Contig contig = (Contig)cf.getClientObject();

	    String name = contig.getName();

	    g.setColor(Color.black);

	    Font oldfont = g.getFont();

	    g.setFont(font);

	    g.drawString(name, rect.x, rect.y - 2);

	    g.setColor(oldcolour);
	}
    }

    public Shape calculateBoundingShape(Feature f, Transformer t) {
	Point p = f.getPosition();
	Dimension d = f.getSize();

	Rectangle r = new Rectangle(t.worldToView(p), t.worldToView(d));

	return r;
    }
}
