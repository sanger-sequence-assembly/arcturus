package uk.ac.sanger.arcturus.gui.genericdisplay;

import java.awt.Point;
import java.awt.Dimension;

public interface Feature {
    public Point getPosition();
    public void setPosition(Point p);
    public Dimension getSize();
    public Object getClientObject();
    public void setParent(DrawableFeature df);
    public DrawableFeature getParent();
}
