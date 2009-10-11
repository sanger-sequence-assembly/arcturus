package uk.ac.sanger.arcturus.gui;

public interface SortableTableModel extends javax.swing.table.TableModel {
	public boolean isColumnSortable(int column);

	public void sortOnColumn(int column, boolean ascending);
	
	public void refresh();
}
