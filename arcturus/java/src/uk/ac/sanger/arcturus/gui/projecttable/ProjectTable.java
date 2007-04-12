package uk.ac.sanger.arcturus.gui.projecttable;

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.table.*;
import java.util.*;

import uk.ac.sanger.arcturus.gui.*;

import uk.ac.sanger.arcturus.gui.contigtable.ContigTablePanel;
import uk.ac.sanger.arcturus.gui.scaffoldtable.ScaffoldTableFrame;

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ProjectTable extends SortableTable {
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	public ProjectTable(ProjectTableModel ptm) {
		super((SortableTableModel) ptm);

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
	}

	private void handleCellMouseClick(MouseEvent event) {
		if (event.isPopupTrigger()) {
			// show popup?
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
		
		ProjectTableModel ptm = (ProjectTableModel) getModel();
		ProjectProxy proxy = ptm.getProjectAtRow(rowIndex);
		
		if (proxy.isMine()) {
			Font font = c.getFont().deriveFont(Font.BOLD);
			c.setFont(font);
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
		
		Project[] projects = new Project[indices.length];
		
		String title = null;
		
		String names[] = new String[indices.length];

		for (int i = 0; i < indices.length; i++) {
			ProjectProxy proxy = (ProjectProxy) ptm.elementAt(indices[i]);
			projects[i] = proxy.getProject();
			names[i] = projects[i].getName();
		}
		
		Arrays.sort(names);
		
		for (int i = 0; i < names.length; i++) {
			if (i == 0)
				title = names[i];
			else
				title += "," + names[i];
		}
		
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);

		ContigTablePanel ctp = new ContigTablePanel(projects, mtp);
	
		mtp.add(title, ctp);
		
		JFrame frame = (JFrame)SwingUtilities.getRoot(mtp);
		frame.pack();
		
		mtp.setSelectedComponent(ctp);
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
