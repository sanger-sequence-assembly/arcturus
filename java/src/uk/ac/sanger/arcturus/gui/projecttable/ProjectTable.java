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

import java.awt.*;
import java.awt.event.*;

import javax.swing.*;
import javax.swing.event.PopupMenuEvent;
import javax.swing.event.PopupMenuListener;
import javax.swing.table.*;

import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.gui.*;

import uk.ac.sanger.arcturus.gui.contigtable.ContigTablePanel;
import uk.ac.sanger.arcturus.gui.scaffoldtable.ScaffoldTableFrame;
import uk.ac.sanger.arcturus.people.*;

import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ProjectTable extends SortableTable {
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected Project projectForPopup;
	protected int rowForPopup;
	protected int columnForPopup;

	protected JMenuItem itemUnlockProject = new JMenuItem("Unlock");
	protected JMenuItem itemLockAsOwner = new JMenuItem("Set owner lock");
	protected JMenuItem itemLockAsMe = new JMenuItem("Acquire lock");
	
	protected JMenuItem itemSetOwner = new JMenuItem("Change owner...");

	protected JPopupMenu popupLock = new JPopupMenu();
	protected JPopupMenu popupOwner = new JPopupMenu();
	
	protected Person me;
	protected ArcturusDatabase adb;
	
	protected Person[] allUsers = null;

	public ProjectTable(ProjectTableModel ptm) throws ArcturusDatabaseException {
		super((SortableTableModel) ptm);

		adb = ptm.adb;
		
		me = adb.findMe();

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

		createPopupMenus();
		

		allUsers = adb.getAllUsers(true);
	}

	private void createPopupMenus() throws ArcturusDatabaseException {
		popupLock.add(itemUnlockProject);
		popupLock.addSeparator();
		popupLock.add(itemLockAsOwner);
		popupLock.add(itemLockAsMe);

		itemUnlockProject.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				unlockProject();
			}
		});

		itemLockAsOwner.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				lockProjectAsOwner();
			}
		});

		itemLockAsMe.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				lockProjectAsMe();
			}
		});

		popupLock.addPopupMenuListener(new PopupMenuListener() {
			public void popupMenuCanceled(PopupMenuEvent e) {
				// Do nothing
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
				// Do nothing
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
				try {
					updatePopupMenu();
				} catch (ArcturusDatabaseException e1) {
					Arcturus.logWarning("Failed to update project table popup menu", e1);
				}
			}
		});
		
		itemSetOwner.setEnabled(adb.isCoordinator());
		
		popupOwner.add(itemSetOwner);
		
		itemSetOwner.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				displaySetOwnerDialog();
			}
		});	
	}

	private void updatePopupMenu() throws ArcturusDatabaseException {
		boolean noOwner = projectForPopup.isUnowned();

		String pname = projectForPopup.getName();

		itemUnlockProject.setEnabled(adb.canUserUnlockProject(projectForPopup, me));
		
		itemUnlockProject.setText("Unlock " + pname);


		itemLockAsOwner.setEnabled(adb.canUserLockProjectForOwner(projectForPopup, me) &&
					!projectForPopup.isMine());

		itemLockAsOwner.setText(noOwner ? "(" + pname
				+ " has no owner)" : "Set lock on " + pname + " for "
				+ projectForPopup.getOwner().getName());


		itemLockAsMe.setEnabled(adb.canUserLockProject(projectForPopup, me));
		
		itemLockAsMe.setText("Acquire lock on " + pname);
	}
	
	private void displaySetOwnerDialog() {
		Person currentOwner = projectForPopup.getOwner();
		
		Component frame = SwingUtilities.getRoot(this);
		
		Person newOwner = (Person)JOptionPane.showInputDialog(
                frame,
                "Please select an owner for the project",
                "Change project owner",
                JOptionPane.PLAIN_MESSAGE,
                null,
                allUsers,
                currentOwner);
		
		if (newOwner != null && newOwner != currentOwner)
			getModel().setValueAt(newOwner, rowForPopup, columnForPopup);

	}

	private void handleCellMouseClick(MouseEvent event) {
		Point point = event.getPoint();

		int column = columnAtPoint(point);
		columnForPopup = convertColumnIndexToModel(column);
	
		if (event.isPopupTrigger()) {
			rowForPopup = rowAtPoint(point);
			ProjectProxy proxy = ((ProjectTableModel) getModel())
					.getProjectAtRow(rowForPopup);
			projectForPopup = proxy.getProject();

			switch (columnForPopup) {
				case ProjectTableModel.LOCKED_COLUMN:
					popupLock.show(event.getComponent(), event.getX(), event.getY());
					break;
					
				case ProjectTableModel.OWNER_COLUMN:
					popupOwner.show(event.getComponent(), event.getX(), event.getY());
					break;
			}
		} else if (event.getID() == MouseEvent.MOUSE_CLICKED
				&& event.getButton() == MouseEvent.BUTTON1
				&& columnForPopup != ProjectTableModel.OWNER_COLUMN
				&& event.getClickCount() == 2) {
			displaySelectedProjects();
		}
	}

	protected void unlockProject() {
		getModel().setValueAt(null, rowForPopup, columnForPopup);
	}

	protected void lockProjectAsMe() {
		getModel().setValueAt(me, rowForPopup, columnForPopup);
	}

	protected void lockProjectAsOwner() {
		getModel().setValueAt(projectForPopup.getOwner(), rowForPopup, columnForPopup);
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
		
		int fontStyle = Font.PLAIN;

		if (proxy.isMine())
			fontStyle |= Font.BOLD;
		
		if (proxy.getProject().isRetired())
			fontStyle |= Font.ITALIC;
		
		if (fontStyle != Font.PLAIN)
			c.setFont(c.getFont().deriveFont(fontStyle));
		
		if (proxy.isImporting() || proxy.isExporting())
			c.setForeground(Color.lightGray);

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

	public ProjectProxy getSelectedProject() {
		int[] indices = getSelectedRows();

		switch (indices.length) {
			case 1:
				return (ProjectProxy) ((ProjectTableModel) getModel())
						.elementAt(indices[0]);

			default:
				return null;
		}
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

		ContigTablePanel ctp = null;
		
		try {
			ctp = new ContigTablePanel(mtp, projects);
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to create contig table panel", e);
		}

		if (ctp != null) {
			mtp.add(title, ctp);

			JFrame frame = (JFrame) SwingUtilities.getRoot(mtp);
			frame.pack();

			mtp.setSelectedComponent(ctp);
		}
	}

	public void scaffoldSelectedProjects() {
		int[] indices = getSelectedRows();

		if (indices.length == 0)
			return;

		String title = "Scaffold:";

		ProjectTableModel ptm = (ProjectTableModel) getModel();

		Set<Project> projects = new HashSet<Project>();

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
