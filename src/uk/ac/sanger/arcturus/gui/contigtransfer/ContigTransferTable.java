package uk.ac.sanger.arcturus.gui.contigtransfer;

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.table.*;
import javax.swing.ListSelectionModel;
import java.text.*;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.gui.SortableTable;

import uk.ac.sanger.arcturus.gui.genericdisplay.InfoPanel;
import uk.ac.sanger.arcturus.gui.genericdisplay.InvalidClientObjectException;
import uk.ac.sanger.arcturus.gui.genericdisplay.PopupManager;

public class ContigTransferTable extends SortableTable implements PopupManager {
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);
	private final DateFormat formatter = new SimpleDateFormat(
			"yyyy MMM dd HH:mm");

	protected ContigInfoPanel cip;

	protected Popup popup;

	public ContigTransferTable(ContigTransferTableModel cttm) {
		super(cttm);
		setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

		addMouseListener(new MouseAdapter() {
			public void mousePressed(MouseEvent e) {
				handleMouseEvent(e);
			}
		});

		cip = new ContigInfoPanel(this);
	}

	private void handleMouseEvent(MouseEvent e) {
		Point point = e.getPoint();

		int row = rowAtPoint(point);
		int column = columnAtPoint(point);
		int modelColumn = convertColumnIndexToModel(column);

		if (modelColumn != ContigTransferTableModel.COLUMN_CONTIG_ID)
			return;

		System.out.println("Mouse click at " + point + " --> row " + row
				+ ", column " + column + "(model column " + modelColumn + ")");

		Contig contig = ((ContigTransferTableModel) getModel())
				.getContigForRow(row);
		
		try {
			cip.setClientObject(contig);
			displayPopup(cip, point);
		} catch (InvalidClientObjectException e1) {
			e1.printStackTrace();
		}		
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

		if (vColIndex == ContigTransferTableModel.COLUMN_CONTIG_ID
				&& c instanceof JComponent) {
			Contig contig = ((ContigTransferTableModel) getModel())
					.getContigForRow(rowIndex);

			JComponent jc = (JComponent) c;

			String text = "Contig " + contig.getID() + "\n" + "  Name = "
					+ contig.getName() + "\n" + "  Length = "
					+ contig.getLength() + "bp\n" + "  Created "
					+ formatter.format(contig.getCreated());

			jc.setToolTipText(text);
		}

		if (isCellSelected(rowIndex, vColIndex)) {
			c.setBackground(getBackground());
		} else {
			if (rowIndex % 2 == 0) {
				c.setBackground(VIOLET1);
			} else {
				c.setBackground(VIOLET2);
			}
		}

		if (isCellSelected(rowIndex, vColIndex))
			c.setForeground(Color.RED);
		else
			c.setForeground(Color.BLACK);

		return c;
	}

	public void hidePopup() {
		if (popup != null) {
			popup.hide();
			popup = null;
		}
	}

	private void displayPopup(InfoPanel ip, Point p) {
		SwingUtilities.convertPointToScreen(p, this);

		PopupFactory factory = PopupFactory.getSharedInstance();
		popup = factory.getPopup(this, ip, p.x - 5, p.y - 5);
		popup.show();
	}
}
