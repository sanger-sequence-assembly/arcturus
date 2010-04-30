package uk.ac.sanger.arcturus.gui;

import javax.swing.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.awt.BorderLayout;
import java.awt.event.*;

public abstract class MinervaPanel extends JPanel implements MinervaClient {
	protected ArcturusDatabase adb;

	protected JMenuBar menubar = new JMenuBar();
	protected JToolBar toolbar = null;
	protected MinervaTabbedPane parent;

	protected MinervaAbstractAction actionCloseView;
	protected MinervaAbstractAction actionPrint;
	protected MinervaAbstractAction actionRefresh;

	public MinervaPanel(MinervaTabbedPane parent,
			ArcturusDatabase adb) {
		super(new BorderLayout());
		this.parent = parent;
		this.adb = adb;
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

		parent.addSharedFileMenuItems(fileMenu);

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
				"Close this view", new Integer(KeyEvent.VK_W), KeyStroke
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
