package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import java.awt.BorderLayout;
import java.awt.event.*;

import java.sql.SQLException;
import java.util.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.Arcturus;

public class ContigTablePanel extends MinervaPanel {
	protected ContigTable table = null;
	protected ContigTableModel model = null;

	protected JCheckBoxMenuItem cbGroupByProject = new JCheckBoxMenuItem(
			"Group by project");

	protected JFileChooser fileChooser = new JFileChooser();

	protected MinervaAbstractAction actionExportAsCAF;
	protected MinervaAbstractAction actionExportAsFasta;
	protected MinervaAbstractAction actionViewContigs;
	
	protected JMenu xferMenu = null;
	
	protected String projectlist;

	protected boolean oneProject;

	public ContigTablePanel(Project[] projects, MinervaTabbedPane parent) {
		super(new BorderLayout(), parent, projects[0].getArcturusDatabase());

		projectlist = (projects != null && projects.length > 0) ? projects[0]
				.getName() : "[null]";

		for (int i = 1; i < projects.length; i++)
			projectlist += "," + projects[i].getName();

		oneProject = projects.length == 1;

		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		table.getSelectionModel().addListSelectionListener(
				new ListSelectionListener() {
					public void valueChanged(ListSelectionEvent e) {
						updateActions();
					}
				});

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane, BorderLayout.CENTER);

		createActions();

		createMenus();
		
		getPrintAction().setEnabled(false);

		if (projects.length < 2)
			cbGroupByProject.setEnabled(false);

		updateActions();
	}

	protected void createActions() {
		actionExportAsCAF = new MinervaAbstractAction("Export as CAF", null,
				"Export contigs as CAF", new Integer(KeyEvent.VK_E), KeyStroke
						.getKeyStroke(KeyEvent.VK_E, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsCAF();
			}
		};

		actionExportAsFasta = new MinervaAbstractAction("Export as FASTA",
				null, "Export contigs as FASTA", new Integer(KeyEvent.VK_F),
				KeyStroke.getKeyStroke(KeyEvent.VK_F, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsFasta();
			}
		};

		actionViewContigs = new MinervaAbstractAction("Open selected contigs",
				null, "Open selected contigs", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				viewSelectedContigs();
			}
		};
	}

	protected void updateActions() {
		boolean noneSelected = table.getSelectionModel().isSelectionEmpty();
		actionExportAsCAF.setEnabled(!noneSelected);
		actionExportAsFasta.setEnabled(!noneSelected);
		actionViewContigs.setEnabled(!noneSelected);
		if (xferMenu != null)
			xferMenu.setEnabled(!noneSelected);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionViewContigs);

		return true;
	}

	protected void exportAsCAF() {
		if (table.getSelectedRowCount() > 0) {
			int rc = fileChooser.showSaveDialog(this);

			if (rc == JFileChooser.APPROVE_OPTION) {
				table.saveSelectedContigsAsCAF(fileChooser.getSelectedFile());
			}
		} else {
			JOptionPane.showMessageDialog(this,
					"Please select the contigs to export",
					"No contigs selected", JOptionPane.WARNING_MESSAGE, null);
		}
	}

	protected void exportAsFasta() {
		if (table.getSelectedRowCount() > 0) {
			int rc = fileChooser.showSaveDialog(this);

			if (rc == JFileChooser.APPROVE_OPTION) {
				table.saveSelectedContigsAsFasta(fileChooser.getSelectedFile());
			}
		} else {
			JOptionPane.showMessageDialog(this,
					"Please select the contigs to export",
					"No contigs selected", JOptionPane.WARNING_MESSAGE, null);
		}
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
		menu.addSeparator();

		menu.add(cbGroupByProject);

		cbGroupByProject.setSelected(false);

		cbGroupByProject.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				boolean byProject = cbGroupByProject.getState();
				model.setGroupByProject(byProject);
			}
		});
	}

	protected void createClassSpecificMenus() {
		createProjectMenu();
		createContigMenu();
	}

	protected void createProjectMenu() {
		JMenu projectMenu = createMenu("Project", KeyEvent.VK_P, "Project");
		menubar.add(projectMenu);

		projectMenu.add(actionShowReadImporter);

		actionShowReadImporter.setEnabled(oneProject);
	}

	protected void createContigMenu() {
		JMenu contigMenu = createMenu("Contig", KeyEvent.VK_C, "Contig");
		menubar.add(contigMenu);

		contigMenu.add(actionViewContigs);

		contigMenu.addSeparator();

		contigMenu.add(actionExportAsCAF);

		contigMenu.add(actionExportAsFasta);

		Person me = PeopleManager.findMe();

		Set mypset = null;

		try {
			if (administrator)
				mypset = adb.getAllProjects();
			else
				mypset = adb.getProjectsForOwner(me);
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error whilst enumerating my projects", sqle);
		}

		if (mypset != null && !mypset.isEmpty()) {
			contigMenu.addSeparator();

			xferMenu = new JMenu("Transfer selected contigs to");

			contigMenu.add(xferMenu);
			
			Project[] myProjects = (Project[]) mypset.toArray(new Project[0]);

			Arrays.sort(myProjects, new ProjectComparator());

			for (int i = 0; i < myProjects.length; i++)
				if (!myProjects[i].isBin())
					xferMenu.add(new ContigTransferAction(table, myProjects[i]));
			
			Project bin = null;

			try {
				bin = adb.getProjectByName(null, "BIN");
			} catch (SQLException sqle) {
				Arcturus.logWarning("Error whilst finding the BIN project", sqle);
			}

			if (bin != null) {
				xferMenu.addSeparator();
				xferMenu.add(new ContigTransferAction(table, bin));
			}
			
			if (xferMenu.getMenuComponentCount() > 40) {	        
				VerticalGridLayout menuGrid = new VerticalGridLayout(40,0);   
		        xferMenu.getPopupMenu().setLayout(menuGrid); 
			}
		}
	}

	class ProjectComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			Project p1 = (Project) o1;
			Project p2 = (Project) o2;

			return p1.getName().compareTo(p2.getName());
		}

	}

	protected void viewSelectedContigs() {
		JOptionPane
				.showMessageDialog(
						this,
						"The selected contigs will be displayed in a colourful and informative way",
						"Display contigs", JOptionPane.INFORMATION_MESSAGE,
						null);
	}

	public void closeResources() {
		// Does nothing
	}

	public String toString() {
		return "ContigTablePanel[projects=" + projectlist + "]";
	}

	public boolean isOneProject() {
		return oneProject;
	}

	public void refresh() {
		table.refresh();
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}
}
