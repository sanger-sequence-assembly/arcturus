package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;

import java.awt.BorderLayout;
import java.awt.event.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.data.*;

public class ContigTablePanel extends JPanel implements MinervaClient {
	private ContigTable table = null;
	private ContigTableModel model = null;
	private JMenuBar menubar = new JMenuBar();

	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionExportAsCAF ;
	private MinervaAbstractAction actionExportAsFasta;
	private MinervaAbstractAction actionViewContigs;
	
	private String projectlist;

	public ContigTablePanel(Project[] projects) {
		super(new BorderLayout());

		projectlist = (projects != null && projects.length > 0) ?
				projects[0].getName() : "[null]";
		
		for (int i = 1; i < projects.length; i++)
			projectlist += "," + projects[i].getName();
		
		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane, BorderLayout.CENTER);

		createActions();

		createMenus();
	}

	private void createActions() {
		actionClose = new MinervaAbstractAction("Close", null,
				"Close this window", new Integer(KeyEvent.VK_C), 
				KeyStroke.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				closePanel();
			}
		};

		actionExportAsCAF = new MinervaAbstractAction("Export as CAF", null,
				"Export contigs as CAF", new Integer(KeyEvent.VK_E),
				KeyStroke.getKeyStroke(KeyEvent.VK_E, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsCAF();
			}
		};

		actionExportAsCAF.setEnabled(false);

		actionExportAsFasta = new MinervaAbstractAction("Export as FASTA",
				null, "Export contigs as FASTA", new Integer(KeyEvent.VK_F),
				KeyStroke.getKeyStroke(KeyEvent.VK_F, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsFasta();
			}
		};

		actionExportAsFasta.setEnabled(false);

		actionViewContigs = new MinervaAbstractAction("Open selected contigs",
				null, "Open selected contigs", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				viewSelectedContigs();
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

		fileMenu.add(actionViewContigs);

		fileMenu.addSeparator();

		fileMenu.add(actionClose);

		fileMenu.addSeparator();

		fileMenu.add(actionExportAsCAF);

		fileMenu.add(actionExportAsFasta);

		fileMenu.addSeparator();

		fileMenu.add(Minerva.getQuitAction());
	}

	private void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	private void exportAsCAF() {
		JOptionPane.showMessageDialog(this,
				"The selected contigs will be exported as a CAF file",
				"Export as CAF", JOptionPane.INFORMATION_MESSAGE, null);
	}

	private void exportAsFasta() {
		JOptionPane.showMessageDialog(this,
				"The selected contigs will be exported as a FASTA file",
				"Export as FASTA", JOptionPane.INFORMATION_MESSAGE, null);
	}

	private void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}

	private void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);

		viewMenu.add(actionViewContigs);
	}

	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);
	}

	private void viewSelectedContigs() {
		JOptionPane.showMessageDialog(
						this,
						"The selected contigs will be displayed in a colourful and informative way",
						"Display contigs", JOptionPane.INFORMATION_MESSAGE,
						null);
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
		return "ContigTablePanel[projects=" + projectlist + "]";
	}
}
