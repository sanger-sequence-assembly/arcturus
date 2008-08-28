package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.util.HashMap;
import java.util.Map;

import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.gui.oligofinder.OligoFinderPanel;
import uk.ac.sanger.arcturus.gui.projecttable.ProjectTablePanel;
import uk.ac.sanger.arcturus.gui.importreads.ImportReadsPanel;
import uk.ac.sanger.arcturus.gui.checkconsistency.CheckConsistencyPanel;
import uk.ac.sanger.arcturus.gui.contigtransfertable.ContigTransferTablePanel;
import uk.ac.sanger.arcturus.gui.createcontigtransfers.CreateContigTransferPanel;
import uk.ac.sanger.arcturus.gui.readfinder.ReadFinderPanel;

public class MinervaTabbedPane extends JTabbedPane implements MinervaClient {
	protected ArcturusDatabase adb;

	protected JMenuBar menubar = new JMenuBar();

	protected MinervaAbstractAction actionShowProjectList;
	protected MinervaAbstractAction actionClose;
	
	protected Map<String, MinervaPanel> permanentComponents = new HashMap<String, MinervaPanel>();

	private static final String PROJECT_TABLE = "PROJECT_TABLE";
	private static final String IMPORT_READS = "IMPORT_READS";
	private static final String READ_FINDER = "READ_FINDER";
	private static final String CONTIG_TRANSFER_TABLE = "CONTIG_TRANSFER_TABLE";
	private static final String ADMIN_CONTIG_TRANSFER_TABLE = "ADMIN_CONTIG_TRANSFER_TABLE";
	private static final String CREATE_CONTIG_TRANSFER = "CREATE_CONTIG_TRANSFER";
	private static final String OLIGO_FINDER = "OLIGO_FINDER";
	private static final String CHECK_CONSISTENCY = "CHECK_CONSISTENCY";

	public MinervaTabbedPane(ArcturusDatabase adb) {
		super();
		this.adb = adb;

		createActions();

		createMenu();
	}

	protected void createActions() {
		actionShowProjectList = new MinervaAbstractAction("Open project list",
				null, "Open project list", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				showProjectTablePanel();
			}
		};

		actionClose = new MinervaAbstractAction("Close", null,
				"Close this window", new Integer(KeyEvent.VK_C), KeyStroke
						.getKeyStroke(KeyEvent.VK_W, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				closeParentFrame();
			}
		};
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
		ProjectTablePanel ptp = (ProjectTablePanel)permanentComponents.get(PROJECT_TABLE);
		
		if (ptp == null) {
			ptp = new ProjectTablePanel(adb, this);
			permanentComponents.put(PROJECT_TABLE, ptp);
		}

		if (indexOfComponent(ptp) < 0)
			insertTab("Projects", null, ptp, "All projects", 0);

		setSelectedComponent(ptp);

		return ptp;
	}

	public ImportReadsPanel showImportReadsPanel() {
		ImportReadsPanel irp = (ImportReadsPanel)permanentComponents.get(IMPORT_READS);
		
		if (irp == null) {
			irp = new ImportReadsPanel(adb, this);
			permanentComponents.put(IMPORT_READS, irp);
		}

		if (indexOfComponent(irp) < 0)
			addTab("Import reads", null, irp, "Import reads");

		setSelectedComponent(irp);

		return irp;
	}

	public ReadFinderPanel showReadFinderPanel() {
		ReadFinderPanel rfp = (ReadFinderPanel)permanentComponents.get(READ_FINDER);
		
		if (rfp == null) {
			rfp = new ReadFinderPanel(adb, this);
			permanentComponents.put(READ_FINDER, rfp);
		}

		if (indexOfComponent(rfp) < 0)
			addTab("Find reads", null, rfp, "Find reads");

		setSelectedComponent(rfp);

		return rfp;
	}

	public ContigTransferTablePanel showContigTransferTablePanel() {
		ContigTransferTablePanel cttp = (ContigTransferTablePanel)permanentComponents.get(CONTIG_TRANSFER_TABLE);
		
		if (cttp == null) {
			cttp = new ContigTransferTablePanel(adb, adb.findMe(), this, false);
			permanentComponents.put(CONTIG_TRANSFER_TABLE, cttp);
		}

		if (indexOfComponent(cttp) < 0)
			addTab("Contig transfers", null, cttp, "Contig transfers");

		setSelectedComponent(cttp);

		cttp.resetDivider();

		return cttp;
	}

	public ContigTransferTablePanel showAdminContigTransferTablePanel() {
		ContigTransferTablePanel cttpAdmin = (ContigTransferTablePanel)permanentComponents.get(ADMIN_CONTIG_TRANSFER_TABLE);
	
		if (cttpAdmin == null) {
			cttpAdmin = new ContigTransferTablePanel(adb, adb.findMe(), this, true);
			permanentComponents.put(ADMIN_CONTIG_TRANSFER_TABLE, cttpAdmin);
		}

		if (indexOfComponent(cttpAdmin) < 0)
			addTab("All contig transfers", null, cttpAdmin,
					"All contig transfers");

		setSelectedComponent(cttpAdmin);

		return cttpAdmin;
	}

	public CreateContigTransferPanel showCreateContigTransferPanel() {
		CreateContigTransferPanel cctp = (CreateContigTransferPanel)permanentComponents.get(CREATE_CONTIG_TRANSFER);
		
		if (cctp == null) {
			cctp = new CreateContigTransferPanel(adb, this);
			permanentComponents.put(CREATE_CONTIG_TRANSFER, cctp);
		}
		
		if (indexOfComponent(cctp) < 0)
			addTab("Create contig transfers", null, cctp,
					"Create contig transfers");

		setSelectedComponent(cctp);

		return cctp;
	}

	public OligoFinderPanel showOligoFinderPanel() {
		OligoFinderPanel ofp = (OligoFinderPanel)permanentComponents.get(OLIGO_FINDER);
		
		if (ofp == null) {
			ofp = new OligoFinderPanel(adb, this);
			permanentComponents.put(OLIGO_FINDER, ofp);
		}
		
		if (indexOfComponent(ofp) < 0)
			addTab("Oligo finder", null, ofp, "Oligo finder");

		setSelectedComponent(ofp);

		return ofp;
	}

	public CheckConsistencyPanel showCheckConsistencyPanel() {
		CheckConsistencyPanel ccp = (CheckConsistencyPanel)permanentComponents.get(CHECK_CONSISTENCY);
		
		if (ccp == null) {
			ccp = new CheckConsistencyPanel(adb, this);
			permanentComponents.put(CHECK_CONSISTENCY, ccp);
		}
		
		if (indexOfComponent(ccp) < 0)
			addTab("Database Check", null, ccp, "Check database consistency");
		
		setSelectedComponent(ccp);
		
		return ccp;
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
			((MinervaPanel)c).closeResources();
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
