package uk.ac.sanger.arcturus.gui.contigtable;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;
import javax.swing.event.PopupMenuListener;
import javax.swing.event.PopupMenuEvent;

import java.awt.BorderLayout;
import java.awt.event.*;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.contigtransfer.ContigTransferTablePanel;
import uk.ac.sanger.arcturus.gui.importreads.*;
import uk.ac.sanger.arcturus.data.*;

public class ContigTablePanel extends MinervaPanel {
	private ContigTable table = null;
	private ContigTableModel model = null;
	
	private JCheckBoxMenuItem cbGroupByProject =
		new JCheckBoxMenuItem("Group by project");
	
	private JFileChooser fileChooser = new JFileChooser();

	private MinervaAbstractAction actionExportAsCAF ;
	private MinervaAbstractAction actionExportAsFasta;
	private MinervaAbstractAction actionViewContigs;

	private String projectlist;
	
	private boolean oneProject;

	public ContigTablePanel(Project[] projects, MinervaTabbedPane parent) {
		super(new BorderLayout(), parent);

		projectlist = (projects != null && projects.length > 0) ?
				projects[0].getName() : "[null]";
		
		for (int i = 1; i < projects.length; i++)
			projectlist += "," + projects[i].getName();
		
		oneProject = projects.length == 1;
		
		model = new ContigTableModel(projects);

		table = new ContigTable(model);

		table.getSelectionModel().addListSelectionListener(new ListSelectionListener() {
			public void valueChanged(ListSelectionEvent e) {
				updateActions();
			}		
		});

		JScrollPane scrollpane = new JScrollPane(table);

		add(scrollpane, BorderLayout.CENTER);

		createActions();

		createMenus();
		
		if (projects.length < 2)
			cbGroupByProject.setEnabled(false);
		
		updateActions();
	}

	protected void createActions() {
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
	}
	
	protected void updateActions() {
		boolean noneSelected = table.getSelectionModel().isSelectionEmpty();
		actionExportAsCAF.setEnabled(!noneSelected);
		actionExportAsFasta.setEnabled(!noneSelected);
		actionViewContigs.setEnabled(!noneSelected);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		menu.add(actionViewContigs);
		
		return true;
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
		createProjectMenu();
		createContigMenu();
	}

	private void createProjectMenu() {
		JMenu projectMenu = createMenu("Project", KeyEvent.VK_P, "Project");
		menubar.add(projectMenu);
		
		projectMenu.add(actionShowReadImporter);

		actionShowReadImporter.setEnabled(oneProject);
	}
	
	private void createContigMenu() {
		JMenu contigMenu = createMenu("Contig", KeyEvent.VK_C, "Contig");
		menubar.add(contigMenu);
	
		contigMenu.add(actionViewContigs);

		contigMenu.addSeparator();

		contigMenu.add(actionExportAsCAF);

		contigMenu.add(actionExportAsFasta);
	}

	private void viewSelectedContigs() {
		JOptionPane.showMessageDialog(
						this,
						"The selected contigs will be displayed in a colourful and informative way",
						"Display contigs", JOptionPane.INFORMATION_MESSAGE,
						null);
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

	protected boolean isRefreshable() {
		return true;
	}
}
