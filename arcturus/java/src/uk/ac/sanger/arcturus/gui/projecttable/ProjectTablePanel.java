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
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;

public class ProjectTablePanel extends MinervaPanel implements ProjectChangeEventListener {
	protected ProjectTable table = null;
	protected ProjectTableModel model = null;

	protected MinervaAbstractAction actionViewProject;
	protected MinervaAbstractAction actionExportToGap4;
	protected MinervaAbstractAction actionImportFromGap4;
	protected MinervaAbstractAction actionExportForAssembly;

	public ProjectTablePanel(ArcturusDatabase adb, MinervaTabbedPane parent) {
		super(new BorderLayout(), parent, adb);
		
		adb.addProjectChangeEventListener(this);

		model = new ProjectTableModel(adb);

		table = new ProjectTable(model);
		table.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);

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

		actionExportToGap4 = new MinervaAbstractAction(
				"Export project to Gap4", null,
				"Export selected project to Gap4", new Integer(KeyEvent.VK_E),
				KeyStroke.getKeyStroke(KeyEvent.VK_E, ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportToGap4();
			}
		};

		actionImportFromGap4 = new MinervaAbstractAction(
				"Import project from Gap4", null,
				"Import selected project from Gap4",
				new Integer(KeyEvent.VK_I), KeyStroke.getKeyStroke(
						KeyEvent.VK_I, ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				importFromGap4();
			}
		};

		actionExportForAssembly = new MinervaAbstractAction(
				"Export project for assembly", null,
				"Export selected project for assembly", new Integer(
						KeyEvent.VK_A), KeyStroke.getKeyStroke(KeyEvent.VK_Y,
						ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportForAssembly();
			}
		};
	}

	protected void updateActions() {
		int rowcount = table.getSelectedRowCount();

		actionExportToGap4.setEnabled(rowcount == 1);
		actionImportFromGap4.setEnabled(rowcount == 1);
		actionExportForAssembly.setEnabled(rowcount == 1);

		actionViewProject.setEnabled(rowcount > 0);
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

		projectMenu.add(actionExportToGap4);
		projectMenu.add(actionImportFromGap4);

		projectMenu.addSeparator();

		projectMenu.add(actionExportForAssembly);

		projectMenu.getPopupMenu().addPopupMenuListener(
				new PopupMenuListener() {
					public void popupMenuCanceled(PopupMenuEvent e) {
					}

					public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
					}

					public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
						updateActions();
					}

				});
	}

	protected void viewSelectedProjects() {
		table.displaySelectedProjects();
	}

	protected void exportToGap4() {
		ProjectProxy proxy = table.getSelectedProject();
		
		if (proxy != null)
			notYetImplemented("Exporting " + proxy.getName() + " to a Gap4 database");
	}

	protected void importFromGap4() {
		ProjectProxy proxy = table.getSelectedProject();
		
		if (proxy != null)
			notYetImplemented("Importing " + proxy.getName() + " from a Gap4 database");
	}

	protected void exportForAssembly() {
		ProjectProxy proxy = table.getSelectedProject();
		
		if (proxy != null)
			notYetImplemented("Exporting " + proxy.getName() + " for incremental assembly");
	}

	protected void notYetImplemented(String message) {
		showMessage("For your information", "*** THIS FEATURE IS NOT YET IMPLEMENTED ***\n" + message);
	}
	
	protected void showMessage(String caption, String message) {
		JOptionPane.showMessageDialog(this,
				message,
				caption, JOptionPane.INFORMATION_MESSAGE, null);
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
			Arcturus.logWarning("Error when attempting to print project table",
					e);
		}
	}

	public void projectChanged(ProjectChangeEvent event) {
		refresh();
	}
}