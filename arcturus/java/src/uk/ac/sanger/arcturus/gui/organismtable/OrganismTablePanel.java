package uk.ac.sanger.arcturus.gui.organismtable;

import javax.swing.*;
import java.awt.event.*;

import java.awt.BorderLayout;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.gui.*;

public class OrganismTablePanel extends JPanel implements MinervaClient {
	protected OrganismTable table = null;
	protected JMenuBar menubar = new JMenuBar();

	public OrganismTablePanel(ArcturusInstance instance) {
		super(new BorderLayout());

		OrganismTableModel model = new OrganismTableModel(instance);

		table = new OrganismTable(model);

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane);

		createMenus();
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

		fileMenu.add(new ViewOrganismAction("Open selected organism(s)"));

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

		viewMenu.add(new ViewOrganismAction("View selected organism(s)"));
	}

	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);
	}

	class ViewOrganismAction extends AbstractAction {
		public ViewOrganismAction(String name) {
			super(name);
		}

		public void actionPerformed(ActionEvent event) {
			table.displaySelectedOrganisms();
		}
	}

	public JMenuBar getMenuBar() {
		return menubar;
	}

	public JToolBar getToolBar() {
		return null;
	}
}
