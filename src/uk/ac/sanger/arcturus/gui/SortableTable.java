package uk.ac.sanger.arcturus.gui;

import javax.swing.JTable;
import javax.swing.table.*;
import java.awt.event.*;
import java.awt.Point;

public class SortableTable extends JTable {
    public SortableTable(SortableTableModel stm) {
	super((TableModel)stm);

	getTableHeader().addMouseListener(new MouseAdapter() {
		public void mouseClicked(MouseEvent event) {
		    handleHeaderMouseClick(event);
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

	    SortableTableModel stm = (SortableTableModel)model;

	    if (id == MouseEvent.MOUSE_CLICKED &&
		event.getButton() == MouseEvent.BUTTON1 &&
		stm.isColumnSortable(modelcol)) {
		boolean ascending = event.isShiftDown();
		stm.sortOnColumn(modelcol, ascending);
	    }
	}
    }
}
