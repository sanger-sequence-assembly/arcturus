package uk.ac.sanger.arcturus.test.scaffoldbuilder;

import java.awt.Point;
import java.awt.Dimension;
import java.util.Set;
import java.util.HashSet;
import java.util.Iterator;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ContigFeature implements Feature {
    protected Contig contig;
    protected Point position;
    protected Dimension size;
    protected boolean forward;
    protected Set bridgeSet = new HashSet();
    protected DrawableFeature parent;

    public ContigFeature(Contig contig, Point position, boolean forward) {
	this.contig = contig;
	this.position = position;
	this.forward = forward;
	this.size = new Dimension(contig.getLength(), 20);
    }

    public Point getPosition() { return position; }

    public void setPosition(Point position) {
	this.position = position;
	recalculateBridgeFeatures();
    }

    public Dimension getSize() { return size; }

    public Object getClientObject() { return contig; }

    public boolean isForward() { return forward; }

    public String toString() {
	return "ContigFeature[contig=" + contig + ", position=" + position +
	    ", size=" + size + ", forward=" + forward + "]";
    }

    public void addBridgeFeature(BridgeFeature bf) {
	bridgeSet.add(bf);
    }

    private void recalculateBridgeFeatures() {
	for (Iterator iter = bridgeSet.iterator(); iter.hasNext();) {
	    BridgeFeature bf = (BridgeFeature)iter.next();

	    bf.getParent().calculateBoundingShape();
	}
    }

    public void setParent(DrawableFeature parent) {
	this.parent = parent;
    }

    public DrawableFeature getParent() { return parent; }

    public Point getLeftEnd() {
	return new Point(position.x, position.y + size.height/2);
    }

    public Point getRightEnd() {
	return new Point(position.x + size.width, position.y + size.height/2);
    }
}
