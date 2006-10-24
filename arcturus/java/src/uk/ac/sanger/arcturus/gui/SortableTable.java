package uk.ac.sanger.arcturus.gui;

import javax.swing.JTable;
import javax.swing.table.*;
import javax.swing.event.*;
import java.awt.event.*;
import java.awt.Point;
import java.awt.Component;
import java.awt.Dimension;

public class SortableTable extends JTable {
	/**
	 * 
	 */
	private static final long serialVersionUID = 6686950946133273774L;
	
	protected MinervaFrame frame;

	public SortableTable(MinervaFrame frame, SortableTableModel stm) {
		super((TableModel) stm);
		
		this.frame = frame;

		getTableHeader().addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent event) {
				handleHeaderMouseClick(event);
			}
		});

		setDefaultRenderer(java.util.Date.class, new ISODateRenderer());

		stm.addTableModelListener(new TableModelListener() {
			public void tableChanged(TableModelEvent e) {
				initColumnSizes(2);
			}
		});
	}

	private void handleHeaderMouseClick(MouseEvent event) {
		TableModel model = getModel();
		if (model instanceof SortableTableModel) {
			Point point = event.getPoint();
			int id = event.getID();

			int col = getTableHeader().columnAtPoint(point);
			int modelcol = convertColumnIndexToModel(col);

			SortableTableModel stm = (SortableTableModel) model;

			if (id == MouseEvent.MOUSE_CLICKED
					&& event.getButton() == MouseEvent.BUTTON1
					&& stm.isColumnSortable(modelcol)) {
				boolean ascending = event.isShiftDown();
				stm.sortOnColumn(modelcol, ascending);
			}
		}
	}

	/*
	 * This method sets column width based upon the contents of the cells.
	 */

	private void initColumnSizes(int padding) {
		SortableTableModel model = (SortableTableModel) getModel();
		TableCellRenderer headerRenderer = getTableHeader()
				.getDefaultRenderer();

		int colcount = model.getColumnCount();
		int rowcount = model.getRowCount();

		int fullWidth = 0;

		for (int i = 0; i < colcount; i++) {
			TableColumn column = getColumnModel().getColumn(i);

			Component comp = headerRenderer.getTableCellRendererComponent(null,
					column.getHeaderValue(), false, false, 0, 0);
			int headerWidth = comp.getPreferredSize().width;

			int cellWidth = 0;

			for (int x = 0; x < rowcount; x++) {
				comp = getDefaultRenderer(model.getColumnClass(i))
						.getTableCellRendererComponent(this,
								model.getValueAt(x, i), false, false, x, i);

				int myWidth = comp.getPreferredSize().width;

				if (myWidth > cellWidth) {
					cellWidth = myWidth;
				}
			}

			int bestWidth = (headerWidth > cellWidth ? headerWidth : cellWidth)
					+ padding;

			column.setPreferredWidth(bestWidth);
			column.setMinWidth(bestWidth);

			fullWidth += bestWidth;
		}

		doLayout();
	}

	public Dimension getPreferredScrollableViewportSize() {
		return getPreferredSize();
	}
	
	public MinervaFrame getFrame() {
		return frame;
	}
}
