package uk.ac.sanger.arcturus.gui;

import javax.swing.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.people.PeopleManager;
import uk.ac.sanger.arcturus.people.Person;

import java.awt.LayoutManager;
import java.awt.event.*;
import java.sql.SQLException;

public abstract class MinervaPanel extends JPanel implements MinervaClient {
	protected ArcturusDatabase adb;

	protected JMenuBar menubar = new JMenuBar();
	protected JToolBar toolbar = null;
	protected MinervaTabbedPane parent;

	protected MinervaAbstractAction actionCloseView;
	protected MinervaAbstractAction actionShowReadImporter;
	protected MinervaAbstractAction actionShowOligoFinder;
	protected MinervaAbstractAction actionShowReadFinder;
	protected MinervaAbstractAction actionShowContigTransfers;
	protected MinervaAbstractAction actionShowAllContigTransfers;
	protected MinervaAbstractAction actionShowCreateContigTransfer;
	protected MinervaAbstractAction actionCheckConsistency;
	protected MinervaAbstractAction actionPrint;
	protected MinervaAbstractAction actionRefresh;

	public MinervaPanel(LayoutManager layoutManager, MinervaTabbedPane parent,
			ArcturusDatabase adb) {
		super(layoutManager);
		this.parent = parent;
		this.adb = adb;
	}

	public MinervaPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		this((LayoutManager) null, parent, adb);
	}

	public JMenuBar getMenuBar() {
		return menubar;
	}

	public JToolBar getToolBar() {
		return toolbar;
	}

	public abstract void refresh();

	public abstract void closeResources();

	protected abstract void createActions();

	protected abstract void createClassSpecificMenus();

	protected abstract boolean addClassSpecificFileMenuItems(JMenu menu);

	protected abstract boolean isRefreshable();

	protected abstract void addClassSpecificViewMenuItems(JMenu menu);

	protected abstract void doPrint();

	protected Action getPrintAction() {
		return actionPrint;
	}

	protected void createMenus() {
		createFileMenu();
		createEditMenu();
		createViewMenu();

		createClassSpecificMenus();

		menubar.add(Box.createHorizontalGlue());

		createHelpMenu();
	}

	protected JMenu createMenu(String name, int mnemonic, String description) {
		JMenu menu = new JMenu(name);

		menu.setMnemonic(mnemonic);

		if (description != null)
			menu.getAccessibleContext().setAccessibleDescription(description);

		return menu;
	}

	protected void createFileMenu() {
		JMenu fileMenu = createMenu("File", KeyEvent.VK_F, "File");
		menubar.add(fileMenu);

		if (addClassSpecificFileMenuItems(fileMenu))
			fileMenu.addSeparator();

		addSharedFileMenuItems(fileMenu);

		fileMenu.addSeparator();

		actionPrint = new MinervaAbstractAction("Print...", null,
				"Print this view", new Integer(KeyEvent.VK_P), KeyStroke
						.getKeyStroke(KeyEvent.VK_P, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				doPrint();
			}
		};

		fileMenu.add(actionPrint);

		fileMenu.addSeparator();

		actionCloseView = new MinervaAbstractAction("Close", null,
				"Close this view", new Integer(KeyEvent.VK_C), KeyStroke
						.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				closePanel();
			}
		};

		fileMenu.add(actionCloseView);

		fileMenu.addSeparator();

		fileMenu.add(Minerva.getQuitAction());
	}

	private void closePanel() {
		if (Boolean.getBoolean("minerva.safemode")) {
			int rc = JOptionPane.showOptionDialog(this,
					"Do you REALLY want to close this view?", "Warning",
					JOptionPane.OK_CANCEL_OPTION, JOptionPane.WARNING_MESSAGE,
					null, null, null);

			if (rc != JOptionPane.OK_OPTION)
				return;
		}

		parent.remove(this);
	}

	protected void addSharedFileMenuItems(JMenu menu) {
		actionShowReadImporter = new MinervaAbstractAction(
				"Import reads", null, "Import reads into project",
				new Integer(KeyEvent.VK_I), KeyStroke.getKeyStroke(
						KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showImportReadsPanel();
			}
		};

		menu.add(actionShowReadImporter);

		actionShowOligoFinder = new MinervaAbstractAction("Find oligos", null,
				"Find oligos", new Integer(KeyEvent.VK_L), KeyStroke
						.getKeyStroke(KeyEvent.VK_L, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showOligoFinderPanel();
			}
		};

		menu.add(actionShowOligoFinder);

		actionShowReadFinder = new MinervaAbstractAction("Show read finder",
				null, "Show read finder", new Integer(KeyEvent.VK_F), KeyStroke
						.getKeyStroke(KeyEvent.VK_F, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showReadFinderPanel();
			}
		};

		menu.add(actionShowReadFinder);

		actionShowContigTransfers = new MinervaAbstractAction(
				"Show contigs transfers", null, "Show contig transfers",
				new Integer(KeyEvent.VK_T), KeyStroke.getKeyStroke(
						KeyEvent.VK_T, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showContigTransferTablePanel();
			}
		};

		actionShowAllContigTransfers = new MinervaAbstractAction(
				"Show all contigs transfers", null,
				"Show all contig transfers", new Integer(KeyEvent.VK_K),
				KeyStroke.getKeyStroke(KeyEvent.VK_K, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showAdminContigTransferTablePanel();
			}
		};

		if (adb.isCoordinator())
			menu.add(actionShowAllContigTransfers);
		else
			menu.add(actionShowContigTransfers);

		actionShowCreateContigTransfer = new MinervaAbstractAction(
				"Create contig transfers", null, "Create contig transfers",
				new Integer(KeyEvent.VK_R), KeyStroke.getKeyStroke(
						KeyEvent.VK_R, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showCreateContigTransferPanel();
			}
		};

		menu.add(actionShowCreateContigTransfer);

		actionCheckConsistency = new MinervaAbstractAction(
				"Check database consistency", null, "Check database consistency",
				new Integer(KeyEvent.VK_D), KeyStroke.getKeyStroke(
						KeyEvent.VK_D, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				parent.showCheckConsistencyPanel();
			}
		};

		menu.add(actionCheckConsistency);
	}

	protected void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}

	protected void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);

		actionRefresh = new MinervaAbstractAction(
				"Refresh", null, "Refresh the display", new Integer(
						KeyEvent.VK_R), KeyStroke.getKeyStroke(KeyEvent.VK_F5,
						0)) {
			public void actionPerformed(ActionEvent e) {
				refresh();
			}
		};

		viewMenu.add(actionRefresh);

		actionRefresh.setEnabled(isRefreshable());

		addClassSpecificViewMenuItems(viewMenu);
	}

	protected void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);

		MinervaAbstractAction actionHelp = new MinervaAbstractAction("Help",
				null, "Help", new Integer(KeyEvent.VK_H), KeyStroke
						.getKeyStroke(KeyEvent.VK_F1, 0)) {
			public void actionPerformed(ActionEvent e) {
				Minerva.displayHelp();
			}
		};

		helpMenu.add(actionHelp);
	}
}
