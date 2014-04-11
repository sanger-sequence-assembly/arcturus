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
