package uk.ac.sanger.arcturus.gui;

import javax.swing.JTable;
import javax.swing.table.*;
import java.awt.event.*;
import java.awt.Point;
import java.awt.Component;
import java.awt.Dimension;

public class SortableTable extends JTable {
    public SortableTable(SortableTableModel stm) {
	super((TableModel)stm);

	getTableHeader().addMouseListener(new MouseAdapter() {
		public void mouseClicked(MouseEvent event) {
		    handleHeaderMouseClick(event);
		}
	    });

	//setAutoResizeMode(JTable.AUTO_RESIZE_OFF);

	setDefaultRenderer(java.util.Date.class,
			   new ISODateRenderer());

	initColumnSizes(5);
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

    private void initColumnSizes(int padding) {
        SortableTableModel model = (SortableTableModel)getModel();
	TableCellRenderer headerRenderer =
	    getTableHeader().getDefaultRenderer();

	int colcount = model.getColumnCount();
	int rowcount = model.getRowCount();

	int fullWidth = 0;
    
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


	    System.err.println("Column " + i + ":" +
	    	       "\n\tclass=" + model.getColumnClass(i).getName() +
	    	       "\n\tlargest object=\"" + largest + "\" is " + cellWidth +
	    	       " pixels wide\n\theader is " + headerWidth + " pixels wide");
	    
	    int bestWidth = (headerWidth > cellWidth ? headerWidth : cellWidth) + padding;

	    column.setPreferredWidth(bestWidth);
	    column.setMinWidth(bestWidth);

	    fullWidth += bestWidth;
	}

	doLayout();

	System.err.println("fullWidth = " + fullWidth + ", preferred width =" + getPreferredSize().width);
	for (int i = 0; i < colcount; i++) {
	    TableColumn column = getColumnModel().getColumn(i);
	    System.err.println("Column " + i + " preferred width = " + column.getPreferredWidth() +
			       ", actual width = " + column.getWidth());
	}
    }

    public Dimension getPreferredScrollableViewportSize() {
	return getPreferredSize();
    }
}
