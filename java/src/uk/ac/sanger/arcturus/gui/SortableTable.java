package uk.ac.sanger.arcturus.gui;

import javax.swing.JTable;
import javax.swing.ListSelectionModel;
import javax.swing.table.*;
import javax.swing.event.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.awt.event.*;
import java.awt.Point;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;

public class SortableTable extends JTable {
	public final static int MAX_VIEWPORT_HEIGHT = 800;
	public final static int MIN_VIEWPORT_WIDTH = 500;

	public SortableTable(SortableTableModel stm) {
		super((TableModel) stm);

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
		
		initColumnSizes(2);
		
		setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
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

				Font font = comp.getFont().deriveFont(Font.BOLD);
				comp.setFont(font);

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
        Dimension prefsize = getPreferredSize();
       
        if (prefsize.height > MAX_VIEWPORT_HEIGHT)
            prefsize.height = MAX_VIEWPORT_HEIGHT;
        
        if (prefsize.width < MIN_VIEWPORT_WIDTH)
        	prefsize.width = MIN_VIEWPORT_WIDTH;
       
        return prefsize;
    }
    
    public void refresh() throws ArcturusDatabaseException {
    	((SortableTableModel)getModel()).refresh();
    }
}
