package uk.ac.sanger.arcturus.gui;

import java.awt.event.*;
import javax.swing.*;
import java.awt.Dimension;
import java.util.*;
import java.io.*;
import javax.naming.NamingException;
import javax.naming.Context;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.*;

import uk.ac.sanger.arcturus.gui.projecttable.ProjectTableFrame;

/**
 * This class is the main class for all GUI applications.
 * It handles user preferences and manages the shared ArcturusDatabase
 * objects. It also maintains a list of all active frames.
 */

public class Minerva implements WindowListener {
    public static final String ARCTURUS_USER_DIRECTORY = ".arcturus";
    public static final String MINERVA_PREFERENCES_FILE = "minerva.prefs";

    protected Properties userProperties = new Properties();
    protected Properties siteProperties = new Properties();
    protected Vector activeFrames = new Vector();
    protected ArcturusDatabase adb = null;

    public Minerva(String[] args) {
	loadUserProperties();
	loadSiteProperties();

	String instance = getStringParameter(args, "-instance");
	String organism = getStringParameter(args, "-organism");

	if (instance == null) {
	    System.err.println("No instance specified");
	    System.exit(1);
	}

	if (organism == null) {
	    System.err.println("No organism specified");
	    System.exit(1);
	}

	try {
	    adb = createArcturusDatabase(instance ,organism);
	}
	catch (Exception e) {
	    System.err.println("Failed to create an ArcturusDatabase  for instance \"" + instance +
			       "\", organism \"" + organism + "\" : " + e.getMessage());
	    System.exit(1);
	}

	if (adb == null) {
	    System.err.println("ArcturusDatabase object for instance \"" + instance +
			       "\", organism \"" + organism + "\" was null");
	    System.exit(1);
	}

	//restoreOldSessions();

	//createNewSessions(args);
    }

    private void loadUserProperties() {
	String userHome = System.getProperty("user.home");

	File file = new File(userHome);

	file = new File(file, ARCTURUS_USER_DIRECTORY);

	if (!file.exists()) {
	    System.err.println("Cannot load user preferences: directory " + file +
			       " does not exist");
	    return;
	}

	if (!file.isDirectory()) {
	    System.err.println("Cannot load user preferences: " + file +
			       " exists but is not a directory");
	}

	file = new File(file, MINERVA_PREFERENCES_FILE);

	loadPropertiesFromFile(userProperties, file);
    }

    private void loadSiteProperties() {
	String siteHome = System.getProperty("arcturus.site.home");

	if (siteHome == null) {
	    System.err.println("Cannot load site preferences: site home directory is not defined");
	    return;
	}

	File file = new File(siteHome);

	if (!file.exists()) {
	    System.err.println("Cannot load site preferences: directory " + file + " does not exist");
	    return;
	}

	if (!file.isDirectory()) {
	    System.err.println("Cannot load site preferences: " + file + " exists but is not a directory");
	    return;
	}

	if (!file.canRead()) {
	    System.err.println("Cannot load site preferences: directory " + file + " exists but is not readable");
	    return;
	}

	file = new File(file, MINERVA_PREFERENCES_FILE);

	loadPropertiesFromFile(siteProperties, file);
    }

    private void loadPropertiesFromFile(Properties props, File file) {
	String preftype = (props == userProperties) ? "user" : (props == siteProperties) ? "site" : "(unknown)";

	String warning = "Cannot load " + preftype + " preferences:";

	if (!file.exists()) {
	    System.err.println(warning + file + " does not exist");
	    return;
	}

	if (!file.isFile()) {
	    System.err.println(warning + file + " is not a file");
	    return;
	}

	if (!file.canRead()) {
	    System.err.println(warning + file + " is not readable");
	    return;
	}

	try {
	    FileInputStream fis = new FileInputStream(file);
	    props.load(fis);
	    fis.close();
	}
	catch (IOException ioe) {
	    System.err.println(warning + " an IOException occurred when attempting to read " + file);
	    System.err.println("The error message is: " + ioe.getMessage());
	}
    }

    private String getStringParameter(String[] args, String key) {
	if (args == null || key == null)
	    return null;

	for (int i = 0; i < args.length - 1; i++)
	    if (args[i].equalsIgnoreCase(key) && !args[i+1].startsWith("-"))
		return args[i+1];

	return null;
    }

    private boolean getBooleanParameter(String[] args, String key) {
	if (args == null || key == null)
	    return false;

	String notkey = "-no" + key.substring(1);

	boolean value = false;

	for (int i = 0; i < args.length; i++) {
	    if (args[i].equalsIgnoreCase(key))
		value = true;

	    if (args[i].equalsIgnoreCase(notkey))
		value = false;
	}

	return value;
    }

    private ArcturusDatabase createArcturusDatabase(String instance, String organism)
	throws NamingException, SQLException {
	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, env.get(Context.PROVIDER_URL));

	ArcturusInstance ai = new ArcturusInstance(props, instance);

	ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	return adb;
    }

    public ArcturusDatabase getArcturusDatabase() { return adb; }

    public String getUserProperty(String key) {
	return userProperties.getProperty(key);
    }

    public Object setUserProperty(String key, String value) {
	return userProperties.setProperty(key, value);
    }

    public String getSiteProperty(String key) {
	return siteProperties.getProperty(key);
    }

    public String getProperty(String key) {
	String value = siteProperties.getProperty(key);

	return (value != null) ? value : userProperties.getProperty(key);
    }
    
    /**
     * This method is required by the WindowListener interface.
     * It is a no-op because we are not interested in this type
     * of event.
     */
    public void windowActivated(WindowEvent event) {}

    /**
     * This method is required by the WindowListener interface.
     * It is a no-op because we are not interested in this type
     * of event.
     */
    public void windowDeactivated(WindowEvent event) {}

    /**
     * This method is required by the WindowListener interface.
     * It is a no-op because we are not interested in this type
     * of event.
     */
    public void windowIconified(WindowEvent event) {}

    /**
     * This method is required by the WindowListener interface.
     * It is a no-op because we are not interested in this type
     * of event.
     */
    public void windowDeiconified(WindowEvent event) {}

    /**
     * This method is required by the WindowListener interface.
     * It is a no-op because we are not interested in this type
     * of event.
     */
    public void windowClosing(WindowEvent event) {}

    /**
     * This method is required by the WindowListener interface.
     * We add the window to the set of active frames.
     */
    public void windowOpened(WindowEvent event) {
	java.awt.Window window = (java.awt.Window)event.getSource();
	activeFrames.add(window);
    }

    /**
     * This method is required by the WindowListener interface.
     */
    public void windowClosed(WindowEvent event) {
	java.awt.Window window = (java.awt.Window)event.getSource();
	activeFrames.remove(window);
    }

    public Vector getActiveFrames() {
	return (Vector)activeFrames.clone();
    }

    public void displayNewFrame(JFrame frame) {
	frame.addWindowListener(this);
	frame.pack();
	frame.show();
    }

    public void run() {
	SwingUtilities.invokeLater(new Runnable() {
		public void run() {
		    MinervaFrame frame = new ProjectTableFrame(Minerva.this);
		    displayNewFrame(frame);
		}
	    });
    }

    public static void main(String[] args) {
	Minerva minerva = new Minerva(args);

	minerva.run();
    }
}
