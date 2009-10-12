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

	public ScaffoldManagerPanel(ArcturusDatabase adb, MinervaTabbedPane parent) {
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
		public Component getTreeCellRendererComponent(JTree tree, Object value,
				boolean sel, boolean expanded, boolean leaf, int row,
				boolean hasFocus) {

			JLabel label = (JLabel)super.getTreeCellRendererComponent(tree, value, sel, expanded,
					leaf, row, hasFocus);
			
            DefaultMutableTreeNode node = (DefaultMutableTreeNode)value;
 
            Color bg = Color.white;
            
            boolean forward = false;
            
            if (node instanceof ScaffoldNode) {
            	bg = PALE_PINK;
            	forward = ((ScaffoldNode)node).isForward();
            	fixupLabel(label, forward);
            } else if (node instanceof ContigNode) {         		
            	bg = PALE_BLUE;
               	forward = ((ContigNode)node).isForward();
            	fixupLabel(label, forward);
            } else
            	label.setIcon(null);    
            
            setBackgroundNonSelectionColor(bg);
            
			return this;
		}
	}
	
	private void fixupLabel(JLabel label, boolean forward) {
    	label.setIcon(forward ? rightArrow : leftArrow);
    	label.setHorizontalTextPosition(JLabel.LEFT);		
    	// The following line is a kludge to overcome a bug in the paint method
    	// of DefaultTreeCellRenderer.
    	label.setComponentOrientation(ComponentOrientation.RIGHT_TO_LEFT);
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
