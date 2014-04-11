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

package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.HashMap;
import java.util.Map;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.gui.oligofinder.OligoFinderPanel;
import uk.ac.sanger.arcturus.gui.projecttable.ProjectTablePanel;
import uk.ac.sanger.arcturus.gui.importreads.ImportReadsPanel;
import uk.ac.sanger.arcturus.gui.checkconsistency.CheckConsistencyPanel;
import uk.ac.sanger.arcturus.gui.consensusreadimporter.ConsensusReadImporterPanel;
import uk.ac.sanger.arcturus.gui.contigtransfertable.AdministratorContigTransferTablePanel;
import uk.ac.sanger.arcturus.gui.contigtransfertable.ContigTransferTablePanel;
import uk.ac.sanger.arcturus.gui.createcontigtransfers.CreateContigTransferPanel;
import uk.ac.sanger.arcturus.gui.readfinder.ReadFinderPanel;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.ScaffoldManagerPanel;
import uk.ac.sanger.arcturus.gui.siblingreadfinder.SiblingReadFinderPanel;
import uk.ac.sanger.arcturus.gui.contigfinder.ContigFinderPanel;
import uk.ac.sanger.arcturus.gui.reportrunner.ReportRunnerPanel;

public class MinervaTabbedPane extends JTabbedPane implements MinervaClient {
	protected ArcturusDatabase adb;

	protected JMenuBar menubar = new JMenuBar();

	protected MinervaAbstractAction actionShowProjectList;
	protected MinervaAbstractAction actionClose;

	protected Map<PermanentView, MinervaPanel> permanentComponents =
		new HashMap<PermanentView, MinervaPanel>();

	class PermanentView {
		final private Class panelClass;
		private String menuText;
		private String tabText;
		private String description;
		private Integer mnemonic;
		private KeyStroke accelerator;
		private boolean isAdministratorView;

		public PermanentView(Class panelClass, String menuText, String tabText,
				String description, int mnemonic, KeyStroke accelerator,
				boolean isAdministratorView) {
			this.panelClass = panelClass;
			this.menuText = menuText;
			this.tabText = tabText;
			this.description = description;
			this.mnemonic = mnemonic;
			this.accelerator = accelerator;
			this.isAdministratorView = isAdministratorView;
		}

		public Class getPanelClass() {
			return panelClass;
		}

		public String getMenuText() {
			return menuText;
		}

		public String getTabText() {
			return tabText;
		}

		public String getDescription() {
			return description;
		}

		public Integer getMnemonic() {
			return mnemonic;
		}

		public KeyStroke getAccelerator() {
			return accelerator;
		}

		public boolean isAdministratorView() {
			return isAdministratorView;
		}
	}
	
