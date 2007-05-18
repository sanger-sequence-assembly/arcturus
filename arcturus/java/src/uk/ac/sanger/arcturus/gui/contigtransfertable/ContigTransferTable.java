package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.table.*;
import javax.swing.ListSelectionModel;
import java.text.*;

import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
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

		if (c instanceof JComponent) {
			String text = null;
			ContigTransferRequest request = ((ContigTransferTableModel) getModel())
					.getRequestForRow(rowIndex);

			switch (vColIndex) {
				case ContigTransferTableModel.COLUMN_CONTIG_ID:
					Contig contig = request.getContig();
					;

					text = contig == null ? "Contig no longer exists"
							: "Contig " + contig.getID() + "\n" + "  Name = "
									+ contig.getName() + "\n" + "  Length = "
									+ contig.getLength() + "bp\n"
									+ "  Created "
									+ formatter.format(contig.getCreated());
					break;

				case ContigTransferTableModel.COLUMN_REQUESTER:
				case ContigTransferTableModel.COLUMN_OPENED_DATE:
					text = request.getRequesterComment();
					break;

				case ContigTransferTableModel.COLUMN_REVIEWER:
				case ContigTransferTableModel.COLUMN_REVIEWED_DATE:
				case ContigTransferTableModel.COLUMN_STATUS:
					text = request.getReviewerComment();
					break;
			}

			((JComponent) c).setToolTipText(text);
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
