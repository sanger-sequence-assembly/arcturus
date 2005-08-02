package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import java.awt.*;

public class MinervaFrame extends JFrame {
    private Minerva minerva = null;
    private JMenuBar menubar = null;
    private JMenu fileMenu = null;
    private JMenu editMenu = null;
    private JMenu viewMenu = null;
    private JMenu toolMenu = null;
    private JToolBar toolbar = null;
    private JPanel mainPane = null;
    private Container contentPane = null;

    public MinervaFrame(Minerva minerva) {
	this(minerva, "No Title");
    }

    public MinervaFrame(Minerva minerva, String title) {
	super(title);
	this.minerva = minerva;

	mainPane = new JPanel(new BorderLayout());
	mainPane.setOpaque(true);
	super.setContentPane(mainPane);

	createMenus();

	setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
    }

    private void createMenus() {
	menubar = new JMenuBar();

	fileMenu = new JMenu("File");
	menubar.add(fileMenu);

	editMenu = new JMenu("Edit");
	menubar.add(editMenu);

	viewMenu = new JMenu("View");
	menubar.add(viewMenu);

	toolMenu = new JMenu("Tools");
	menubar.add(toolMenu);

	setJMenuBar(menubar);
    }

    public JMenu getFileMenu() { return fileMenu; }

    public JMenu getEditMenu() { return editMenu; }

    public JMenu getViewMenu() { return viewMenu; }

    public JMenu getToolMenu() { return toolMenu; }

    public void setContentPane(Container contentPane) {
	if (this.contentPane != null)
	    mainPane.remove(this.contentPane);

	this.contentPane = contentPane;

	mainPane.add(contentPane, BorderLayout.CENTER);

	pack();
    }

    public Container getContentPane() { return contentPane; }

    public void setToolBar(JToolBar toolbar) {
	if (this.toolbar != null)
	    mainPane.remove(this.toolbar);

	this.toolbar = toolbar;

	mainPane.add(toolbar, BorderLayout.NORTH);

	pack();
    }
}
