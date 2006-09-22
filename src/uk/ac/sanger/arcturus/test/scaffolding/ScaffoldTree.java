package uk.ac.sanger.arcturus.test.scaffolding;

import javax.swing.*;
import javax.swing.tree.*;
import javax.swing.event.*;

import java.util.Enumeration;

import java.awt.Dimension;
import java.awt.GridLayout;

class ScaffoldTree extends JPanel
    implements TreeSelectionListener {
    private JEditorPane htmlPane;
    private JTree tree;
 
    public ScaffoldTree(Assembly assembly) {
        super(new GridLayout(1,0));

	DefaultMutableTreeNode top = makeTreeFromAssembly(assembly);

        //Create a tree that allows one selection at a time.
        tree = new JTree(top);
        tree.getSelectionModel().setSelectionMode
                (TreeSelectionModel.SINGLE_TREE_SELECTION);

        //Listen for when the selection changes.
        tree.addTreeSelectionListener(this);

        //Create the scroll pane and add the tree to it. 
        JScrollPane treeView = new JScrollPane(tree);

        //Create the HTML viewing pane.
        htmlPane = new JEditorPane();
        htmlPane.setEditable(false);
        JScrollPane htmlView = new JScrollPane(htmlPane);

        //Add the scroll panes to a split pane.
        JSplitPane splitPane = new JSplitPane(JSplitPane.VERTICAL_SPLIT);
        splitPane.setTopComponent(treeView);
        splitPane.setBottomComponent(htmlView);

        Dimension minimumSize = new Dimension(100, 50);
        htmlView.setMinimumSize(minimumSize);
        treeView.setMinimumSize(minimumSize);
        splitPane.setDividerLocation(100);

        splitPane.setPreferredSize(new Dimension(500, 300));

        add(splitPane);
    }

    public void valueChanged(TreeSelectionEvent e) {
        DefaultMutableTreeNode node = (DefaultMutableTreeNode)
                           tree.getLastSelectedPathComponent();

        if (node == null) return;

        Object nodeInfo = node.getUserObject();

	System.err.println("Selected " + nodeInfo);
    }

    private DefaultMutableTreeNode makeTreeFromAssembly(Assembly assembly) {
	return createTreeRecursively(assembly);
    }

    private DefaultMutableTreeNode createTreeRecursively(Core parent) {
	DefaultMutableTreeNode parentNode = new DefaultMutableTreeNode(parent, true);

	for (Enumeration e = parent.elements(); e.hasMoreElements() ;) {
	    Object child = e.nextElement();
	    if (child instanceof Core) {
		Core coreChild = (Core)child;
		
		DefaultMutableTreeNode childNode = createTreeRecursively(coreChild);

		parentNode.add(childNode);
	    } else {
		parentNode.add(new DefaultMutableTreeNode(child, false));
	    }
	}

	return parentNode;
    }
}
