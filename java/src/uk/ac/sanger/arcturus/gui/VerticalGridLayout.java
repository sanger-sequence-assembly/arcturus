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

package uk.ac.sanger.arcturus.gui;

import java.awt.Container;
import java.awt.GridLayout;
import java.awt.Insets;

public class VerticalGridLayout extends GridLayout {
	public VerticalGridLayout(int rows, int cols) {
		super(rows, cols);
	}

	public void layoutContainer(Container parent) {
		synchronized (parent.getTreeLock()) {
			Insets insets = parent.getInsets();
			int ncomponents = parent.getComponentCount();
			int nrows = getRows();
			int ncols = getColumns();

			if (ncomponents == 0) {
				return;
			}

			if (nrows > 0) {
				ncols = (ncomponents + nrows - 1) / nrows;
			} else {
				nrows = (ncomponents + ncols - 1) / ncols;
			}
			int w = parent.getWidth() - (insets.left + insets.right);
			int h = parent.getHeight() - (insets.top + insets.bottom);
			int vGap = getVgap();
			int hGap = getHgap();
			w = (w - (ncols - 1) * hGap) / ncols;
			h = (h - (nrows - 1) * vGap) / nrows;
			int compNum = 0;

			for (int c = 0, x = insets.left; c < ncols; c++, x += w + hGap) {
				for (int r = 0, y = insets.top; r < nrows; r++, y += h + vGap) {
					if (compNum < ncomponents)
						parent.getComponent(compNum++).setBounds(x, y, w, h);
					else
						break;
				}
			}
		}
	}
}
