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

package uk.ac.sanger.arcturus.gui.scaffold;

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
	protected boolean seed;
	protected Set bridgeSet = new HashSet();
	protected DrawableFeature parent;

	public ContigFeature(Contig contig, Point position, boolean forward, boolean seed) {
		this.contig = contig;
		this.position = position;
		this.forward = forward;
		this.seed = seed;
		this.size = new Dimension(contig.getLength(), 20);
	}

	public Point getPosition() {
		return position;
	}

	public void setPosition(Point position) {
		this.position = position;
		recalculateBridgeFeatures();
	}

	public Dimension getSize() {
		return size;
	}

	public Object getClientObject() {
		return contig;
	}

	public boolean isForward() {
		return forward;
	}
	
	public boolean isSeedContig() {
		return seed;
	}

	public String toString() {
		return "ContigFeature[contig=" + contig + ", position=" + position
				+ ", size=" + size + ", forward=" + forward + "]";
	}

	public void addBridgeFeature(BridgeFeature bf) {
		bridgeSet.add(bf);
	}

	private void recalculateBridgeFeatures() {
		for (Iterator iter = bridgeSet.iterator(); iter.hasNext();) {
			BridgeFeature bf = (BridgeFeature) iter.next();

			bf.getParent().calculateBoundingShape();
		}
	}

	public void setParent(DrawableFeature parent) {
		this.parent = parent;
	}

	public DrawableFeature getParent() {
		return parent;
	}

	public Point getLeftEnd() {
		return new Point(position.x, position.y + size.height / 2);
	}

	public Point getRightEnd() {
		return new Point(position.x + size.width, position.y + size.height / 2);
	}
}
