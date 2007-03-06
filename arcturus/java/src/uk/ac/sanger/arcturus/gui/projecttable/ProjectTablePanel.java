package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;

import java.awt.*;
import java.awt.event.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.*;

public class ProjectTablePanel extends JPanel implements MinervaClient  {
	private ProjectTable table = null;
	private ProjectTableModel model = null;
	private JMenuBar menubar = new JMenuBar();
	
	private JCheckBoxMenuItem cbAllowMultipleProjectSelection =
		new JCheckBoxMenuItem("Allow multiple projects to be selected");

	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionViewProject;
	
	ArcturusDatabase adb;

	public ProjectTablePanel(ArcturusDatabase adb) {
		super(new BorderLayout());
		
		this.adb = adb;
		
		model = new ProjectTableModel(adb);

		table = new ProjectTable(model);

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
	}
	
	private void createMenus() {
		createFileMenu();
		createEditMenu();
		createViewMenu();
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

		viewMenu.addSeparator();
		
		viewMenu.add(cbAllowMultipleProjectSelection);
		
		cbAllowMultipleProjectSelection.setSelected(false);
		
		cbAllowMultipleProjectSelection.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				boolean multiple = cbAllowMultipleProjectSelection.getState();
				table.setSelectionMode(multiple ?
						ListSelectionModel.MULTIPLE_INTERVAL_SELECTION : ListSelectionModel.SINGLE_SELECTION);
			}
		});
	}
	
	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);		
	}

	private void viewSelectedProjects() {
		table.displaySelectedProjects();
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
	
	public String toString() {
		return "ProjectTablePanel[organism=" + adb.getName() + "]";
	}
}
