package uk.ac.sanger.arcturus.gui.projecttable;

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.table.*;
import java.sql.Connection;

import uk.ac.sanger.arcturus.gui.SortableTable;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.gui.ISODateRenderer;

public class ProjectTable extends SortableTable {
    protected final Color paleYellow = new Color(255, 255, 238);
    protected final Color VIOLET1 = new Color(245, 245, 255);
    protected final Color VIOLET2 = new Color(238, 238, 255);
    protected final Color VIOLET3 = new Color(226, 226, 255);

    protected JPopupMenu popupMenu;

    public ProjectTable(ProjectTableModel ptm) {
	super((SortableTableModel)ptm);

	setDefaultRenderer(java.util.Date.class,
			   new ISODateRenderer());

	getColumnModel().getColumn(5).setPreferredWidth(150);

	addMouseListener(new MouseAdapter() {
		public void mouseClicked(MouseEvent e) {
		    handleCellMouseClick(e);
		}
		public void mousePressed(MouseEvent e) {
		    handleCellMouseClick(e);
		}
		public void mouseReleased(MouseEvent e) {
		    handleCellMouseClick(e);
		}
	    });

	popupMenu = new JPopupMenu();
	JMenuItem display = new JMenuItem("Display");
	popupMenu.add(display);
	display.addActionListener(new ActionListener() {
		public void actionPerformed(ActionEvent event) {
		    displaySelectedProjects();
		}
	    });
    }

    private void handleCellMouseClick(MouseEvent event) {
	Point point = event.getPoint();
	int row = rowAtPoint(point);
	int col = columnAtPoint(point);
	int modelcol = convertColumnIndexToModel(col);

	if (event.isPopupTrigger()) {
	    //System.err.println("popup triggered at row " + row + ", view column " + col + ", model column " + modelcol);
	    popupMenu.show(event.getComponent(), event.getX(), event.getY());
	}

	if (event.getID() == MouseEvent.MOUSE_CLICKED &&
	    event.getButton() == MouseEvent.BUTTON1 &&
	    event.getClickCount() == 2) {
	    //System.err.println("Double click at row " + row + ", view column " + col + ", model column " + modelcol);
	    ProjectTableModel ptm = (ProjectTableModel)getModel();
	    ProjectProxy project = (ProjectProxy)ptm.elementAt(row);
	    int project_id = project.getID();
	    Connection conn = ptm.getConnection();
	    int idlist[] = {project_id};
	    //createAndShowContigTable(conn, idlist);
	}
    }

    //private void createAndShowContigTable(Connection conn, int[] idlist) {
    //	ContigPanel.createAndShowGUI(conn, idlist);
    //}

    public Component prepareRenderer(TableCellRenderer renderer,
				     int rowIndex, int vColIndex) {
	Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

	if (isCellSelected(rowIndex, vColIndex)) {
	    c.setBackground(getBackground());
	    c.setForeground(Color.RED);
	} else {
	    if (rowIndex % 2 == 0) {
		c.setBackground(VIOLET1);
	    } else {
		c.setBackground(VIOLET2);
	    }
	    c.setForeground(Color.BLACK);
	}

	return c;
    }

    public ProjectList getSelectedValues() {
	int[] indices = getSelectedRows();
	ProjectTableModel ptm = (ProjectTableModel)getModel();
	ProjectList clist = new ProjectList();
	for (int i = 0; i < indices.length; i++)
	    clist.add(ptm.elementAt(indices[i]));

	return clist;
    }

    private void displaySelectedProjects() {
	int[] indices = getSelectedRows();
	ProjectTableModel ptm = (ProjectTableModel)getModel();
	for (int i = 0; i < indices.length; i++) {
	    ProjectProxy project = (ProjectProxy)ptm.elementAt(indices[i]);
	    indices[i] = project.getID();
	}
    }
}
