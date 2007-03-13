package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import javax.swing.event.PopupMenuEvent;
import javax.swing.event.PopupMenuListener;

import java.awt.*;
import java.awt.event.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.*;

public class ProjectTablePanel extends JPanel implements MinervaClient  {
	private ProjectTable table = null;
	private ProjectTableModel model = null;
	private JMenuBar menubar = new JMenuBar();

	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionViewProject;
	private MinervaAbstractAction actionImportReads;
	private MinervaAbstractAction actionHelp;
	private MinervaAbstractAction actionRefresh;

	ArcturusDatabase adb;

	public ProjectTablePanel(ArcturusDatabase adb) {
		super(new BorderLayout());
		
		this.adb = adb;
		
		model = new ProjectTableModel(adb);

		table = new ProjectTable(model);
		table.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
		
		JScrollPane scrollpane = new JScrollPane(table);
		
		add(scrollpane, BorderLayout.CENTER);
		
		createActions();
		
		createMenus();
	}
	
	private void createActions() {
		actionClose = new MinervaAbstractAction("Close", null, "Close this window",
				new Integer(KeyEvent.VK_C),
				KeyStroke.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
					public void actionPerformed(ActionEvent e) {
						closePanel();
					}			
		};
		
		actionViewProject = new MinervaAbstractAction("Open selected project",
				null, "Open selected project", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				viewSelectedProjects();
			}
		};
		
		actionImportReads = new MinervaAbstractAction("Import reads into project",
				null, "Import reads into project", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				importReadsIntoProject();
			}
		};
		
		actionRefresh = new MinervaAbstractAction("Refresh",
				null, "Refresh the display", new Integer(KeyEvent.VK_R),
				KeyStroke.getKeyStroke(KeyEvent.VK_F5, 0)) {
			public void actionPerformed(ActionEvent e) {
				refresh();
			}
		};
	
		actionHelp = new MinervaAbstractAction("Help",
				null, "Help", new Integer(KeyEvent.VK_H),
				KeyStroke.getKeyStroke(KeyEvent.VK_F1, 0)) {
			public void actionPerformed(ActionEvent e) {
				Minerva.displayHelp();
			}
		};
	}
	
	private void createMenus() {
		createFileMenu();
		createEditMenu();
		createViewMenu();
		createProjectMenu();
		menubar.add(Box.createHorizontalGlue());
		createHelpMenu();
	}

	private JMenu createMenu(String name, int mnemonic, String description) {
		JMenu menu = new JMenu(name);

		menu.setMnemonic(mnemonic);

		if (description != null)
			menu.getAccessibleContext().setAccessibleDescription(description);

		return menu;
	}

	private void createFileMenu() {
		JMenu fileMenu = createMenu("File", KeyEvent.VK_F, "File");
		menubar.add(fileMenu);
		
		fileMenu.add(actionViewProject);
		
		fileMenu.addSeparator();
				
		fileMenu.add(actionClose);
		
		fileMenu.addSeparator();
		
		fileMenu.add(Minerva.getQuitAction());
	}

	private void closePanel() {
		int rc = JOptionPane.showOptionDialog(this,
				"Do you REALLY want to close the project list?",
	    		 "Warning",
	    		 JOptionPane.OK_CANCEL_OPTION,
	    		 JOptionPane.WARNING_MESSAGE,
	    		 null, null, null);

		if (rc == JOptionPane.OK_OPTION) {
			MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
			mtp.remove(this);
		}
	}
	
	private void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}
	
	private void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);
		
		viewMenu.add(actionRefresh);

		viewMenu.addSeparator();

		ButtonGroup group = new ButtonGroup();

		JRadioButtonMenuItem rbShowProjectDate = new JRadioButtonMenuItem(
				"Show project date");
		group.add(rbShowProjectDate);
		viewMenu.add(rbShowProjectDate);

		rbShowProjectDate.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.PROJECT_UPDATED_DATE);
			}
		});

		JRadioButtonMenuItem rbShowContigCreated = new JRadioButtonMenuItem(
				"Show contig creation date");
		group.add(rbShowContigCreated);
		viewMenu.add(rbShowContigCreated);

		rbShowContigCreated.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.CONTIG_CREATED_DATE);
			}
		});

		JRadioButtonMenuItem rbShowContigUpdated = new JRadioButtonMenuItem(
				"Show contig updated date");
		group.add(rbShowContigUpdated);
		viewMenu.add(rbShowContigUpdated);

		rbShowContigUpdated.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.CONTIG_UPDATED_DATE);
			}
		});

		model.setDateColumn(ProjectTableModel.CONTIG_UPDATED_DATE);
		rbShowContigUpdated.setSelected(true);

		viewMenu.addSeparator();

		group = new ButtonGroup();

		JRadioButtonMenuItem rbShowAllContigs = new JRadioButtonMenuItem(
				"Show all contigs");
		group.add(rbShowAllContigs);
		viewMenu.add(rbShowAllContigs);

		rbShowAllContigs.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.showAllContigs();
			}
		});

		JRadioButtonMenuItem rbShowMultiReadContigs = new JRadioButtonMenuItem(
				"Show contigs with more than one read");
		group.add(rbShowMultiReadContigs);
		viewMenu.add(rbShowMultiReadContigs);

		rbShowMultiReadContigs.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.showMultiReadContigs();
			}
		});

		model.showAllContigs();
		rbShowAllContigs.setSelected(true);
	}
	
	private void createProjectMenu() {
		JMenu projectMenu = createMenu("Project", KeyEvent.VK_P, "Project");
		menubar.add(projectMenu);
		
		projectMenu.add(actionImportReads);
		
		projectMenu.getPopupMenu().addPopupMenuListener(new PopupMenuListener() {
			public void popupMenuCanceled(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
				actionImportReads.setEnabled(table.getSelectedRowCount() == 1);
			}
			
		});
	}

	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);		
		
		helpMenu.add(actionHelp);
	}

	private void viewSelectedProjects() {
		table.displaySelectedProjects();
	}
	
	private void importReadsIntoProject() {
		JOptionPane.showMessageDialog(
				this,
				"The user will be invited to import a set of reads into the selected project",
				"Import reads", JOptionPane.INFORMATION_MESSAGE,
				null);
	}

	public JMenuBar getMenuBar() {
		return menubar;
	}

	public JToolBar getToolBar() {
		return null;
	}
	
	public void closeResources() {
		// Does nothing
	}
	
	public void refresh() {
		table.refresh();
	}
	
	public String toString() {
		return "ProjectTablePanel[organism=" + adb.getName() + "]";
	}
}
