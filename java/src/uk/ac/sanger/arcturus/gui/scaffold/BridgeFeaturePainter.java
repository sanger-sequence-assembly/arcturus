package uk.ac.sanger.arcturus.gui.scaffold;

import java.awt.*;
import java.awt.geom.*;

import uk.ac.sanger.arcturus.scaffold.*;
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

			ContigFeature cfa = bf.getLeftContigFeature();
			ContigFeature cfb = bf.getRightContigFeature();

			Bridge bridge = (Bridge) bf.getClientObject();

			int dx = 20;

			int enda = ((bridge.getEndA() == Bridge.RIGHT) ^ cfa.isForward()) ? Bridge.LEFT
					: Bridge.RIGHT;

			Point pa = (enda == Bridge.LEFT) ? cfa.getLeftEnd() : cfa
					.getRightEnd();

			int dxa = (enda == Bridge.LEFT) ? -dx : dx;

			int endb = ((bridge.getEndB() == Bridge.RIGHT) ^ cfb.isForward()) ? Bridge.LEFT
					: Bridge.RIGHT;

			Point pb = ((bridge.getEndB() == Bridge.RIGHT) ^ cfb.isForward()) ? cfb
					.getLeftEnd()
					: cfb.getRightEnd();

			int dxb = (endb == Bridge.LEFT) ? -dx : dx;

			pa = t.worldToView(pa);
			pb = t.worldToView(pb);

			int links = ((Bridge) bf.getClientObject()).getLinkCount();

			if (links > 5)
				links = 5;

			Shape path = new CubicCurve2D.Double((double) pa.x, (double) pa.y,
					(double) (pa.x + dxa), (double) pa.y,
					(double) (pb.x + dxb), (double) pb.y, (double) pb.x,
					(double) pb.y);

			Stroke stroke = new BasicStroke((float) links);

			Shape outline = stroke.createStrokedShape(path);

			return outline;
		} else
			return null;
	}
}
