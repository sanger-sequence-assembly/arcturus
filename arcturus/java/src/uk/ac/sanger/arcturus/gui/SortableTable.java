package uk.ac.sanger.arcturus.gui;

import javax.swing.JTable;
import javax.swing.table.*;
import java.awt.event.*;
import java.awt.Point;
import java.awt.Component;

public class SortableTable extends JTable {
    public SortableTable(SortableTableModel stm) {
	super((TableModel)stm);

	getTableHeader().addMouseListener(new MouseAdapter() {
		public void mouseClicked(MouseEvent event) {
		    handleHeaderMouseClick(event);
		}
	    });

	setDefaultRenderer(java.util.Date.class,
			   new ISODateRenderer());

	initColumnSizes();
    }

    private void handleHeaderMouseClick(MouseEvent event) {
	TableModel model = getModel();
	if (model instanceof SortableTableModel) {
	    Point point = event.getPoint();
	    int id = event.getID();

	    int col = getTableHeader().columnAtPoint(point);
	    int modelcol = convertColumnIndexToModel(col);

	    SortableTableModel stm = (SortableTableModel)model;

	    if (id == MouseEvent.MOUSE_CLICKED &&
		event.getButton() == MouseEvent.BUTTON1 &&
		stm.isColumnSortable(modelcol)) {
		boolean ascending = event.isShiftDown();
		stm.sortOnColumn(modelcol, ascending);
	    }
	}
    }

    /*
     * This method sets column width based upon the contents of the
     * cells.
     */

    private void initColumnSizes2() {
        SortableTableModel model = (SortableTableModel)getModel();
        TableColumn column = null;
        Component comp = null;
        int headerWidth = 0;
        int cellWidth = 0;
        Object[] longValues = model.getLongValues();
        TableCellRenderer headerRenderer =
            getTableHeader().getDefaultRenderer();

	int colcount = model.getColumnCount();

        for (int i = 0; i < colcount; i++) {
            column = getColumnModel().getColumn(i);

            comp = headerRenderer.getTableCellRendererComponent(null, column.getHeaderValue(),
								false, false, 0, 0);
            headerWidth = comp.getPreferredSize().width;

            comp = getDefaultRenderer(model.getColumnClass(i)).
		getTableCellRendererComponent(this, longValues[i],
					      false, false, 0, i);

            cellWidth = comp.getPreferredSize().width;

	    //System.err.println("Set width of column " + i +
	    //	       " (class=" + model.getColumnClass(i).getName() +
	    //	       ", long value=\"" + longValues[i] + "\") to " + cellWidth +
	    //	       " pixels.");

            column.setPreferredWidth(Math.max(headerWidth, cellWidth));
        }
    }

    private void initColumnSizes() {
        SortableTableModel model = (SortableTableModel)getModel();
	TableCellRenderer headerRenderer =
	    getTableHeader().getDefaultRenderer();

	int colcount = model.getColumnCount();
	int rowcount = model.getRowCount();
    
	for (int i = 0; i < colcount; i++) {
	    TableColumn column = getColumnModel().getColumn(i);
	
	    Component comp =
		headerRenderer.getTableCellRendererComponent(null,
							     column.getHeaderValue(), false, false, 0, 0);
	    int headerWidth = comp.getPreferredSize().width;
	
	    int cellWidth = 0;
	    Object largest = null;
	
	    for (int x = 0; x < rowcount; x++) {
		comp = getDefaultRenderer(model.getColumnClass(i))
		    .getTableCellRendererComponent(this,
						   model.getValueAt(x, i), false, false, x, i);

		int myWidth = comp.getPreferredSize().width;
		
		if (myWidth > cellWidth) {
		    cellWidth = myWidth;
		    largest = model.getValueAt(x, i);
		}
	    }

	    //System.err.println("Ideal width of column " + i +
	    //	       " (class=" + model.getColumnClass(i).getName() +
	    //	       ", largest object=" + largest + ") is " + cellWidth +
	    //	       " pixels (header is " + headerWidth + " pixels).");
	    
	    column.setPreferredWidth(Math.max(headerWidth, cellWidth));
	    //column.setMinWidth(Math.max(headerWidth, cellWidth));
	}
    }
}
