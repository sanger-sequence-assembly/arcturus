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

package uk.ac.sanger.arcturus.gui.scaffoldtable;

import java.awt.*;
import java.awt.event.*;

import javax.swing.*;
import javax.swing.table.*;

import uk.ac.sanger.arcturus.gui.SortableTable;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.scaffold.*;

public class ScaffoldTable  extends SortableTable {
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected JPopupMenu popupMenu;

	public ScaffoldTable(ScaffoldTableModel stm) {
		super((SortableTableModel) stm);

		// getColumnModel().getColumn(5).setPreferredWidth(150);

		addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				handleCellMouseClick(e);
			}

			public void mousePressed(MouseEvent e) {
				handleCellMouseClick(e);
			}

			public void mouseReleased(MouseEvent e) {
				handleCellMouseClick(e);
			}
		});

		popupMenu = new JPopupMenu();
		JMenuItem display = new JMenuItem("Display");
		popupMenu.add(display);
		display.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				displaySelectedScaffolds();
			}
		});
	}

	private void handleCellMouseClick(MouseEvent event) {
		if (event.isPopupTrigger()) {
			popupMenu.show(event.getComponent(), event.getX(), event.getY());
		} else if (event.getID() == MouseEvent.MOUSE_CLICKED
				&& event.getButton() == MouseEvent.BUTTON1
				&& event.getClickCount() == 2) {
			displaySelectedScaffolds();
		}
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

		if (isCellSelected(rowIndex, vColIndex)) {
			c.setBackground(getBackground());
			c.setForeground(Color.RED);
		} else {
			if (rowIndex % 2 == 0) {
				c.setBackground(VIOLET1);
			} else {
				c.setBackground(VIOLET2);
			}
			c.setForeground(Color.BLACK);
		}

		return c;
	}

	public void displaySelectedScaffolds() {
		int[] indices = getSelectedRows();
		ScaffoldTableModel ptm = (ScaffoldTableModel) getModel();

		String title = "Scaffold List:";

		System.err.println(title);
		
		for (int i = 0; i < indices.length; i++) {
			Scaffold scaffold = (Scaffold) ptm.elementAt(indices[i]);
			System.err.println(scaffold);
		}
	}

}
