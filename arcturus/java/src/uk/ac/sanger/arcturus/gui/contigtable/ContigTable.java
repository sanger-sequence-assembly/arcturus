package uk.ac.sanger.arcturus.gui.contigtable;

import java.awt.*;
import javax.swing.table.*;

import uk.ac.sanger.arcturus.gui.SortableTable;
import uk.ac.sanger.arcturus.gui.SortableTableModel;

public class ContigTable extends SortableTable {
	/**
	 * 
	 */
	private static final long serialVersionUID = -5151666511676328720L;
	public final static int BY_ROW_NUMBER = 1;
	public final static int BY_PROJECT = 2;
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected int howToColour = BY_ROW_NUMBER;

	public ContigTable(ContigTableFrame frame, SortableTableModel stm) {
		super(frame, stm);
	}

	public void setHowToColour(int how) {
		howToColour = how;
		repaint();
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

		switch (howToColour) {
			case BY_ROW_NUMBER:
				if (isCellSelected(rowIndex, vColIndex)) {
					c.setBackground(getBackground());
				} else {
					if (rowIndex % 2 == 0) {
						c.setBackground(VIOLET1);
					} else {
						c.setBackground(VIOLET2);
					}
				}
				break;

			case BY_PROJECT:
				ContigTableModel ctm = (ContigTableModel) getModel();
				//int project = ctm.getProjectIDAtRow(rowIndex);
				if (isCellSelected(rowIndex, vColIndex)) {
					c.setBackground(getBackground());
				} else {
					c.setBackground(ctm.getColourForRow(rowIndex));
				}

				break;

			default:
				break;
		}

		if (isCellSelected(rowIndex, vColIndex))
			c.setForeground(Color.RED);
		else
			c.setForeground(Color.BLACK);

		return c;
	}

	public ContigList getSelectedValues() {
		int[] indices = getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) getModel();
		ContigList clist = new ContigList();
		for (int i = 0; i < indices.length; i++)
			clist.add(ctm.elementAt(indices[i]));

		return clist;
	}
}
