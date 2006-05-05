package uk.ac.sanger.arcturus.gui.genericdisplay;

import java.awt.Graphics2D;
import java.awt.Shape;

public interface FeaturePainter {
    public void paintFeature(Graphics2D g, Feature f, Shape s);

    public Shape calculateBoundingShape(Feature f, Transformer t);
}
