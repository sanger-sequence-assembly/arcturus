package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;
import java.awt.event.*;
import java.util.*;

public class MinervaFrame extends JFrame {
	/**
	 * 
	 */
	private static final long serialVersionUID = -3338074737769851188L;

	private static int counter = 0;

	protected Minerva minerva = null;
	protected JMenuBar menubar = null;
	protected JMenu fileMenu = null;
	protected JMenu editMenu = null;
	protected JMenu viewMenu = null;
	protected JMenu toolMenu = null;
	protected JMenu windowMenu = null;

	private Action quitAction = null;

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
		quitAction = new MyAbstractAction("Quit", null, "Quit", new Integer(
				KeyEvent.VK_Q), KeyStroke.getKeyStroke(KeyEvent.VK_Q,
				ActionEvent.CTRL_MASK)) {
			private static final long serialVersionUID = -8639285371442350829L;

			public void actionPerformed(ActionEvent e) {
				exitMinerva();
			}
		};
	}

	private void exitMinerva() {
		Object[] options = { "Yes", "No" };
		int rc = JOptionPane.showOptionDialog(this,
				"Do you really want to quit Minerva?", "You are about to quit Minerva",
				JOptionPane.YES_NO_OPTION, JOptionPane.WARNING_MESSAGE, null,
				options, options[1]);
		
		if (rc == JOptionPane.YES_OPTION) {
				System.exit(0);
		}
	}

	private void createMenus() {
		menubar = new JMenuBar();

		fileMenu = new JMenu("File");

		fileMenu.addSeparator();
		fileMenu.add(quitAction);

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

			public void popupMenuWillBecomeInvisible(PopupMenuEvent e) {
			}

			public void popupMenuCanceled(PopupMenuEvent e) {
			}
		});

		setJMenuBar(menubar);
	}

	private void refreshWindowMenu() {
		JPopupMenu windowPopup = windowMenu.getPopupMenu();

		windowPopup.removeAll();

		Vector frames = minerva.getActiveFrames();

		for (Enumeration elements = frames.elements(); elements
				.hasMoreElements();) {
			MinervaFrame frame = (MinervaFrame) elements.nextElement();
			windowPopup.add(new MyWindowAction(frame));
		}
	}

	public JMenu getFileMenu() {
		return fileMenu;
	}

	public JMenu getEditMenu() {
		return editMenu;
	}

	public JMenu getViewMenu() {
		return viewMenu;
	}

	public JMenu getToolMenu() {
		return toolMenu;
	}

	protected ImageIcon createImageIcon(String imageName) {
		String path = "/toolbarButtonGraphics/" + imageName + ".gif";

		java.net.URL imgURL = getClass().getResource(path);

		if (imgURL != null) {
			return new ImageIcon(imgURL);
		} else {
			System.err.println("Couldn't find file: " + path);
			return null;
		}
	}

	abstract class MyAbstractAction extends AbstractAction {
		public MyAbstractAction(String text, ImageIcon icon,
				String description, Integer mnemonic, KeyStroke accelerator) {
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
		/**
		 * 
		 */
		private static final long serialVersionUID = 8691248827701224064L;
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
