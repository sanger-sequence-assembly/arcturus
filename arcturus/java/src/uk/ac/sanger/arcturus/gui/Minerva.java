package uk.ac.sanger.arcturus.gui;

import java.sql.SQLException;
import javax.naming.NamingException;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.*;

import uk.ac.sanger.arcturus.gui.projecttable.ProjectTablePanel;
import uk.ac.sanger.arcturus.gui.organismtable.OrganismTablePanel;

/**
 * This class is the main class for all GUI applications. It manages the shared
 * ArcturusDatabase objects and maintains a list of all active frames.
 */

public class Minerva {
	private static Minerva instance = null;
	private ArcturusInstance ai = null;
	private String buildtime;
	private SplashWindow splash = null;

	public static Minerva getInstance() {
		if (instance == null)
			instance = new Minerva();

		return instance;
	}

	private Minerva() {
		try {
			InputStream is = getClass().getResourceAsStream(
					"/resources/buildtime.props");

			if (is != null) {
				Properties myprops = new Properties();

				myprops.load(is);

				is.close();

				buildtime = myprops.getProperty("BuildTime");
			}
		} catch (IOException ioe) {
			// Do nothing
		}
	}

	public String getBuildTime() {
		return buildtime;
	}

	private String getStringParameter(String[] args, String key) {
		if (args == null || key == null)
			return null;

		for (int i = 0; i < args.length - 1; i++)
			if (args[i].equalsIgnoreCase(key) && !args[i + 1].startsWith("-"))
				return args[i + 1];

		return null;
	}

	public void run(final String[] args) {
		//showSplashScreen();

		String instance = getStringParameter(args, "-instance");

		String organism = getStringParameter(args, "-organism");

		if (instance == null)
			instance = Arcturus.getDefaultInstance();

		if (organism == null)
			organism = Arcturus.getDefaultOrganism();

		if (instance == null) {
			Arcturus.logWarning("No instance name was specified");
			System.exit(1);
		}

		try {
			ai = ArcturusInstance.getInstance(instance);

			if (organism == null)
				createInstanceDisplay(ai);
			else
				createOrganismDisplay(organism);

			//hideSplashScreen();
		} catch (Exception e) {
			Arcturus.logWarning(e);
			System.exit(1);
		}
	}

	private void createInstanceDisplay(ArcturusInstance ai) {
		OrganismTablePanel panel = new OrganismTablePanel(ai);

		String caption = "Minerva - " + ai.getName();
		if (buildtime != null)
			caption += " [Build " + buildtime + "]";

		MinervaFrame frame = new MinervaFrame(this, caption, panel);

		frame.pack();
		frame.show();
	}

	public void createOrganismDisplay(String organism) throws SQLException,
			NamingException {
		ArcturusDatabase adb = ai.findArcturusDatabase(organism);

		adb.setReadCacheing(false);
		adb.setSequenceCacheing(false);

		MinervaTabbedPane panel = new MinervaTabbedPane(adb);

		String caption = "Minerva - " + adb.getName();
		if (buildtime != null)
			caption += " [Build " + buildtime + "]";

		MinervaFrame frame = new MinervaFrame(this, caption, panel);

		panel.showProjectTablePanel();

		frame.pack();
		frame.show();
	}

	private void showSplashScreen() {
		if (splash == null)
			splash = new SplashWindow();
		
		splash.showSplash();
	}

	private void hideSplashScreen() {
		splash.hideSplash();
	}

	class SplashWindow extends JWindow {
		private JLabel imageLabel;
		
		public SplashWindow() {
			super();

			java.net.URL imgURL = getClass().getResource("/resources/images/minerva.jpg");
			ImageIcon image = new ImageIcon(imgURL);

			imageLabel = new JLabel(image);
			getContentPane().add(imageLabel, BorderLayout.CENTER);
			
			pack();
			
	        addMouseListener(new MouseAdapter() {
                public void mousePressed(MouseEvent e)  {
                    hideSplash();
                }
            });

		}

		public void showSplash() {
			Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
			Dimension splashSize = getPreferredSize();

			splash.setLocation(screenSize.width / 2 - (splashSize.width / 2),
					screenSize.height / 2 - (splashSize.height / 2));
			setVisible(true);
			toFront();
		}

		public void hideSplash() {
			setVisible(false);
			dispose();
		}
	}

	public static void displayHelp() {
		Minerva.getInstance().showSplashScreen();
	}

	public static Action getQuitAction() {
		return new MinervaAbstractAction("Quit", null, "Quit", new Integer(
				KeyEvent.VK_Q), KeyStroke.getKeyStroke(KeyEvent.VK_Q,
				ActionEvent.CTRL_MASK)) {

			public void actionPerformed(ActionEvent e) {
				Minerva.exitMinerva();
			}
		};
	}

	public static void exitMinerva() {
		Object[] options = { "Yes", "No" };
		int rc = JOptionPane.showOptionDialog(null,
				"Do you really want to quit Minerva?",
				"You are about to quit Minerva", JOptionPane.YES_NO_OPTION,
				JOptionPane.WARNING_MESSAGE, null, options, options[1]);

		if (rc == JOptionPane.YES_OPTION) {
			System.exit(0);
		}
	}

	public static ImageIcon createImageIcon(String imageName) {
		String path = "/toolbarButtonGraphics/" + imageName + ".gif";

		java.net.URL imgURL = Minerva.class.getResource(path);

		if (imgURL != null) {
			return new ImageIcon(imgURL);
		} else {
			System.err.println("Couldn't find file: " + path);
			return null;
		}
	}

	public static void main(String[] args) {
		Minerva minerva = Minerva.getInstance();
		minerva.run(args);
	}
}
