package uk.ac.sanger.arcturus.gui.projecttable;

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.table.*;
import java.util.*;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.gui.*;

import uk.ac.sanger.arcturus.gui.contigtable.ContigTableFrame;
import uk.ac.sanger.arcturus.gui.scaffoldtable.ScaffoldTableFrame;

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ProjectTable extends SortableTable {
	/**
	 * 
	 */
	private static final long serialVersionUID = -6687174884203004659L;
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected JPopupMenu popupMenu;

	public ProjectTable(ProjectTableFrame frame, ProjectTableModel ptm) {
		super(frame, (SortableTableModel) ptm);

		// getColumnModel().getColumn(5).setPreferredWidth(150);

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
		
		JMenuItem scaffold = new JMenuItem("Scaffold");
		popupMenu.add(scaffold);
		scaffold.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent event) {
				scaffoldSelectedProjects();
			}
		});
	}

	private void handleCellMouseClick(MouseEvent event) {
		if (event.isPopupTrigger()) {
			popupMenu.show(event.getComponent(), event.getX(), event.getY());
		} else if (event.getID() == MouseEvent.MOUSE_CLICKED
				&& event.getButton() == MouseEvent.BUTTON1
				&& event.getClickCount() == 2) {
			displaySelectedProjects();
		}
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
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
		ProjectTableModel ptm = (ProjectTableModel) getModel();
		ProjectList clist = new ProjectList();
		for (int i = 0; i < indices.length; i++)
			clist.add(ptm.elementAt(indices[i]));

		return clist;
	}

	public void displaySelectedProjects() {
		int[] indices = getSelectedRows();
		
		if (indices.length == 0)
			return;
		
		ProjectTableModel ptm = (ProjectTableModel) getModel();

		Set contigs = new HashSet();

		String title = "Contig List:";

		for (int i = 0; i < indices.length; i++) {
			ProjectProxy proxy = (ProjectProxy) ptm.elementAt(indices[i]);
			Project project = proxy.getProject();

			title += ((i > 0) ? "," : " ") + project.getName();

			try {
				Set contigsForProject = project.getContigs(true);
				contigs.addAll(contigsForProject);
			} catch (SQLException sqle) {
				sqle.printStackTrace();
			}
		}

		Minerva minerva = Minerva.getInstance();

		ArcturusDatabase adb = ptm.getArcturusDatabase();

		ContigTableFrame.createAndShowFrame(minerva, title, adb, contigs);
	}
	
	public void scaffoldSelectedProjects() {
		int[] indices = getSelectedRows();
		
		if (indices.length == 0)
			return;

		String title = "Scaffold:";

		ProjectTableModel ptm = (ProjectTableModel) getModel();

		Set projects = new HashSet();
		
		for (int i = 0; i < indices.length; i++) {
			ProjectProxy proxy = (ProjectProxy) ptm.elementAt(indices[i]);
			Project project = proxy.getProject();
			projects.add(project);
			
			title += ((i > 0) ? "," : " ") + project.getName();
		}
		
		Minerva minerva = Minerva.getInstance();

		ArcturusDatabase adb = ptm.getArcturusDatabase();

		ScaffoldTableFrame.createAndShowFrame(minerva, title, adb, projects);
	}
}
