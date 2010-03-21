package uk.ac.sanger.arcturus.test.contigdisplay;

import java.awt.*;
import java.awt.geom.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class BridgeFeaturePainter implements FeaturePainter {

	public void paintFeature(Graphics2D g, Feature f, Shape s) {
		Color oldcolour = g.getColor();

		g.setColor(Color.black);

		g.fill(s);

		g.setColor(oldcolour);
	}

	public Shape calculateBoundingShape(Feature f, Transformer t) {
		if (f instanceof BridgeFeature) {
			BridgeFeature bf = (BridgeFeature) f;

			Point l = bf.getLeftContigFeature().getRightEnd();
			Point r = bf.getRightContigFeature().getLeftEnd();

			l = t.worldToView(l);
			r = t.worldToView(r);

			int links = ((Bridge) bf.getClientObject()).getScore();

			if (links > 5)
				links = 5;

			int dx = 20;

			Shape path = new CubicCurve2D.Double((double) l.x, (double) l.y,
					(double) (l.x + dx), (double) l.y, (double) (r.x - dx),
					(double) r.y, (double) r.x, (double) r.y);

			Stroke stroke = new BasicStroke((float) links);

			Shape outline = stroke.createStrokedShape(path);

			return outline;
		} else
			return null;
	}
}
