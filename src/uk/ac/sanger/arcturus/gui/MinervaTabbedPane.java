package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.sql.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.gui.projecttable.ProjectTablePanel;
import uk.ac.sanger.arcturus.gui.importreads.ImportReadsPanel;

public class MinervaTabbedPane extends JTabbedPane implements MinervaClient {
	private ArcturusDatabase adb;
	private ProjectTablePanel ptp;
	private ImportReadsPanel irp;
	private JMenuBar menubar = new JMenuBar();
	
	private MinervaAbstractAction actionShowProjectList;
	private MinervaAbstractAction actionShowImportReadsPanel;
	private MinervaAbstractAction actionClose;

	public MinervaTabbedPane(ArcturusDatabase adb) {
		super();
		this.adb = adb;
		
		createActions();
		
		createMenu();
	}
	
	private void createActions() {
		actionShowProjectList = new MinervaAbstractAction("Open project list",
				null, "Open project list", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				showProjectTablePanel();
			}
		};
		
		actionShowImportReadsPanel = new MinervaAbstractAction("Import reads",
				null, "Open read import window", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				showImportReadsPanel();
			}
		};
		
		actionClose = new MinervaAbstractAction("Close", null, "Close this window",
				new Integer(KeyEvent.VK_C),
				KeyStroke.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
					public void actionPerformed(ActionEvent e) {
						closeParentFrame();
					}			
		};
	}
	
	private void createMenu() {
		createFileMenu();
		menubar.add(Box.createHorizontalGlue());
		createHelpMenu();
	}

	private void createFileMenu() {
		JMenu fileMenu = createMenu("File", KeyEvent.VK_F, "File");
		menubar.add(fileMenu);
		
		fileMenu.add(actionShowProjectList);
		
		fileMenu.addSeparator();
				
		fileMenu.add(actionClose);
		
		fileMenu.addSeparator();
		
		fileMenu.add(Minerva.getQuitAction());
	}
	
	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);		
	}

	private JMenu createMenu(String name, int mnemonic, String description) {
		JMenu menu = new JMenu(name);

		menu.setMnemonic(mnemonic);

		if (description != null)
			menu.getAccessibleContext().setAccessibleDescription(description);

		return menu;
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

	public ProjectTablePanel showProjectTablePanel() {
		if (ptp == null)
			ptp = new ProjectTablePanel(adb);

		if (indexOfComponent(ptp) < 0)
			insertTab("Projects", null, ptp, "All projects", 0);

		return ptp;
	}

	public ImportReadsPanel showImportReadsPanel() {
		if (irp == null)
			irp = new ImportReadsPanel(adb);
		
		if (indexOfComponent(irp) < 0)
			addTab("Import reads", null, irp, "Import reads");
		
		return irp;
	}

	public void closeResources() {
		try {
			adb.getConnection().close();
		}
		catch (SQLException sqle) {
			Arcturus.logWarning(sqle);
		}
	}
	
	private void closeParentFrame() {
		closeResources();
		JFrame frame = (JFrame)SwingUtilities.getRoot(this);
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
	}
	
	public static MinervaTabbedPane getTabbedPane(Component component) {
		Container c = component.getParent();
		
		while (c != null && !(c instanceof Frame)) {
			if (c instanceof MinervaTabbedPane)
				return (MinervaTabbedPane)c;
			
			c = c.getParent();
		}
		
		return null;
	}

	public void refresh() {
		// Does nothing
	}
}
