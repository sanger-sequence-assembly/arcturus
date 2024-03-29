// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.projecttable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;
import javax.swing.event.PopupMenuEvent;
import javax.swing.event.PopupMenuListener;

import java.awt.*;
import java.awt.event.*;
import java.awt.print.PrinterException;

import java.io.IOException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.InputDialog;
import uk.ac.sanger.arcturus.gui.common.InputDialog.Status;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventNotifier;

public class ProjectTablePanel extends MinervaPanel implements
		ProjectChangeEventListener {
	protected ProjectTable table = null;
	protected ProjectTableModel model = null;

	protected MinervaAbstractAction actionViewProject;
	protected MinervaAbstractAction actionExportToGap4;
	protected MinervaAbstractAction actionImportFromGap4;
	protected MinervaAbstractAction actionExportForAssembly;
	protected MinervaAbstractAction actionRetireProject;
	protected MinervaAbstractAction actionCreateNewProject;

	protected final NewProjectPanel panelNewProject;
	protected final InputDialog dialogNewProject;
	
	private final static boolean allowBinImport = Arcturus.getBoolean("project.allowbinimport");

	public ProjectTablePanel(MinervaTabbedPane parent, ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(parent, adb);

		panelNewProject = new NewProjectPanel(adb);
		dialogNewProject = new InputDialog(null, "Create a new project", panelNewProject);

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

		actionCreateNewProject = new MinervaAbstractAction(
				"Create a new project", null, "Create a new project",
				new Integer(KeyEvent.VK_N), KeyStroke.getKeyStroke(
						KeyEvent.VK_N, ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				createNewProject();
			}
		};

		actionRetireProject = new MinervaAbstractAction("Retire project", null,
				"Retire project", new Integer(KeyEvent.VK_R), KeyStroke
						.getKeyStroke(KeyEvent.VK_R, ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				retireProject();
			}
		};
	}

	protected void updateActions() {
		int rowcount = table.getSelectedRowCount();

		actionExportToGap4.setEnabled(rowcount == 1);
		actionImportFromGap4.setEnabled(false);
		actionExportForAssembly.setEnabled(rowcount == 1);

		actionViewProject.setEnabled(rowcount > 0);

		if (rowcount == 1) {
			ProjectProxy proxy = table.getSelectedProject();
			Project project = proxy.getProject();

			actionImportFromGap4.setEnabled(!project.isBin() || allowBinImport);

			boolean canRetire = false;

			try {
				canRetire = adb.canUserChangeProjectStatus(project) && !project.isRetired();
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to check whether user can change project status", e);
			}

			actionRetireProject.setEnabled(canRetire);
		} else
			actionRetireProject.setEnabled(false);

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

		menu.addSeparator();

		final JCheckBoxMenuItem cbShowRetiredProjects = new JCheckBoxMenuItem(
				"Show retired projects");
		cbShowRetiredProjects.setState(false);
		menu.add(cbShowRetiredProjects);

		cbShowRetiredProjects.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				model.showRetiredProjects(cbShowRetiredProjects.getState());
			}
		});
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

		projectMenu.addSeparator();

		projectMenu.add(actionRetireProject);

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

		projectMenu.addSeparator();

		projectMenu.add(actionCreateNewProject);
	}

	protected void viewSelectedProjects() {
		table.displaySelectedProjects();
	}

	protected boolean canExport(ProjectProxy proxy) {
		Person owner = proxy.getOwner();
		
		boolean coordinator = false;

		try {
			coordinator = adb.isCoordinator();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to check whether the user is a coordinator", e);
		}
		
		return coordinator || proxy.isMine() || owner == null;
	}

	protected void exportToGap4() {
		ProjectProxy proxy = table.getSelectedProject();

		String projectName = proxy.getName();

		Person owner = proxy.getOwner();

		if (!canExport(proxy)) {
			JOptionPane
					.showMessageDialog(
							this,
							"Project "
									+ projectName
									+ " belongs to "
									+ owner.getName()
									+ ".\nYou don't have permission to export it.\nPlease seek assistance.",
							"Cannot export project " + projectName,
							JOptionPane.ERROR_MESSAGE);

			return;

		}

		String directory = proxy.getProject().getDirectory();

		if (directory == null) {
			JOptionPane.showMessageDialog(this,
					"Could not find the home directory for " + projectName
							+ ".\nPlease seek assistance.",
					"Cannot export project " + projectName,
					JOptionPane.ERROR_MESSAGE);

			return;
		}

		int rc = JOptionPane.showConfirmDialog(this, "Do you wish to export "
				+ projectName + "?", "Export project?",
				JOptionPane.OK_CANCEL_OPTION);

		if (rc != JOptionPane.OK_OPTION)
			return;

		ProjectExporter exporter = new ProjectExporter(proxy, directory, this);

		exporter.start();
	}

	protected boolean canImport(ProjectProxy proxy) {
		Person owner = proxy.getOwner();
		
		boolean coordinator = false;
		
		try {
			coordinator = adb.isCoordinator();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to check whether the user is a coordinator", e);
		}

		return coordinator || proxy.isMine() || owner == null;
	}

	protected void importFromGap4() {
		ProjectProxy proxy = table.getSelectedProject();

		String projectName = proxy.getName();

		Person owner = proxy.getOwner();

		if (!canImport(proxy)) {
			JOptionPane
					.showMessageDialog(
							this,
							"Project "
									+ projectName
									+ " belongs to "
									+ owner.getName()
									+ ".\nYou don't have permission to import it.\nPlease seek assistance.",
							"Cannot import project " + projectName,
							JOptionPane.ERROR_MESSAGE);

			return;
		}

		String directory = proxy.getProject().getDirectory();

		if (directory == null) {
			JOptionPane.showMessageDialog(this,
					"Could not find the home directory for " + projectName
							+ ".\nPlease seek assistance.",
					"Cannot import project " + projectName,
					JOptionPane.ERROR_MESSAGE);

			return;
		}

		int rc = JOptionPane.showConfirmDialog(this, "Do you wish to import "
				+ projectName + "?", "Import project?",
				JOptionPane.OK_CANCEL_OPTION);

		if (rc != JOptionPane.OK_OPTION)
			return;

		ProjectImporter importer = new ProjectImporter(proxy, directory, this);

		importer.start();
	}

	protected void exportForAssembly() {
		ProjectProxy proxy = table.getSelectedProject();

		if (proxy != null)
			notYetImplemented("Exporting " + proxy.getName()
					+ " for incremental assembly");
	}

	protected void retireProject() {
		ProjectProxy proxy = table.getSelectedProject();
		Project project = proxy.getProject();
		String projectName = project.getName();
		
		try {
			boolean canChangeProject = adb.canUserChangeProjectStatus(project);

			if (!canChangeProject) {
				JOptionPane.showMessageDialog(this,
						"You do not have the authority to retire Project "
								+ projectName, "Cannot retire project "
								+ projectName, JOptionPane.ERROR_MESSAGE);

				return;
			}

			int rc = JOptionPane.showConfirmDialog(this,
					"Are you sure you want to retire project " + projectName
							+ "?", "Retire project?",
					JOptionPane.OK_CANCEL_OPTION);

			if (rc != JOptionPane.OK_OPTION)
				return;

			if (adb.retireProject(project))
				model.refresh();
		}
		catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to retre project", e);
		}
	}

	protected void notYetImplemented(String message) {
		showMessage("For your information",
				"*** THIS FEATURE IS NOT YET IMPLEMENTED ***\n" + message);
	}

	protected void showMessage(String caption, String message) {
		JOptionPane.showMessageDialog(this, message, caption,
				JOptionPane.INFORMATION_MESSAGE, null);
	}

	public void closeResources() {
		// Does nothing
	}

	public void refresh() throws ArcturusDatabaseException {
		model.refresh();
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
		if (event.getType() == ProjectChangeEvent.CONTIGS_CHANGED)
			try {
				refresh();
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("Failed to refresh project table panel", e);
			}
	}

	private void createNewProject() {
		panelNewProject.refresh();
		
		dialogNewProject.setOKActionEnabled(false);
		
		Status rc = dialogNewProject.showDialog();

		if (rc == Status.OK) {
			String name = panelNewProject.getName();
			String directory = panelNewProject.getDirectory();
			Person owner = panelNewProject.getOwner();
			Assembly assembly = panelNewProject.getAssembly();

			if (name == null || name.trim().length() == 0) {
				JOptionPane.showMessageDialog(this,
						"You did not specify the name of the project",
						"Failed to create the project",
						JOptionPane.WARNING_MESSAGE);

				return;
			}

			if (directory == null || directory.trim().length() == 0) {
				JOptionPane.showMessageDialog(this,
						"You did not specify a directory for the project",
						"Failed to create the project",
						JOptionPane.WARNING_MESSAGE);

				return;
			}

			try {
				if (adb.createNewProject(assembly, name.trim(), owner,
						directory)) {
					refresh();
					
					String message = "Successfully created project " + name;

					JOptionPane.showMessageDialog(this,
							message,
							"The project was created",
							JOptionPane.INFORMATION_MESSAGE);
					
					ProjectChangeEvent event = new ProjectChangeEvent(this, ProjectChangeEventNotifier.ANY_PROJECT, ProjectChangeEvent.CREATED);
					adb.notifyProjectChangeEventListeners(event, null);
				}
			} catch (ArcturusDatabaseException e) {
				Arcturus.logSevere(
								"An error occurred when trying to create a new project",
								e);
			}
			catch (IOException e) {
				Arcturus.logSevere(
						"An error occurred when trying to create a new project",
						e);
			}
		}

	}
}
