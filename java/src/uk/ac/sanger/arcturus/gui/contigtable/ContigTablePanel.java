package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import java.awt.BorderLayout;
import java.awt.Point;
import java.awt.event.*;

import java.sql.SQLException;
import java.util.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.scaffold.ScaffoldWorker;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.Arcturus;

public class ContigTablePanel extends MinervaPanel implements ProjectChangeEventListener {
	protected ContigTable table = null;
	protected ContigTableModel model = null;

	protected JCheckBoxMenuItem cbGroupByProject = new JCheckBoxMenuItem(
			"Group by project");

	protected JFileChooser fileChooser = new JFileChooser();

	protected MinervaAbstractAction actionExportAsCAF;
	protected MinervaAbstractAction actionExportAsFasta;
	protected MinervaAbstractAction actionViewContigs;
	protected MinervaAbstractAction actionScaffoldContig;
	
	protected JMenu xferMenu = new JMenu("Transfer selected contigs to");
	
	protected JPopupMenu contigPopupMenu = new JPopupMenu();
	
	protected String projectlist;

	protected boolean oneProject;
	
	public ContigTablePanel(Project[] projects, MinervaTabbedPane parent) {
		super(new BorderLayout(), parent, projects[0].getArcturusDatabase());
		
		projectlist = (projects != null && projects.length > 0) ? projects[0]
				.getName() : "[null]";

		for (int i = 1; i < projects.length; i++)
			projectlist += "," + projects[i].getName();
		
		for (int i = 0; i < projects.length; i++)
			adb.addProjectChangeEventListener(projects[i], this);

		oneProject = projects.length == 1;

		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		table.getSelectionModel().addListSelectionListener(
				new ListSelectionListener() {
					public void valueChanged(ListSelectionEvent e) {
						updateActions();
					}
				});
		
		table.addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				handleMouseEvent(e);
			}

			public void mousePressed(MouseEvent e) {
				handleMouseEvent(e);
			}

			public void mouseReleased(MouseEvent e) {
				handleMouseEvent(e);
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

		adb.addProjectChangeEventListener(this);
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

		actionScaffoldContig = new MinervaAbstractAction("Scaffold the selected contig",
				null, "Scaffold the selected contig", new Integer(KeyEvent.VK_S),
				KeyStroke.getKeyStroke(KeyEvent.VK_S, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				scaffoldTheSelectedContig();
			}
		};
	}

	protected void updateActions() {
		int nrows = table.getSelectedRowCount();
		boolean noneSelected = nrows == 0;
		
		actionExportAsCAF.setEnabled(!noneSelected);
		actionExportAsFasta.setEnabled(!noneSelected);
		actionViewContigs.setEnabled(!noneSelected);
		if (xferMenu != null)
			xferMenu.setEnabled(!noneSelected);
		
		actionScaffoldContig.setEnabled(nrows == 1);
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
		createContigMenu();
	}

	protected void createContigMenu() {
		JMenu contigMenu = createMenu("Contig", KeyEvent.VK_C, "Contig");
		menubar.add(contigMenu);

		contigMenu.add(actionViewContigs);

		contigMenu.addSeparator();

		contigMenu.add(actionExportAsCAF);

		contigMenu.add(actionExportAsFasta);
		
		contigMenu.addSeparator();
		
		contigMenu.add(actionScaffoldContig);

		contigMenu.addSeparator();

		contigMenu.add(xferMenu);
		
		refreshContigTransferMenu();
		
		contigPopupMenu.add(actionViewContigs);

		contigPopupMenu.addSeparator();

		contigPopupMenu.add(actionExportAsCAF);

		contigPopupMenu.add(actionExportAsFasta);
		
		contigPopupMenu.addSeparator();
		
		contigPopupMenu.add(actionScaffoldContig);
	}
	
	protected void refreshContigTransferMenu() {
		xferMenu.removeAll();
		
		Person me = adb.findMe();

		Set<Project> mypset = null;
		
		try {
			if (adb.isCoordinator())
				mypset = adb.getAllProjects();
			else
				mypset = adb.getProjectsForOwner(me);
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error whilst enumerating my projects", sqle);
		}

		if (mypset != null && !mypset.isEmpty()) {
			SortedSet<Project> myProjects = new TreeSet<Project>(new ProjectComparator());
			myProjects.addAll(mypset);

			for (Project project : myProjects)
				if (!project.isBin()) {
					ContigTransferAction action = new ContigTransferAction(table, project);
					action.setEnabled(project.isActive());
					xferMenu.add(action);
				}
			
			Set<Project> bin = null;

			try {
				bin = adb.getBinProjects();
			} catch (SQLException sqle) {
				Arcturus.logWarning("Error whilst finding the BIN project", sqle);
			}

			if (bin != null) {
				xferMenu.addSeparator();
				for (Project project : bin)
					xferMenu.add(new ContigTransferAction(table, project));
			}
			
			if (xferMenu.getMenuComponentCount() > 40) {	        
				VerticalGridLayout menuGrid = new VerticalGridLayout(40,0);   
		        xferMenu.getPopupMenu().setLayout(menuGrid); 
			}
		}

	}

	class ProjectComparator implements Comparator<Project> {
		public int compare(Project p1, Project p2) {
			return p1.getName().compareTo(p2.getName());
		}

	}

	private void handleMouseEvent(MouseEvent e) {
		if (e.isPopupTrigger()) {
			displayPopupMenu(e);
		}
	}

	protected void displayPopupMenu(MouseEvent e) {
		contigPopupMenu.show(e.getComponent(), e.getX(), e.getY());
	}
	
	protected void viewSelectedContigs() {
		JOptionPane
				.showMessageDialog(
						this,
						"The selected contigs will be displayed in a colourful and informative way",
						"Display contigs", JOptionPane.INFORMATION_MESSAGE,
						null);
	}
	
	protected void scaffoldTheSelectedContig() {
		int[] indices = table.getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) table.getModel();

		Contig contig = (Contig)ctm.elementAt(indices[0]);

		ScaffoldWorker worker = new ScaffoldWorker(contig, parent, adb);
		
		worker.execute();		
	}

	public void closeResources() {
		adb.removeProjectChangeEventListener(this);
	}

	public String toString() {
		return "ContigTablePanel[projects=" + projectlist + "]";
	}

	public boolean isOneProject() {
		return oneProject;
	}

	public void refresh() {
		table.refresh();
		refreshContigTransferMenu();
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}

	public void projectChanged(ProjectChangeEvent event) {
		refresh();
	}
}
