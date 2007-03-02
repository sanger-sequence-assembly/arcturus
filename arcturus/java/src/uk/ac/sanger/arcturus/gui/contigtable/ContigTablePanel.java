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
	
	public ContigTablePanel(Project[] projects) {
		super(new BorderLayout());
		
		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		JScrollPane scrollpane = new JScrollPane(table);
		
		add(scrollpane, BorderLayout.CENTER);
		
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
		
		fileMenu.add(new ViewContigAction("Open selected project(s)"));
		
		fileMenu.addSeparator();
				
		fileMenu.add(new MinervaAbstractAction("Close", null, "Close this window",
				new Integer(KeyEvent.VK_C),
				KeyStroke.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
					public void actionPerformed(ActionEvent e) {
						closePanel();
					}			
		});
	
		fileMenu.addSeparator();
		
		fileMenu.add(Minerva.getQuitAction());
	}

	private void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	private void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}
	
	private void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);

		viewMenu.add(new ViewContigAction("View selected contig(s)"));
	}
	
	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);		
	}

	class ViewContigAction extends AbstractAction {
		public ViewContigAction(String name) {
			super(name);
		}

		public void actionPerformed(ActionEvent event) {
		}
	}

	public JMenuBar getMenuBar() {
		return menubar;
	}

	public JToolBar getToolBar() {
		return null;
	}

}
