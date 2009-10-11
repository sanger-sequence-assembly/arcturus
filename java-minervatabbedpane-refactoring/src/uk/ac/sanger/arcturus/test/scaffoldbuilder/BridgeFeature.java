package uk.ac.sanger.arcturus.test.scaffoldbuilder;

import java.awt.Point;
import java.awt.Dimension;

import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class BridgeFeature implements Feature {
	protected ContigFeature leftContigFeature;
	protected ContigFeature rightContigFeature;
	protected Bridge bridge;
	protected DrawableFeature parent;

	public BridgeFeature(Bridge bridge, ContigFeature leftContigFeature,
			ContigFeature rightContigFeature) {
		this.bridge = bridge;
		this.leftContigFeature = leftContigFeature;
		this.rightContigFeature = rightContigFeature;

		leftContigFeature.addBridgeFeature(this);
		rightContigFeature.addBridgeFeature(this);
	}

	public Point getPosition() {
		return null;
	}

	public void setPosition(Point position) {
	}

	public Dimension getSize() {
		return null;
	}

	public Object getClientObject() {
		return bridge;
	}

	public String toString() {
		return "BridgeFeature[bridge=" + bridge + ", leftcontig="
				+ leftContigFeature.getClientObject() + ", rightcontig="
				+ rightContigFeature.getClientObject() + "]";
	}

	public void setParent(DrawableFeature parent) {
		this.parent = parent;
	}

	public DrawableFeature getParent() {
		return parent;
	}

	public ContigFeature getLeftContigFeature() {
		return leftContigFeature;
	}

	public ContigFeature getRightContigFeature() {
		return rightContigFeature;
	}
}
