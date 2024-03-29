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

package uk.ac.sanger.arcturus.gui;

import javax.naming.NamingException;

import javax.swing.*;
import javax.swing.border.*;
import java.awt.*;
import java.awt.event.*;

import java.util.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Organism;
import uk.ac.sanger.arcturus.database.*;

import uk.ac.sanger.arcturus.gui.organismtree.OrganismTreePanel;
import uk.ac.sanger.arcturus.jdbc.ArcturusDatabaseImpl;
import uk.ac.sanger.arcturus.people.PeopleManager;

import uk.ac.sanger.arcturus.utils.CheckVersion;

/**
 * This class is the main class for all GUI applications.
 */

public class Minerva {
	private static Minerva instance = null;
	protected ArcturusInstance[] ai = null;
	protected Map<String, MinervaFrame> frames = new HashMap<String, MinervaFrame>();

	public static Minerva getInstance() {
		if (instance == null)
			instance = new Minerva();

		return instance;
	}

	private Minerva() {
	}

	public String getBuildTime() {
		return Arcturus.getProperty(Arcturus.BUILD_DATE_KEY);
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
		String instances = getStringParameter(args, "-instance");

		String organism = getStringParameter(args, "-organism");

		if (instances == null)
			instances = Arcturus.getDefaultInstance();

		if (organism == null)
			organism = Arcturus.getDefaultOrganism();

		if (instances == null) {
			Arcturus.logWarning("No instance name was specified");
			System.exit(1);
		}

		SplashWindow splash = new SplashWindow();
		splash.showCentred();

		try {
			String[] inames = instances.split(",");

			ai = new ArcturusInstance[inames.length];

			for (int i = 0; i < inames.length; i++)
				ai[i] = ArcturusInstance.getInstance(inames[i]);

			String caption = (organism == null) ? instances : organism;

			MinervaFrame frame = createMinervaFrame(caption);

			JComponent component = (organism == null) ? createInstanceDisplay(ai)
					: createOrganismDisplay(organism);

			frame.setComponent(component);

			frame.pack();
			frame.setVisible(true);

			splash.setVisible(false);
			splash.dispose();
		} catch (Exception e) {
			splash.setVisible(false);
			splash.dispose();
			
			if (e instanceof NamingException)
				Arcturus.logInfo(e);
			else
				Arcturus.logWarning(e);
			System.exit(1);
		}
	}

	private MinervaFrame createMinervaFrame(String name) {
		String caption = "Minerva - " + name;

		if (PeopleManager.isMasquerading())
			caption += " [Masquerading as  "
					+ PeopleManager.createPerson(
							PeopleManager.getEffectiveUID()).getName() + "]";

		MinervaFrame frame = new MinervaFrame(this, caption, name);

		registerFrame(frame);

		return frame;
	}

	public void registerFrame(MinervaFrame frame) {
		String name = frame.getName();
		frames.put(name, frame);
	}

	public void unregisterFrame(MinervaFrame frame) {
		String name = frame.getName();

		frames.remove(name);

		if (frames.isEmpty())
			Minerva.exitMinerva();
	}

	public void createAndShowInstanceDisplay(ArcturusInstance ai) {
		MinervaFrame frame = createMinervaFrame(ai.getName());

		ArcturusInstance[] aia = new ArcturusInstance[1];

		aia[0] = ai;

		JComponent component = createInstanceDisplay(aia);

		frame.setComponent(component);

		frame.pack();
		frame.setVisible(true);
	}

	private JComponent createInstanceDisplay(ArcturusInstance[] ai) {
		return new OrganismTreePanel(ai);
	}

	public void createAndShowOrganismDisplay(String organism)
			throws ArcturusDatabaseException {
		MinervaFrame frame = frames.get(organism);

		if (frame == null) {
			frame = createMinervaFrame(organism);
			MinervaTabbedPane component = createOrganismDisplay(organism);

			frame.setComponent(component);

			frame.pack();
			frame.setVisible(true);
		} else {
			frame.setVisible(true);
			frame.setState(JFrame.NORMAL);
			frame.toFront();
		}
	}

