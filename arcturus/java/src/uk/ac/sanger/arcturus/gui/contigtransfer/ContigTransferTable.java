package uk.ac.sanger.arcturus.gui.contigtransfer;

import java.awt.*;
import javax.swing.table.*;
import javax.swing.ListSelectionModel;

import uk.ac.sanger.arcturus.gui.SortableTable;

public class ContigTransferTable extends SortableTable {
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	public ContigTransferTable(ContigTransferTableModel cttm) {
		super(cttm);
		setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

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
}
