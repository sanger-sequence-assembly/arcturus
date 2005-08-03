package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;
import java.awt.event.*;
import java.util.*;

public class MinervaFrame extends JFrame {
    private static int counter = 0;

    private Minerva minerva = null;
    private JMenuBar menubar = null;
    private JMenu fileMenu = null;
    private JMenu editMenu = null;
    private JMenu viewMenu = null;
    private JMenu toolMenu = null;
    private JMenu windowMenu = null;
    private JPanel mainPane = null;

    private Action newAction = null;

    public MinervaFrame(Minerva minerva) {
	this(minerva, "MinervaFrame#" + counter);
	counter++;
    }

    public MinervaFrame(Minerva minerva, String title) {
	super(title);
	this.minerva = minerva;

	createActions();

	createMenus();

	setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
    }

    private void createActions() {
	newAction = new MyAbstractAction("New", createImageIcon("general/New24"),
					  "New window",
					  new Integer(KeyEvent.VK_N),
					  KeyStroke.getKeyStroke(KeyEvent.VK_N, ActionEvent.ALT_MASK)) {
		public void actionPerformed(ActionEvent e) {
		    createNewWindow();
		}
	    };
    }

    private void createMenus() {
	menubar = new JMenuBar();

	fileMenu = new JMenu("File");

	fileMenu.add(newAction);

	menubar.add(fileMenu);

	editMenu = new JMenu("Edit");
	menubar.add(editMenu);

	viewMenu = new JMenu("View");
	menubar.add(viewMenu);

	toolMenu = new JMenu("Tools");
	menubar.add(toolMenu);

	windowMenu = new JMenu("Windows");
	menubar.add(windowMenu);

	JPopupMenu windowPopup = windowMenu.getPopupMenu();

	windowPopup.addPopupMenuListener(new PopupMenuListener() {
		public void popupMenuWillBecomeVisible(PopupMenuEvent e) {
		    refreshWindowMenu();
		}

		public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {}

		public void popupMenuCanceled(PopupMenuEvent e) {}
	    });

	setJMenuBar(menubar);
    }

    private void refreshWindowMenu() {
	JPopupMenu windowPopup = windowMenu.getPopupMenu();

	windowPopup.removeAll();

	Vector frames = minerva.getActiveFrames();

	for (Enumeration elements = frames.elements(); elements.hasMoreElements();) {
	    MinervaFrame frame = (MinervaFrame)elements.nextElement();
	    windowPopup.add(new MyWindowAction(frame));
	}
    }

    public JMenu getFileMenu() { return fileMenu; }

    public JMenu getEditMenu() { return editMenu; }

    public JMenu getViewMenu() { return viewMenu; }

    public JMenu getToolMenu() { return toolMenu; }

    private void createNewWindow() {
	MinervaFrame frame = new MinervaFrame(minerva);
	Point p = getLocation();
	p.x += 40;
	p.y += 40;
	frame.setLocation(p);
	minerva.displayNewFrame(frame);
    }

    protected ImageIcon createImageIcon(String imageName) {
	String path = "/toolbarButtonGraphics/"
	    + imageName
	    + ".gif";

        java.net.URL imgURL = getClass().getResource(path);

        if (imgURL != null) {
            return new ImageIcon(imgURL);
        } else {
            System.err.println("Couldn't find file: " + path);
            return null;
        }
    }

    abstract class MyAbstractAction extends AbstractAction {
	public MyAbstractAction(String text, ImageIcon icon, String description,
				Integer mnemonic, KeyStroke accelerator) {
	    super(text, icon);
	    
	    if (description != null)
		putValue(SHORT_DESCRIPTION, description);
	    
	    if (mnemonic != null)
		putValue(MNEMONIC_KEY, mnemonic);
	    
	    if (accelerator != null)
		putValue(ACCELERATOR_KEY, accelerator);
	}
    }

    class MyWindowAction extends AbstractAction {
	private MinervaFrame frame = null;

	public MyWindowAction(MinervaFrame frame) {
	    super(frame.getTitle());
	    this.frame = frame;
	}

	public void actionPerformed(ActionEvent e) {
	    if (frame.getState() == Frame.ICONIFIED)
		frame.setState(Frame.NORMAL);

	    frame.toFront();
	}
    }
}
