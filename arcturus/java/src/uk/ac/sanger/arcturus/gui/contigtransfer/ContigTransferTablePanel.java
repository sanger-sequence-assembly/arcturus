package uk.ac.sanger.arcturus.gui.contigtransfer;

import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.PopupMenuListener;
import javax.swing.event.PopupMenuEvent;

import java.awt.BorderLayout;
import java.awt.event.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.importreads.*;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigTransferTablePanel extends JPanel implements MinervaClient {
	private ArcturusDatabase adb;

	private ContigTransferTable tableRequester = null;
	private ContigTransferTableModel modelRequester = null;

	private ContigTransferTable tableContigOwner = null;
	private ContigTransferTableModel modelContigOwner = null;
	
	private JMenuBar menubar = new JMenuBar();

	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionRefresh;
	private MinervaAbstractAction actionHelp;

	public ContigTransferTablePanel(ArcturusDatabase adb, Person user) {
		super();
		
		setLayout(new BoxLayout(this, BoxLayout.Y_AXIS));
		
		this.adb = adb;
		
		modelRequester = new ContigTransferTableModel(adb, user, ArcturusDatabase.USER_IS_REQUESTER);

		tableRequester = new ContigTransferTable(modelRequester);

		JScrollPane scrollpane1 = new JScrollPane(tableRequester);
		
		Border loweredetched1 = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		Border title1 = BorderFactory.createTitledBorder(loweredetched1, "Requests I have made");
		scrollpane1.setBorder(title1);
		
		add(scrollpane1);

		modelContigOwner = new ContigTransferTableModel(adb, user, ArcturusDatabase.USER_IS_CONTIG_OWNER);

		tableContigOwner = new ContigTransferTable(modelContigOwner);

		JScrollPane scrollpane2 = new JScrollPane(tableContigOwner);
		
		Border loweredetched2 = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		Border title2 = BorderFactory.createTitledBorder(loweredetched2, "Requests for contigs I own");
		scrollpane2.setBorder(title2);
		
		add(scrollpane2);
		
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
		
		actionRefresh = new MinervaAbstractAction("Refresh",
				null, "Refresh the display", new Integer(KeyEvent.VK_R),
				KeyStroke.getKeyStroke(KeyEvent.VK_F5, 0)) {
			public void actionPerformed(ActionEvent e) {
				refresh();
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

		//fileMenu.addSeparator();

		fileMenu.add(actionClose);

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
		
		viewMenu.add(actionRefresh);

		//viewMenu.addSeparator();
	}
	
	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);
		
		helpMenu.add(actionHelp);
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

	public void refresh() {
		tableRequester.refresh();
		tableContigOwner.refresh();
	}
}
