// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.genericdisplay;

import java.awt.Shape;
import java.awt.Rectangle;
import java.awt.Point;
import java.awt.Dimension;

public class DrawableFeature implements Transformer {
	public static final int DRAG_NONE = 0;
	public static final int DRAG_X = 1;
	public static final int DRAG_Y = 2;
	public static final int DRAG_XY = 3;

	protected Feature feature;
	protected Shape boundingShape;
	protected FeaturePainter featurePainter;
	protected int dragMode;
	protected Transformer parent;

	public DrawableFeature(Transformer parent, Feature feature,
			FeaturePainter featurePainter, int dragMode) {
		this.parent = parent;
		this.feature = feature;
		this.featurePainter = featurePainter;
		this.dragMode = dragMode;

		feature.setParent(this);
	}

	public DrawableFeature(Transformer parent, Feature feature,
			FeaturePainter featurePainter) {
		this(parent, feature, featurePainter, DRAG_NONE);
	}

	public Feature getFeature() {
		return feature;
	}

	public Shape getBoundingShape() {
		if (boundingShape == null)
			calculateBoundingShape();

		return boundingShape;
	}

	public void calculateBoundingShape() {
		boundingShape = featurePainter.calculateBoundingShape(feature, this);
	}

	public Rectangle getBoundingRectangle() {
		return getBoundingShape().getBounds();
	}

	public Point getPosition() {
		return getBoundingRectangle().getLocation();
	}

	public FeaturePainter getFeaturePainter() {
		return featurePainter;
	}

	public int getDragMode() {
		return dragMode;
	}

	public void setDragMode(int dragMode) {
		if (dragMode < DRAG_NONE || dragMode > DRAG_XY)
			this.dragMode = DRAG_NONE;
		else
			this.dragMode = dragMode;
	}

	public boolean isDraggable() {
		return dragMode != DRAG_NONE;
	}

	public void translate(int dx, int dy) {
		if (boundingShape instanceof Rectangle) {
			Rectangle rect = (Rectangle) boundingShape;
			rect.translate(dx, dy);
		}
	}

	public Transformer getParent() {
		return parent;
	}

	public String toString() {
		return "DrawableFeature[feature=" + feature + ", boundingShape="
				+ boundingShape + ", featurePainter=" + featurePainter
				+ ", dragMode=" + dragMode + "]";
	}

	public Point viewToWorld(Point p) {
		return parent.viewToWorld(p);
	}

	public Point worldToView(Point p) {
		return parent.worldToView(p);
	}

	public Dimension viewToWorld(Dimension d) {
		return parent.viewToWorld(d);
	}

	public Dimension worldToView(Dimension d) {
		return parent.worldToView(d);
	}
}
