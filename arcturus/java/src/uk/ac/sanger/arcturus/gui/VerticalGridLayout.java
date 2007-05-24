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
