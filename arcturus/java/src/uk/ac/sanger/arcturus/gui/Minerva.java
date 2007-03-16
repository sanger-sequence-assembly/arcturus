package uk.ac.sanger.arcturus.gui;

import java.sql.SQLException;
import javax.naming.NamingException;

import javax.swing.*;
import javax.swing.border.*;
import java.awt.*;
import java.awt.event.*;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.*;

import uk.ac.sanger.arcturus.gui.organismtable.OrganismTablePanel;

/**
 * This class is the main class for all GUI applications.
 */

public class Minerva {
	private static Minerva instance = null;
	private ArcturusInstance ai = null;
	private String buildtime;

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

			SplashWindow splash = null;

			String caption = (organism == null) ? ai.getName() : organism;

			MinervaFrame frame = createMinervaFrame(caption);

			splash = new SplashWindow(frame);
			splash.show();

			JComponent component = (organism == null) ? createInstanceDisplay(ai)
					: createOrganismDisplay(organism);

			frame.setComponent(component);

			frame.pack();
			frame.show();

			splash.hide();
			splash.dispose();
		} catch (Exception e) {
			Arcturus.logWarning(e);
			System.exit(1);
		}
	}
	
	private MinervaFrame createMinervaFrame(String name) {
		String caption = "Minerva - " + name;

		if (buildtime != null)
			caption += " [Build " + buildtime + "]";

		return new MinervaFrame(this, caption);
	}
	
	public void createAndShowInstanceDisplay(ArcturusInstance ai) {
		MinervaFrame frame = createMinervaFrame(ai.getName());
		JComponent component = createInstanceDisplay(ai);
		
		frame.setComponent(component);

		frame.pack();
		frame.show();
	}

	private JComponent createInstanceDisplay(ArcturusInstance ai) {
		return new OrganismTablePanel(ai);
	}

	public void createAndShowOrganismDisplay(String organism) throws SQLException, NamingException {
		MinervaFrame frame = createMinervaFrame(organism);
		JComponent component = createOrganismDisplay(organism);
		
		frame.setComponent(component);

		frame.pack();
		frame.show();
		
	}
	public JComponent createOrganismDisplay(String organism)
			throws SQLException, NamingException {
		ArcturusDatabase adb = ai.findArcturusDatabase(organism);

		adb.setReadCacheing(false);
		adb.setSequenceCacheing(false);

		MinervaTabbedPane panel = new MinervaTabbedPane(adb);

		panel.showProjectTablePanel();

		return panel;
	}

	class SplashWindow extends JWindow {
		private JLabel imageLabel;

		public SplashWindow(Frame frame) {
			super(frame);

			setName("SplashWindow");

			java.net.URL imgURL = getClass().getResource(
					"/resources/images/minerva.jpg");
			ImageIcon image = new ImageIcon(imgURL);

			imageLabel = new JLabel(image);
			getContentPane().add(imageLabel, BorderLayout.CENTER);
			
			imageLabel.setBorder(BorderFactory.createBevelBorder(BevelBorder.RAISED));

			pack();
		}

		public void show() {
			Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
			Dimension splashSize = getPreferredSize();

			setLocation(screenSize.width / 2 - (splashSize.width / 2),
					screenSize.height / 2 - (splashSize.height / 2));
			super.show();
			toFront();
		}
	}

	public static void displayHelp() {
		JOptionPane.showMessageDialog(null,
				"The user will be shown some useful and helpful information",
				"Don't panic!", JOptionPane.INFORMATION_MESSAGE, null);
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
