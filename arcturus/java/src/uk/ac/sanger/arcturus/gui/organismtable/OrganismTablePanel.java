package uk.ac.sanger.arcturus.gui.organismtable;

import javax.swing.*;
import java.awt.event.*;

import java.awt.BorderLayout;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.gui.*;

public class OrganismTablePanel extends JPanel implements MinervaClient {
	protected OrganismTable table = null;
	protected JMenuBar menubar = new JMenuBar();
	protected ArcturusInstance instance;

	private MinervaAbstractAction actionOpenOrganism;
	private MinervaAbstractAction actionHelp;

	public OrganismTablePanel(ArcturusInstance instance) {
		super(new BorderLayout());

		this.instance = instance;

		OrganismTableModel model = new OrganismTableModel(instance);

		table = new OrganismTable(model);

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane);

		createActions();

		createMenus();
	}

	private void createActions() {
		actionOpenOrganism = new MinervaAbstractAction(
				"Open selected organism", null, "Open selected organism",
				new Integer(KeyEvent.VK_O), KeyStroke.getKeyStroke(
						KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				openSelectedOrganism();
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

		fileMenu.add(actionOpenOrganism);

		fileMenu.addSeparator();

		fileMenu.add(Minerva.getQuitAction());
	}

	private void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}

	private void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);
	}

	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);
		
		helpMenu.add(actionHelp);
	}

	public void openSelectedOrganism() {
		table.displaySelectedOrganisms();
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
		return "OrganismTablePanel[instance=" + instance.getName() + "]";
	}
}
