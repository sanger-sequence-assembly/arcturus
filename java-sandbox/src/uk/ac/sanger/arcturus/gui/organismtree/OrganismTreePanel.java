package uk.ac.sanger.arcturus.gui.organismtree;

import javax.naming.NamingException;
import javax.swing.*;
import javax.swing.event.TreeSelectionEvent;
import javax.swing.event.TreeSelectionListener;
import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.TreePath;
import javax.swing.tree.TreeSelectionModel;

import java.awt.event.*;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.data.Organism;
import uk.ac.sanger.arcturus.gui.*;

public class OrganismTreePanel extends JPanel implements MinervaClient {
	protected JTree tree = null;
	protected JMenuBar menubar = new JMenuBar();

	private MinervaAbstractAction actionOpenOrganism;
	private MinervaAbstractAction actionHelp;
	private MinervaAbstractAction actionRefresh;

	public OrganismTreePanel(ArcturusInstance[] instances) {
		super(new BorderLayout());

		OrganismTreeModel model = null;

		try {
			model = new OrganismTreeModel(instances);
		} catch (NamingException e) {
			Arcturus
					.logWarning(
							"An error occurred when creating an organism tree model",
							e);
		}

		tree = new JTree(model);

		tree.getSelectionModel().setSelectionMode(
				TreeSelectionModel.SINGLE_TREE_SELECTION);

		tree.addTreeSelectionListener(new TreeSelectionListener() {
			public void valueChanged(TreeSelectionEvent e) {
				DefaultMutableTreeNode node = (DefaultMutableTreeNode) tree
						.getLastSelectedPathComponent();

				if (node instanceof OrganismNode)
					actionOpenOrganism.setEnabled(true);
				else
					actionOpenOrganism.setEnabled(false);
			}
		});

		tree.addMouseListener(new MouseAdapter() {
			public void mousePressed(MouseEvent e) {
				if(e.getClickCount() != 2)
					return;
				
				TreePath path = tree.getPathForLocation(e.getX(), e.getY());
				
				if (path == null)
					return;
				
				DefaultMutableTreeNode node = (DefaultMutableTreeNode)path.getLastPathComponent();

				if (node instanceof OrganismNode)
					openOrganismForNode((OrganismNode)node);
			}
		});

		JScrollPane scrollpane = new JScrollPane(tree);

		add(scrollpane);

		createActions();

		createMenus();

		setPreferredSize(new Dimension(600, 400));
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

		actionOpenOrganism.setEnabled(false);

		actionRefresh = new MinervaAbstractAction("Refresh", null,
				"Refresh the display", new Integer(KeyEvent.VK_R), KeyStroke
						.getKeyStroke(KeyEvent.VK_F5, 0)) {
			public void actionPerformed(ActionEvent e) {
				refresh();
			}
		};

		actionRefresh.setEnabled(false);

		actionHelp = new MinervaAbstractAction("Help", null, "Help",
				new Integer(KeyEvent.VK_H), KeyStroke.getKeyStroke(
						KeyEvent.VK_F1, 0)) {
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

		viewMenu.add(actionRefresh);
	}

	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);

		helpMenu.add(actionHelp);
	}

	public void openSelectedOrganism() {
		DefaultMutableTreeNode node = (DefaultMutableTreeNode) tree
				.getLastSelectedPathComponent();

		if (node instanceof OrganismNode) {
			OrganismNode onode = (OrganismNode) node;
			openOrganismForNode(onode);
		}
	}
	
	private void openOrganismForNode(OrganismNode onode) {
		Organism organism = onode.getOrganism();

		try {
			Minerva.getInstance().createAndShowOrganismDisplay(organism);
		} catch (SQLException e) {
			Arcturus.logWarning("An error occurred when trying to display "
					+ organism.getName(), e);
		}
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
		return "OrganismTreePanel[instance=" + "<pookie>" + "]";
	}

	public void refresh() {
		// Does nothing
	}

}
