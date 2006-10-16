package uk.ac.sanger.arcturus.gui.genericdisplay;

import java.awt.Point;
import java.awt.Dimension;

public interface Transformer {
	public Point viewToWorld(Point p);

	public Point worldToView(Point p);

	public Dimension viewToWorld(Dimension d);

	public Dimension worldToView(Dimension d);
}
