package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.event.PopupMenuListener;
import javax.swing.event.PopupMenuEvent;

import java.awt.BorderLayout;
import java.awt.event.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.importreads.*;
import uk.ac.sanger.arcturus.data.*;

public class ContigTablePanel extends JPanel implements MinervaClient {
	private ContigTable table = null;
	private ContigTableModel model = null;
	private JMenuBar menubar = new JMenuBar();
	
	private JCheckBoxMenuItem cbGroupByProject =
		new JCheckBoxMenuItem("Group by project");
	
	private JFileChooser fileChooser = new JFileChooser();

	private MinervaAbstractAction actionClose;
	private MinervaAbstractAction actionExportAsCAF ;
	private MinervaAbstractAction actionExportAsFasta;
	private MinervaAbstractAction actionViewContigs;
	private MinervaAbstractAction actionImportReads;
	private MinervaAbstractAction actionRefresh;
	private MinervaAbstractAction actionHelp;

	private String projectlist;
	
	private boolean oneProject;

	public ContigTablePanel(Project[] projects) {
		super(new BorderLayout());

		projectlist = (projects != null && projects.length > 0) ?
				projects[0].getName() : "[null]";
		
		for (int i = 1; i < projects.length; i++)
			projectlist += "," + projects[i].getName();
		
		oneProject = projects.length == 1;
		
		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane, BorderLayout.CENTER);

		createActions();

		createMenus();
		
		if (projects.length < 2)
			cbGroupByProject.setEnabled(false);
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

		actionExportAsFasta = new MinervaAbstractAction("Export as FASTA",
				null, "Export contigs as FASTA", new Integer(KeyEvent.VK_F),
				KeyStroke.getKeyStroke(KeyEvent.VK_F, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsFasta();
			}
		};

		actionViewContigs = new MinervaAbstractAction("Open selected contigs",
				null, "Open selected contigs", new Integer(KeyEvent.VK_O),
				KeyStroke.getKeyStroke(KeyEvent.VK_O, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				viewSelectedContigs();
			}
		};
		
		actionImportReads = new MinervaAbstractAction("Import reads into project",
				null, "Import reads into project", new Integer(KeyEvent.VK_I),
				KeyStroke.getKeyStroke(KeyEvent.VK_I, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				importReadsIntoProject();
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
		createProjectMenu();
		createContigMenu();
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

		fileMenu.add(Minerva.getQuitAction());
		
		fileMenu.getPopupMenu().addPopupMenuListener(new PopupMenuListener() {
			public void popupMenuCanceled(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
				actionViewContigs.setEnabled(table.getSelectedRowCount() > 0);
			}
			
		});
	}

	private void closePanel() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		mtp.remove(this);
	}

	private void exportAsCAF() {
		if (table.getSelectedRowCount() > 0) {		
			int rc = fileChooser.showSaveDialog(this);
		
			if (rc == JFileChooser.APPROVE_OPTION) {
				table.saveSelectedContigsAsCAF(fileChooser.getSelectedFile());
			}
		} else {
			JOptionPane.showMessageDialog(this,
					"Please select the contigs to export",
					"No contigs selected", JOptionPane.WARNING_MESSAGE, null);		
		}
	}

	private void exportAsFasta() {
		if (table.getSelectedRowCount() > 0) {				
			int rc = fileChooser.showSaveDialog(this);
		
			if (rc == JFileChooser.APPROVE_OPTION) {
				table.saveSelectedContigsAsFasta(fileChooser.getSelectedFile());
			}
		} else {
			JOptionPane.showMessageDialog(this,
					"Please select the contigs to export",
					"No contigs selected", JOptionPane.WARNING_MESSAGE, null);			
		}
	}

	private void createEditMenu() {
		JMenu editMenu = createMenu("Edit", KeyEvent.VK_E, "Edit");
		menubar.add(editMenu);
	}

	private void createViewMenu() {
		JMenu viewMenu = createMenu("View", KeyEvent.VK_V, "View");
		menubar.add(viewMenu);
		
		viewMenu.add(actionRefresh);

		viewMenu.addSeparator();

		viewMenu.add(cbGroupByProject);
		
		cbGroupByProject.setSelected(false);
		
		cbGroupByProject.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				boolean byProject = cbGroupByProject.getState();
				model.setGroupByProject(byProject);
			}
		});
	}
	
	private void createProjectMenu() {
		JMenu projectMenu = createMenu("Project", KeyEvent.VK_P, "Project");
		menubar.add(projectMenu);
		
		projectMenu.add(actionImportReads);
		
		actionImportReads.setEnabled(oneProject);
	}
	
	private void createContigMenu() {
		JMenu contigMenu = createMenu("Contig", KeyEvent.VK_C, "Contig");
		menubar.add(contigMenu);
		
		contigMenu.getPopupMenu().addPopupMenuListener(new PopupMenuListener() {
			public void popupMenuCanceled(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
			}

			public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
				boolean haveSelection = table.getSelectedRowCount() > 0;
				actionViewContigs.setEnabled(haveSelection);
				actionExportAsCAF.setEnabled(haveSelection);
				actionExportAsFasta.setEnabled(haveSelection);
			}
			
		});
	
		contigMenu.add(actionViewContigs);

		contigMenu.addSeparator();

		contigMenu.add(actionExportAsCAF);

		contigMenu.add(actionExportAsFasta);
	}
	
	private void createHelpMenu() {
		JMenu helpMenu = createMenu("Help", KeyEvent.VK_H, "Help");
		menubar.add(helpMenu);
		
		helpMenu.add(actionHelp);
	}

	private void viewSelectedContigs() {
		JOptionPane.showMessageDialog(
						this,
						"The selected contigs will be displayed in a colourful and informative way",
						"Display contigs", JOptionPane.INFORMATION_MESSAGE,
						null);
	}
	
	private void importReadsIntoProject() {
		MinervaTabbedPane mtp = MinervaTabbedPane.getTabbedPane(this);
		
		ImportReadsPanel irp = mtp.showImportReadsPanel();
		
		irp.setSelectedProject(projectlist);
		
		mtp.setSelectedComponent(irp);
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
	
	public boolean isOneProject() {
		return oneProject;
	}

	public void refresh() {
		table.refresh();
	}
}
