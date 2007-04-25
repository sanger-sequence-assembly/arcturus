package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;
import javax.swing.event.PopupMenuEvent;
import javax.swing.event.PopupMenuListener;

import java.awt.*;
import java.awt.event.*;
import java.awt.print.PrinterException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.*;

public class ProjectTablePanel extends MinervaPanel {
	protected ProjectTable table = null;
	protected ProjectTableModel model = null;
	protected JMenuBar menubar = new JMenuBar();

	protected MinervaAbstractAction actionViewProject;

	ArcturusDatabase adb;

	public ProjectTablePanel(ArcturusDatabase adb, MinervaTabbedPane parent) {
		super(new BorderLayout(), parent);
		
		this.adb = adb;
		
		model = new ProjectTableModel(adb);

		table = new ProjectTable(model);
		table.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
		
		table.getSelectionModel().addListSelectionListener(new ListSelectionListener() {
			public void valueChanged(ListSelectionEvent e) {
				updateActions();
			}		
		});
		
		JScrollPane scrollpane = new JScrollPane(table);
		
		add(scrollpane, BorderLayout.CENTER);
		
		createActions();		
		createMenus();

		actionCloseView.setEnabled(false);
		
		updateActions();
	}
	
	protected void createActions() {
		actionViewProject = new MinervaAbstractAction("Open selected project",
				null, "Open selected project", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				viewSelectedProjects();
			}
		};
	}
	
	protected void updateActions() {
		boolean noneSelected = table.getSelectionModel().isSelectionEmpty();
		actionViewProject.setEnabled(!noneSelected);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionViewProject);
		return true;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
		menu.addSeparator();

		ButtonGroup group = new ButtonGroup();

		JRadioButtonMenuItem rbShowProjectDate = new JRadioButtonMenuItem(
				"Show project date");
		group.add(rbShowProjectDate);
		menu.add(rbShowProjectDate);

		rbShowProjectDate.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.PROJECT_UPDATED_DATE);
			}
		});

		JRadioButtonMenuItem rbShowContigCreated = new JRadioButtonMenuItem(
				"Show contig creation date");
		group.add(rbShowContigCreated);
		menu.add(rbShowContigCreated);

		rbShowContigCreated.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.CONTIG_CREATED_DATE);
			}
		});

		JRadioButtonMenuItem rbShowContigUpdated = new JRadioButtonMenuItem(
				"Show contig updated date");
		group.add(rbShowContigUpdated);
		menu.add(rbShowContigUpdated);

		rbShowContigUpdated.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.setDateColumn(ProjectTableModel.CONTIG_UPDATED_DATE);
			}
		});

		model.setDateColumn(ProjectTableModel.CONTIG_UPDATED_DATE);
		rbShowContigUpdated.setSelected(true);

		menu.addSeparator();

		group = new ButtonGroup();

		JRadioButtonMenuItem rbShowAllContigs = new JRadioButtonMenuItem(
				"Show all contigs");
		group.add(rbShowAllContigs);
		menu.add(rbShowAllContigs);

		rbShowAllContigs.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.showAllContigs();
			}
		});

		JRadioButtonMenuItem rbShowMultiReadContigs = new JRadioButtonMenuItem(
				"Show contigs with more than one read");
		group.add(rbShowMultiReadContigs);
		menu.add(rbShowMultiReadContigs);

		rbShowMultiReadContigs.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.showMultiReadContigs();
			}
		});

		model.showAllContigs();
		rbShowAllContigs.setSelected(true);
	}

	protected void createClassSpecificMenus() {
		createProjectMenu();
	}

	protected void createProjectMenu() {
		JMenu projectMenu = createMenu("Project", KeyEvent.VK_P, "Project");
		menubar.add(projectMenu);
		
		projectMenu.add(actionShowReadImporter);
		
		projectMenu.addSeparator();
		
		projectMenu.add(actionShowOligoFinder);
		
		projectMenu.getPopupMenu().addPopupMenuListener(new PopupMenuListener() {
			public void popupMenuCanceled(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
				int rowcount = table.getSelectedRowCount();
				actionShowReadImporter.setEnabled(rowcount == 1);
			}
			
		});
	}

	protected void viewSelectedProjects() {
		table.displaySelectedProjects();
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

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		try {
			table.print();
		} catch (PrinterException e) {
			Arcturus.logWarning("Error when attempting to print project table", e);
		}
	}
}
