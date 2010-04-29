package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import java.awt.BorderLayout;
import java.awt.event.*;
import java.util.List;
import java.util.Vector;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.contigtransfer.ContigTransferMenu;
import uk.ac.sanger.arcturus.gui.common.contigtransfer.ContigTransferSource;
import uk.ac.sanger.arcturus.gui.scaffold.ScaffoldWorker;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ContigTablePanel extends MinervaPanel implements ProjectChangeEventListener, ContigTransferSource {
	protected ContigTable table = null;
	protected ContigTableModel model = null;

	protected JCheckBoxMenuItem cbGroupByProject = new JCheckBoxMenuItem(
			"Group by project");

	protected JFileChooser fileChooser = new JFileChooser();

	protected MinervaAbstractAction actionExportAsCAF;
	protected MinervaAbstractAction actionExportAsFasta;
	protected MinervaAbstractAction actionViewContigs;
	protected MinervaAbstractAction actionScaffoldContig;
	protected MinervaAbstractAction actionDeleteContig;
	protected MinervaAbstractAction actionDeleteSingleReadContigs;
	
	protected ContigTransferMenu xferMenu;
	
	protected JPopupMenu contigPopupMenu = new JPopupMenu();
	
	protected String projectlist;

	protected boolean oneProject;
	
	public ContigTablePanel(MinervaTabbedPane parent, Project[] projects) throws ArcturusDatabaseException {
		super(parent, projects[0].getArcturusDatabase());
		
		xferMenu = new ContigTransferMenu("Transfer selected contigs to", this, adb);
		
		projectlist = (projects != null && projects.length > 0) ? projects[0]
				.getName() : "[null]";

		for (int i = 1; i < projects.length; i++)
			projectlist += "," + projects[i].getName();
		
		for (int i = 0; i < projects.length; i++)
			adb.addProjectChangeEventListener(projects[i], this);

		oneProject = projects.length == 1;

		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		table.getSelectionModel().addListSelectionListener(
				new ListSelectionListener() {
					public void valueChanged(ListSelectionEvent e) {
						updateActions();
					}
				});
		
		table.addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				handleMouseEvent(e);
			}

			public void mousePressed(MouseEvent e) {
				handleMouseEvent(e);
			}

			public void mouseReleased(MouseEvent e) {
				handleMouseEvent(e);
			}
		});

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane, BorderLayout.CENTER);

		createActions();

		createMenus();
		
		getPrintAction().setEnabled(false);

		if (projects.length < 2)
			cbGroupByProject.setEnabled(false);

		updateActions();

		adb.addProjectChangeEventListener(this);
	}

	protected void createActions() {
		actionExportAsCAF = new MinervaAbstractAction("Export as CAF", null,
				"Export contigs as CAF", new Integer(KeyEvent.VK_E), KeyStroke
						.getKeyStroke(KeyEvent.VK_E, ActionEvent.CTRL_MASK)) {
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

		actionScaffoldContig = new MinervaAbstractAction("Scaffold the selected contig",
				null, "Scaffold the selected contig", new Integer(KeyEvent.VK_S),
				KeyStroke.getKeyStroke(KeyEvent.VK_S, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				scaffoldTheSelectedContig();
			}
		};

		actionDeleteContig = new MinervaAbstractAction("Delete the selected contig",
				null, "Delete the selected contig", new Integer(KeyEvent.VK_D),
				KeyStroke.getKeyStroke(KeyEvent.VK_D, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				deleteSelectedSingleReadContig();
			}
		};

		// or should this be; delete all selected single-read contigs?
		actionDeleteSingleReadContigs = new MinervaAbstractAction("Delete all single-read contigs",
				null, "Delete all single-read contigs", new Integer(KeyEvent.VK_E),
				KeyStroke.getKeyStroke(KeyEvent.VK_E, ActionEvent.CTRL_MASK)) {
			public void actionPerformed(ActionEvent e) {
				deleteSingleReadContigs();
			}
		};
	}

	protected void updateActions() {
		int nrows = table.getSelectedRowCount();
		boolean noneSelected = nrows == 0;
		
		actionExportAsCAF.setEnabled(!noneSelected);
		actionExportAsFasta.setEnabled(!noneSelected);
		actionViewContigs.setEnabled(!noneSelected);
		if (xferMenu != null)
			xferMenu.setEnabled(!noneSelected);
		
		actionScaffoldContig.setEnabled(nrows == 1);
		
		// added by ejz, April 28, 2010; re: remove single-read contigs

        boolean enableSingleDelete = table.hasSingleReadContigSelectedForDelete();
        boolean enableMultiDelete  = model.hasSingleReadContigs();
        // if either is true, there is at least one contig; test access to it
        if (enableSingleDelete || enableMultiDelete) {
        	if (!model.userCanDeleteContigs()) {
     			enableSingleDelete = false;
    			enableMultiDelete = false;
    		}
        }
 		actionDeleteContig.setEnabled(enableSingleDelete);
		actionDeleteSingleReadContigs.setEnabled(enableMultiDelete);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionViewContigs);

		return true;
	}

	protected void exportAsCAF() {
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

	protected void exportAsFasta() {
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
	
	protected void deleteSelectedSingleReadContig() {
		// method added by ejz on April 28, 2010
        Project project = null;
		
		ContigList clist = table.getSelectedValues();
		for (int i = 0 ; i < clist.size() ; i++) {
			Contig contig = (Contig)clist.elementAt(i);
		    project = contig.getProject(); // register for table refresh
            if (contig.getReadCount() == 1) { // just to be sure
            	try {
//            		System.out.println("deleteSelectedContig invoked " + contig.getID() );		
		            adb.deleteSingleReadCurrentContig(contig.getID());
            	}
            	catch (ArcturusDatabaseException e) {
            		Arcturus.logWarning("Failed to delete single-read contig " + contig.getID(), e);
            	}
            }
		}
		// refresh the view
		ProjectChangeEvent pce = new ProjectChangeEvent(this,project,1);
		projectChanged(pce);	
	}

	protected void deleteSingleReadContigs() {
        Project project = null;
        
		System.out.println("deleteSingleReadContigs to be invoked");
		
		for (int i = 0 ; i < model.getRowCount() ; i++) {
			Contig contig = model.elementAt(i);
		    project = contig.getProject(); // register for table refresh
            if (contig.getReadCount() == 1 && contig.getLength() < 1000) { // must test here
//            if (contig.getReadCount() == 1) { // must test here
            	try {
            		System.out.println("deleteSelectedContig invoked " + contig.getID() );		
		            adb.deleteSingleReadCurrentContig(contig.getID());
//		            adb.deleteSingleReadCurrentContig(0);
            	}
            	catch (ArcturusDatabaseException e) {
            		Arcturus.logWarning("Failed to delete single-read contig " + contig.getID(), e);
            	}
            	i += 10;
            }
		}
		// refresh the view
		ProjectChangeEvent pce = new ProjectChangeEvent(this,project,1);
		projectChanged(pce);	
	}
	
	protected void addClassSpecificViewMenuItems(JMenu menu) {
		menu.addSeparator();

		menu.add(cbGroupByProject);

		cbGroupByProject.setSelected(false);

		cbGroupByProject.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				boolean byProject = cbGroupByProject.getState();
				model.setGroupByProject(byProject);
			}
		});
	}

	protected void createClassSpecificMenus() {
		createContigMenu();
	}

	protected void createContigMenu() {
		JMenu contigMenu = createMenu("Contig", KeyEvent.VK_C, "Contig");
		menubar.add(contigMenu);

		contigMenu.add(actionViewContigs);

		contigMenu.addSeparator();

		contigMenu.add(actionExportAsCAF);

		contigMenu.add(actionExportAsFasta);
		
		contigMenu.addSeparator();
		
		contigMenu.add(actionScaffoldContig);

		contigMenu.addSeparator();
		
		contigMenu.add(actionDeleteSingleReadContigs);

		contigMenu.addSeparator();

		contigMenu.add(xferMenu);
		
		try {
			xferMenu.refreshMenu();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to refresh contig transfer menu", e);
		}
		
		contigPopupMenu.add(actionViewContigs);

		contigPopupMenu.addSeparator();

		contigPopupMenu.add(actionExportAsCAF);

		contigPopupMenu.add(actionExportAsFasta);
		
		contigPopupMenu.addSeparator();
		
		contigPopupMenu.add(actionScaffoldContig);
		
		contigPopupMenu.addSeparator();
		
		contigPopupMenu.add(actionDeleteContig);
	}
	

	private void handleMouseEvent(MouseEvent e) {
		if (e.isPopupTrigger()) {
			displayPopupMenu(e);
		}
	}

	protected void displayPopupMenu(MouseEvent e) {
		contigPopupMenu.show(e.getComponent(), e.getX(), e.getY());
	}
	
	protected void viewSelectedContigs() {
		JOptionPane
				.showMessageDialog(
						this,
						"The selected contigs will be displayed in a colourful and informative way",
						"Display contigs", JOptionPane.INFORMATION_MESSAGE,
						null);
	}
	
	protected void scaffoldTheSelectedContig() {
		int[] indices = table.getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) table.getModel();

		Contig contig = (Contig)ctm.elementAt(indices[0]);

		ScaffoldWorker worker = new ScaffoldWorker(contig, parent, adb);
		
		worker.execute();		
	}

	public void closeResources() {
		adb.removeProjectChangeEventListener(this);
	}

	public String toString() {
		return "ContigTablePanel[projects=" + projectlist + "]";
	}

	public boolean isOneProject() {
		return oneProject;
	}

	public void refresh() throws ArcturusDatabaseException {
		table.refresh();
		
		try {
			xferMenu.refreshMenu();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to refresh contig transfer menu", e);
		}
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}

	public void projectChanged(ProjectChangeEvent event) {
		try {
			refresh();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("Failed to refresh contig list", e);
		}
	}

	public List<Contig> getSelectedContigs() {
		int[] indices = table.getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) table.getModel();
		
		List<Contig> contigs = new Vector<Contig>(indices.length);
		
		for (int i = 0; i < indices.length; i++)
			contigs.add((Contig)ctm.elementAt(indices[i]));
		
		return contigs;
	}
}
