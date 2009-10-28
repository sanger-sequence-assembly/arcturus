package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.ComponentOrientation;
import java.awt.Font;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import javax.swing.*;
import javax.swing.event.TreeSelectionEvent;
import javax.swing.event.TreeSelectionListener;
import javax.swing.tree.*;

public class ScaffoldManagerPanel extends MinervaPanel {
	private JTree tree= new JTree();

	private JLabel lblWait = new JLabel("Please wait whilst the scaffold tree is retrieved");

	public ScaffoldManagerPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);
		
		ScaffoldManagerWorker worker = new ScaffoldManagerWorker(this, adb);
		
		createUI();
		
		worker.execute();
	}
	
	private void createUI() {
		tree.getSelectionModel().setSelectionMode(
				TreeSelectionModel.SINGLE_TREE_SELECTION);

		tree.addTreeSelectionListener(new TreeSelectionListener() {
			public void valueChanged(TreeSelectionEvent e) {
				DefaultMutableTreeNode node = (DefaultMutableTreeNode) tree
						.getLastSelectedPathComponent();

				if (node == null)
					return;
			}
		});

		tree.addMouseListener(new MouseAdapter() {
			public void mousePressed(MouseEvent e) {
				mouseHandler(e);
			}

			public void mouseReleased(MouseEvent e) {
				mouseHandler(e);
			}
		});

		tree.setCellRenderer(new MyRenderer());
		
		lblWait.setForeground(Color.RED);
		lblWait.setHorizontalAlignment(SwingConstants.CENTER);
		lblWait.setVerticalAlignment(SwingConstants.CENTER);
		lblWait.setFont(new Font("SansSerif", Font.BOLD, 24));
		
		add(lblWait, BorderLayout.CENTER);
	}

	protected void mouseHandler(MouseEvent e) {
		if (e.isPopupTrigger()) {
			int x = e.getX();
			int y = e.getY();

			System.out.println("Popup trigger at (" + x + ", " + y + ")");

			TreePath path = tree.getPathForLocation(x, y);

			if (path == null)
				return;

			DefaultMutableTreeNode node = (DefaultMutableTreeNode) path
					.getLastPathComponent();

			System.out.println("Clicked on " + node);
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
            	
            	font = (sNode.hasMyContigs() && !expanded) ? boldFont : defaultFont;
             } else if (node instanceof ContigNode) {         		
             	ContigNode cNode = (ContigNode)node;

             	bg = PALE_BLUE;
             	
             	icon = cNode.isForward() ? rightArrow : leftArrow;

               	font = cNode.isMine() ? boldFont : defaultFont;
            } else if (node instanceof SuperscaffoldNode) {
            	SuperscaffoldNode ssNode = (SuperscaffoldNode)node;
            	
            	font = (ssNode.hasMyScaffolds() && !expanded) ? boldFont : defaultFont;
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
			revalidate();
		}
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	public void closeResources() {
	}

	protected void createActions() {
	}

	protected void createClassSpecificMenus() {
	}

	protected void doPrint() {
	}

	protected boolean isRefreshable() {
		return false;
	}

	public void refresh() {
	}

}