	private final PermanentView projectTableView = 
		new PermanentView(
				ProjectTablePanel.class,
				"Open project list",
				"Projects",
				"Open list of all projects",
				KeyEvent.VK_O,
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK),
				false);

	private PermanentView[] permanentViews = {			
			new PermanentView(
					ImportReadsPanel.class,
					"Import reads",
					"Import reads",
					"Import reads into project",
					KeyEvent.VK_I,
					KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					OligoFinderPanel.class,
					"Find oligos",
					"Find Oligos",
					"Find oligo sequences in contigs and reads",
					KeyEvent.VK_L,
					KeyStroke.getKeyStroke(KeyEvent.VK_L, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					ReadFinderPanel.class,
					"Find reads",
					"Find reads",
					"Find one or more reads",
					KeyEvent.VK_F,
					KeyStroke.getKeyStroke(KeyEvent.VK_F, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					SiblingReadFinderPanel.class,
					"Find free sibling reads for project",
					"Find free sibling reads",
					"Find free sibling reads for project",
					KeyEvent.VK_S,
					KeyStroke.getKeyStroke(KeyEvent.VK_S, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					ContigFinderPanel.class,
					"Find contigs",
					"Find contigs",
					"Find one or more contigs",
					KeyEvent.VK_C,
					KeyStroke.getKeyStroke(KeyEvent.VK_M, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					CreateContigTransferPanel.class,
					"Create contig transfers",
					"Create contig transfers",
					"Create one or more contig transfers",
					KeyEvent.VK_R,
					KeyStroke.getKeyStroke(KeyEvent.VK_R, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					ContigTransferTablePanel.class,
					"Show contig transfers",
					"Contig transfers",
					"Show contig transfers",
					KeyEvent.VK_T,
					KeyStroke.getKeyStroke(KeyEvent.VK_T, ActionEvent.CTRL_MASK),
					false),
					
			new PermanentView(
					AdministratorContigTransferTablePanel.class,
					"Show all contig transfers",
					"All contig transfers",
					"Show all contig transfers",
					KeyEvent.VK_H,
					KeyStroke.getKeyStroke(KeyEvent.VK_H, ActionEvent.CTRL_MASK),
					true),
					
			new PermanentView(
					ConsensusReadImporterPanel.class,
					"Import reads from a FASTA file",
					"Import FASTA file",
					"Import reads from a FASTA file",
					KeyEvent.VK_G,
					KeyStroke.getKeyStroke(KeyEvent.VK_F, ActionEvent.ALT_MASK),
					false),
									
			new PermanentView(
					ScaffoldManagerPanel.class,
					"Show all scaffolds",
					"All scaffolds",
					"Show all scaffolds",
					KeyEvent.VK_A,
					KeyStroke.getKeyStroke(KeyEvent.VK_A, ActionEvent.CTRL_MASK),
					false),
		
			new PermanentView(
					CheckConsistencyPanel.class,
					"Check database consistency",
					"Database consistency",
					"Check the consistency of the database",
					KeyEvent.VK_D,
					KeyStroke.getKeyStroke(KeyEvent.VK_D, ActionEvent.CTRL_MASK),
					false),
			
			new PermanentView(
					ReportRunnerPanel.class,
					"Run reports about projects",
					"Project reports",
					"Run reports about projects",
					KeyEvent.VK_U,
					KeyStroke.getKeyStroke(KeyEvent.VK_U, ActionEvent.CTRL_MASK),
					false)
	};

	public MinervaTabbedPane(ArcturusDatabase adb) {
		super();
		this.adb = adb;
		
		createActions();

		createMenu();
	}

	protected void createActions() {
		actionShowProjectList = createAction(projectTableView);

		actionClose = new MinervaAbstractAction("Close", null,
				"Close this window", new Integer(KeyEvent.VK_C), KeyStroke
						.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				closeParentFrame();
			}
		};
	}
	
	private MinervaAbstractAction createAction(final PermanentView view) {
		return new MinervaAbstractAction(view.getMenuText(), null, view.getDescription(),
				new Integer(view.getMnemonic()), view.getAccelerator()) {
			public void actionPerformed(ActionEvent e) {
				showMinervaPanel(view);
			}			
		};
	}
	
	@SuppressWarnings("unchecked")
	private void showMinervaPanel(final PermanentView view) {
		MinervaPanel panel = permanentComponents.get(view);

		if (panel == null) {
			Class panelClass = view.getPanelClass();

			try {
				panel = createMinervaPanel(panelClass);
				
				if (panel != null)
					permanentComponents.put(view, panel);
			}
			catch (Exception e) {
				Arcturus.logSevere("Failed to create a " + panelClass.getName() + " view", e);
				return;
			}
		}

		if (indexOfComponent(panel) < 0)	
			addTab(view.getTabText(), null, panel, view.getDescription());
		
		setSelectedComponent(panel);
	}
	
	private MinervaPanel createMinervaPanel(Class<MinervaPanel> panelClass)
		throws SecurityException, NoSuchMethodException, IllegalArgumentException,
			InstantiationException, IllegalAccessException, InvocationTargetException {
		if (!MinervaPanel.class.isAssignableFrom(panelClass))
			throw new IllegalArgumentException("Class " + panelClass.getName() + " is not a sub-class of MinervaPanel");
		
		Constructor<MinervaPanel> ctor = panelClass.getConstructor(MinervaTabbedPane.class, ArcturusDatabase.class);

		MinervaPanel panel = ctor.newInstance(this, adb);
		
		return panel;
	}
	
	public void showProjectTable() {		
		showMinervaPanel(projectTableView);
	}

	protected void createMenu() {
		createFileMenu();
		menubar.add(Box.createHorizontalGlue());
		createHelpMenu();
	}

	protected void createFileMenu() {
		JMenu fileMenu = createMenu("File", KeyEvent.VK_F, "File");
		menubar.add(fileMenu);

		fileMenu.add(actionShowProjectList);

		fileMenu.addSeparator();

		fileMenu.add(actionClose);

		fileMenu.addSeparator();

		fileMenu.add(Minerva.getQuitAction());
	}

	protected void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);
	}

	protected JMenu createMenu(String name, int mnemonic, String description) {
		JMenu menu = new JMenu(name);

		menu.setMnemonic(mnemonic);

		if (description != null)
			menu.getAccessibleContext().setAccessibleDescription(description);

		return menu;
	}

	protected void addSharedFileMenuItems(JMenu menu) {
		boolean iAmCoordinator= false;
		
		try {
			iAmCoordinator = adb.isCoordinator();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to determine coordinator status", e);
		}
		
		for (int i = 0; i < permanentViews.length; i++) {
			PermanentView view = permanentViews[i];
			
			boolean canInclude = iAmCoordinator || !view.isAdministratorView();
			
			if (canInclude)
				menu.add(createAction(view));
		}
	}

	public JMenuBar getMenuBar() {
		Component component = getSelectedComponent();

		if (component != null && component instanceof MinervaClient)
			return ((MinervaClient) component).getMenuBar();
		else
			return menubar;
	}

	public JToolBar getToolBar() {
		Component component = getSelectedComponent();

		if (component != null && component instanceof MinervaClient)
			return ((MinervaClient) component).getToolBar();
		else
			return null;
	}

	public void addTab(String title, Component component) {
		addTab(title, null, component, title);
	}

	public void addTab(String title, Icon icon, Component component, String tip) {
		super.addTab(title, icon, component, tip);
		packFrame();
	}

	protected void packFrame() {
		JFrame frame = (JFrame) SwingUtilities.getRoot(this);
		
		if (frame != null)
			frame.pack();
	}

	public void closeResources() {
		adb.closeConnectionPool();
	}

	protected void closeParentFrame() {
		closeResources();
		JFrame frame = (JFrame) SwingUtilities.getRoot(this);
		frame.setVisible(false);
		frame.dispose();
	}

	/**
	 * Removes the specified Component from the JTabbedPane.
	 * 
	 * This method explicitly invokes fireStateChanged to overcome a bug in
	 * Sun's implementation of JTabbedPane which fails to fire a StateChanged
	 * event if the removed component is not the last tab.
	 */

	public void remove(Component c) {
		super.remove(c);
		fireStateChanged();

		if (!isPermanent(c) && c instanceof MinervaPanel)
			((MinervaPanel) c).closeResources();
	}

	protected boolean isPermanent(Component c) {
		return permanentComponents.containsValue(c);
	}

	public static MinervaTabbedPane getTabbedPane(Component component) {
		Container c = component.getParent();

		while (c != null && !(c instanceof Frame)) {
			if (c instanceof MinervaTabbedPane)
				return (MinervaTabbedPane) c;

			c = c.getParent();
		}

		return null;
	}

	public void refresh() {
		// Does nothing
	}

	public ArcturusDatabase getArcturusDatabase() {
		return adb;
	}
}
