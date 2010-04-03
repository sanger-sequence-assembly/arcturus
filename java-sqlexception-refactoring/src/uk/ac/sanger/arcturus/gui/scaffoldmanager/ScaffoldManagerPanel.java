package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.ComponentOrientation;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.KeyEvent;
import java.io.File;
import java.util.List;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.common.contigtransfer.ContigTransferMenu;
import uk.ac.sanger.arcturus.gui.common.contigtransfer.ContigTransferSource;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.*;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import javax.swing.*;
import javax.swing.event.TreeSelectionEvent;
import javax.swing.event.TreeSelectionListener;
import javax.swing.tree.*;

public class ScaffoldManagerPanel extends MinervaPanel
	implements ProjectChangeEventListener, ContigTransferSource {
	public enum FastaMode { SEPARATE_CONTIGS, CONCATENATE_CONTIGS }
	
	private JTree tree= new JTree();

	private JLabel lblWait = new JLabel("Please wait whilst the scaffold tree is retrieved");
	
	private JButton btnSearch = new JButton("Search");
	
	private JTextField txtContig = new JTextField(30);

	protected ContigTransferMenu xferMenu;

	protected MinervaAbstractAction actionExportAsSeparateFasta;
	protected MinervaAbstractAction actionExportAsConcatenatedFasta;

	public ScaffoldManagerPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);

		xferMenu = new ContigTransferMenu("Transfer selected contigs to", this, adb);

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);
		
		ScaffoldManagerWorker worker = new ScaffoldManagerWorker(this, adb);
		
		createUI();
	
		worker.execute();

		adb.addProjectChangeEventListener(this);
	}
	
	private void createUI() {
		tree.getSelectionModel().setSelectionMode(
				TreeSelectionModel.SINGLE_TREE_SELECTION);

		tree.addTreeSelectionListener(new TreeSelectionListener() {
			public void valueChanged(TreeSelectionEvent e) {
				updateActions();
			}
		});

		tree.setCellRenderer(new MyRenderer());
		
		btnSearch.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				doContigSearch();
			}			
		});
		
		lblWait.setForeground(Color.RED);
		lblWait.setHorizontalAlignment(SwingConstants.CENTER);
		lblWait.setVerticalAlignment(SwingConstants.CENTER);
		lblWait.setFont(new Font("SansSerif", Font.BOLD, 24));
		
		add(lblWait, BorderLayout.CENTER);
	}
	
	void updateActions() {
		int nrows = tree.getSelectionCount();
		boolean noneSelected = nrows == 0;
		
		xferMenu.setEnabled(!noneSelected);

		if (noneSelected) {
			actionExportAsSeparateFasta.setEnabled(false);
			actionExportAsConcatenatedFasta.setEnabled(false);
		} else {
			DefaultMutableTreeNode node = (DefaultMutableTreeNode)tree.getLastSelectedPathComponent();
			
			boolean canExport = node instanceof ScaffoldNode || node instanceof SuperscaffoldNode ||
				node instanceof AssemblyNode;

			actionExportAsSeparateFasta.setEnabled(canExport);
			actionExportAsConcatenatedFasta.setEnabled(canExport);
		}
	}

	private final Color PALE_PINK = new Color(0xFF, 0xCC, 0xCC);
	private final Color PALE_BLUE = new Color(0xCC, 0xFF, 0xFF);

	private class MyRenderer extends DefaultTreeCellRenderer {
		private Font defaultFont = null;
		private Font boldFont;
				
		public Component getTreeCellRendererComponent(JTree tree, Object value,
				boolean sel, boolean expanded, boolean leaf, int row,
				boolean hasFocus) {
			super.getTreeCellRendererComponent(tree, value, sel, expanded,
					leaf, row, hasFocus);
			
			if (defaultFont == null) {
				defaultFont = getFont();
				boldFont = defaultFont.deriveFont(Font.BOLD);
			}
			
            DefaultMutableTreeNode node = (DefaultMutableTreeNode)value;
 
            Color bg = Color.white;
            Font font = defaultFont;
            ImageIcon icon = null;
            
            if (node instanceof ScaffoldNode) {
            	ScaffoldNode sNode = (ScaffoldNode)node;
            	
            	bg = PALE_PINK;
            	
            	icon = sNode.isForward() ? rightArrow : leftArrow;
            	
            	font = (!expanded && sNode.hasMyContigs()) ? boldFont : defaultFont;
             } else if (node instanceof ContigNode) {         		
             	ContigNode cNode = (ContigNode)node;

             	bg = PALE_BLUE;
             	
             	icon = cNode.isForward() ? rightArrow : leftArrow;

               	font = cNode.isMine() ? boldFont : defaultFont;
            } else if (node instanceof SuperscaffoldNode) {
            	SuperscaffoldNode ssNode = (SuperscaffoldNode)node;
            	
            	font = (!expanded && ssNode.hasMyContigs()) ? boldFont : defaultFont;
            } 
            
            setFont(font);
            
            setIcon(icon);
          
            setBackgroundNonSelectionColor(bg);
            
			return this;
		}
		
		private void setIcon(ImageIcon icon) {
			super.setIcon(icon);
			
			if (icon != null)
				fixup();
		}
		
		private void fixup() {
	    	setHorizontalTextPosition(JLabel.LEFT);
	    	
	    	// The following line is a kludge to overcome a bug in the paint method
	    	// of DefaultTreeCellRenderer.
	    	setComponentOrientation(ComponentOrientation.RIGHT_TO_LEFT);
		}
	}
	
	ImageIcon leftArrow = createImageIcon("/resources/icons/left-arrow-blue.png");
	ImageIcon rightArrow = createImageIcon("/resources/icons/right-arrow-red.png");
	
    protected ImageIcon createImageIcon(String path) {
        java.net.URL imgURL = getClass().getResource(path);
        if (imgURL != null) {
            return new ImageIcon(imgURL);
        } else {
            System.err.println("Couldn't find file: " + path);
            return null;
        }
    }

	public void setModel(TreeModel model) {
		if (model == null || model.getRoot() == null || model.getChildCount(model.getRoot()) == 0) {
			lblWait.setText("No scaffold could be found ... sorry!");
		} else {
			tree.setModel(model);		
			JScrollPane treepane = new JScrollPane(tree);
			removeAll();
			add(treepane, BorderLayout.CENTER);
			
			JPanel buttonPanel = new JPanel(new FlowLayout());
			
			JLabel label = new JLabel("Search for contig: ");
			
			buttonPanel.add(label);
			buttonPanel.add(txtContig);
			buttonPanel.add(btnSearch);
			
			add(buttonPanel, BorderLayout.NORTH);
			
			revalidate();
		}
	}
	
	private void doContigSearch() {
		String text = txtContig.getText().trim();
		
		ScaffoldContigFinderWorker worker = new ScaffoldContigFinderWorker(adb, this, text);
		
		worker.execute();
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	public void closeResources() {
	}

	protected void createActions() {
		actionExportAsSeparateFasta = new MinervaAbstractAction("For gap closure",
				null, "Export selected scaffold(s) as separate contigs", new Integer(KeyEvent.VK_G),
				KeyStroke.getKeyStroke(KeyEvent.VK_G, ActionEvent.CTRL_MASK | ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsFasta(FastaMode.SEPARATE_CONTIGS);
			}
		};
		
		actionExportAsConcatenatedFasta = new MinervaAbstractAction("For annotation",
				null, "Export selected scaffold(s) as concatenated contigs", new Integer(KeyEvent.VK_N),
				KeyStroke.getKeyStroke(KeyEvent.VK_N, ActionEvent.CTRL_MASK | ActionEvent.ALT_MASK)) {
			public void actionPerformed(ActionEvent e) {
				exportAsFasta(FastaMode.CONCATENATE_CONTIGS);
			}
		};
	}

	private void exportAsFasta(FastaMode mode) {
		DefaultMutableTreeNode node = (DefaultMutableTreeNode)tree.getLastSelectedPathComponent();
		
		if (node == null) {
			JOptionPane.showMessageDialog(this, "No valid node is selected.  This should not happen.",
					"No node selected", JOptionPane.ERROR_MESSAGE);			
			return;
		}
		
		JFileChooser chooser = new JFileChooser();
		
		File dir = new File(System.getProperty("user.dir"));
		
		chooser.setCurrentDirectory(dir);
		
		chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		
		chooser.setMultiSelectionEnabled(false);
		
		if (chooser.showOpenDialog(this) == JFileChooser.APPROVE_OPTION) {
			dir = chooser.getSelectedFile();
			
			if (dir.canWrite()) {
				ScaffoldExportWorker worker = new ScaffoldExportWorker(this, mode, dir, node);
			
				worker.execute();
			} else
				JOptionPane.showMessageDialog(this,
						"The selected directory (" + dir.getAbsolutePath() + ") is read-only.",
						"The directory is read-only.", JOptionPane.ERROR_MESSAGE);
		}
	}

	protected void createClassSpecificMenus() {
		createScaffoldMenu();
		createContigMenu();
	}

	protected void createContigMenu() {
		JMenu contigMenu = createMenu("Contigs", KeyEvent.VK_C, "Operations on contigs");
		menubar.add(contigMenu);

		contigMenu.add(xferMenu);
		
		xferMenu.refreshMenu();
	}
	
	protected void createScaffoldMenu() {
		JMenu scaffoldMenu = createMenu("Scaffolds", KeyEvent.VK_S, "Operations on scaffolds");
		menubar.add(scaffoldMenu);
		
		JMenu exportMenu = new JMenu("Export as FASTA"); 
		scaffoldMenu.add(exportMenu);
		
		exportMenu.add(actionExportAsSeparateFasta);
		exportMenu.add(actionExportAsConcatenatedFasta);
	}

	protected void doPrint() {
	}

	protected boolean isRefreshable() {
		return true;
	}

	public void refresh() {
		xferMenu.refreshMenu();
		refreshTree();
	}
	
	private void refreshTree() {
		TreeModel model = tree.getModel();
		
		if (model instanceof DefaultTreeModel) {
			DefaultTreeModel dtm = (DefaultTreeModel)model;
			
			dtm.nodeStructureChanged((TreeNode)dtm.getRoot());
		}
	}

	public List<Contig> getSelectedContigs() {
		DefaultMutableTreeNode node = (DefaultMutableTreeNode)tree.getLastSelectedPathComponent();

		if (node != null && node instanceof SequenceNode)
			return ((SequenceNode)node).getContigs();
		else
			return null;	
	}

	public void projectChanged(ProjectChangeEvent event) {
		refresh();
	}
	
	public JTree getTree() {
		return tree;
	}
}
