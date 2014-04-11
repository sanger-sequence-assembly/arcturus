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

package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import java.awt.BorderLayout;
import java.awt.event.*;
import java.util.List;
import java.util.Vector;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.contigtransfer.ContigTransferMenu;
import uk.ac.sanger.arcturus.gui.common.contigtransfer.ContigTransferSource;
import uk.ac.sanger.arcturus.gui.scaffold.ScaffoldWorker;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.data.*;

public class ContigTablePanel extends MinervaPanel implements ProjectChangeEventListener, ContigTransferSource {
	protected ContigTable table = null;
	protected ContigTableModel model = null;

	protected JCheckBoxMenuItem cbGroupByProject = new JCheckBoxMenuItem(
			"Group by project");

	protected JFileChooser fileChooser = new JFileChooser();

	protected MinervaAbstractAction actionExportAsCAF;
	protected MinervaAbstractAction actionExportAsFasta;
	protected MinervaAbstractAction actionViewContigs;
	protected MinervaAbstractAction actionScaffoldContig;
	
	protected ContigTransferMenu xferMenu;
	
	protected JPopupMenu contigPopupMenu = new JPopupMenu();
	
	protected String projectlist;

	protected boolean oneProject;
	
	public ContigTablePanel(MinervaTabbedPane parent, Project[] projects) {
		super(parent, projects[0].getArcturusDatabase());
		
		xferMenu = new ContigTransferMenu("Transfer selected contigs to", this, adb);
		
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
		
		xferMenu.refreshMenu();
		
		contigPopupMenu.add(actionViewContigs);

		contigPopupMenu.addSeparator();

		contigPopupMenu.add(actionExportAsCAF);

		contigPopupMenu.add(actionExportAsFasta);
		
		contigPopupMenu.addSeparator();
		
		contigPopupMenu.add(actionScaffoldContig);
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
		xferMenu.refreshMenu();
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

	public List<Contig> getSelectedContigs() {
		int[] indices = table.getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) table.getModel();
		
		List<Contig> contigs = new Vector<Contig>(indices.length);
		
		for (int i = 0; i < indices.length; i++)
			contigs.add((Contig)ctm.elementAt(indices[i]));
		
		return contigs;
	}
}