	public MinervaTabbedPane createOrganismDisplay(String organism)
			throws ArcturusDatabaseException {
		ArcturusDatabase adb = ai[0].findArcturusDatabase(organism);

		return createOrganismDisplay(adb);
	}


	public MinervaTabbedPane createOrganismDisplay(Organism organism)
			throws ArcturusDatabaseException {
		ArcturusDatabase adb = new ArcturusDatabaseImpl(organism);
		
		return createOrganismDisplay(adb);
	}

	private MinervaTabbedPane createOrganismDisplay(ArcturusDatabase adb)
			throws ArcturusDatabaseException {
		adb.setCacheing(ArcturusDatabase.READ, false);
		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);

		MinervaTabbedPane panel = new MinervaTabbedPane(adb);
		
		panel.showProjectTable();

		return panel;
	}

	public void createAndShowOrganismDisplay(Organism organism)
			throws ArcturusDatabaseException {
		MinervaFrame frame = frames.get(organism.getName());

		if (frame == null) {
			frame = createMinervaFrame(organism.getName());
			MinervaTabbedPane component = createOrganismDisplay(organism);

			frame.setComponent(component);

			frame.pack();
			frame.setVisible(true);
		} else {
			frame.setVisible(true);
			frame.setState(JFrame.NORMAL);
			frame.toFront();
		}
	}

	class SplashWindow extends JWindow {
		private JLabel imageLabel;

		public SplashWindow() {
			super((Frame)null);

			setName("SplashWindow");

			java.net.URL imgURL = getClass().getResource(
					"/resources/images/minerva.jpg");
			ImageIcon image = new ImageIcon(imgURL);

			imageLabel = new JLabel(image);
			getContentPane().add(imageLabel, BorderLayout.CENTER);

			imageLabel.setBorder(BorderFactory
					.createBevelBorder(BevelBorder.RAISED));

			pack();
		}

		public void showCentred() {
			Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
			Dimension splashSize = getPreferredSize();

			setLocation(screenSize.width / 2 - (splashSize.width / 2),
					screenSize.height / 2 - (splashSize.height / 2));
			super.setVisible(true);
			toFront();
		}
	}	
	
	public static void displayHelp() {
		String buildDateTime = Arcturus.getProperty(Arcturus.BUILD_DATE_KEY, "?");
		String buildVersion = Arcturus.getProperty(Arcturus.BUILD_VERSION_KEY, "?");
		String buildBy = Arcturus.getProperty(Arcturus.BUILD_BY_KEY, "?");
		String buildHost = Arcturus.getProperty(Arcturus.BUILD_HOST_KEY, "?");
		
		StringBuilder builder = new StringBuilder();
		builder.append("Built by: ");
		builder.append(buildBy);
		builder.append("\non host: ");
		builder.append(buildHost);
		builder.append("\nat: ");
		builder.append(buildDateTime);
		builder.append("\nusing revision: ");
		builder.append(buildVersion);

		JOptionPane.showMessageDialog(null,
				builder.toString(),
				"Build Information", JOptionPane.INFORMATION_MESSAGE, null);
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
		int major = 1;
		int minor = 6;

		if (!CheckVersion.require(major, minor)) {
			String message = "You are running Java version "
					+ System.getProperties().getProperty("java.version") + "\n"
					+ "but this software requires at least version " + major
					+ "." + minor + ".\n\nPlease upgrade your version of Java.";

			JOptionPane.showMessageDialog(null, message,
					"Please upgrade your version of Java",
					JOptionPane.WARNING_MESSAGE);

			System.exit(1);
		}

		Minerva minerva = Minerva.getInstance();
		minerva.run(args);
	}
}
