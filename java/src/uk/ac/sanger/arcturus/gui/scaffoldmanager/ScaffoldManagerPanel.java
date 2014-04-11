// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.ComponentOrientation;
import java.awt.Font;
import java.awt.event.KeyEvent;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
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

public class ScaffoldManagerPanel extends MinervaPanel implements ProjectChangeEventListener, ContigTransferSource {
	private JTree tree= new JTree();

	private JLabel lblWait = new JLabel("Please wait whilst the scaffold tree is retrieved");

	protected ContigTransferMenu xferMenu;

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
		createContigMenu();
	}

	protected void createContigMenu() {
		JMenu contigMenu = createMenu("Contigs", KeyEvent.VK_C, "Contigs");
		menubar.add(contigMenu);

		contigMenu.add(xferMenu);
		
		xferMenu.refreshMenu();
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
}
