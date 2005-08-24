package uk.ac.sanger.arcturus.gui;

import java.awt.event.*;
import javax.swing.*;
import java.awt.Dimension;
import java.util.*;
import java.io.*;
import javax.naming.NamingException;
import javax.naming.Context;
import java.sql.SQLException;
import java.awt.Color;
import java.util.prefs.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.*;

import uk.ac.sanger.arcturus.gui.projecttable.ProjectTableFrame;

/**
 * This class is the main class for all GUI applications.
 * It manages the shared ArcturusDatabase objects and maintains
 * a list of all active frames.
 */

public class Minerva implements WindowListener {
    private static Minerva instance = null;

    protected Vector activeFrames = new Vector();
    protected Properties ldapProps = new Properties();
    protected HashMap databases = new HashMap();
    protected HashMap instances = new HashMap();

    protected Preferences appPrefs = Preferences.userNodeForPackage(getClass());

    public static Minerva getInstance() {
	if (instance == null)
	    instance = new Minerva();

	return instance;
    }

    private Minerva() {
	Properties env = System.getProperties();

	ldapProps.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	ldapProps.put(Context.PROVIDER_URL, env.get(Context.PROVIDER_URL));
    }

    private ArcturusDatabase createArcturusDatabase(String instance, String organism)
	throws NamingException, SQLException {
	ArcturusInstance ai = (ArcturusInstance)instances.get(instance);

	if (ai == null) {
	    ai = new ArcturusInstance(ldapProps, instance);
	    instances.put(instance, ai);
	}

	if (ai != null) {
	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	    databases.put(organism, adb);

	    return adb;
	} else
	    return null;
    }

    public ArcturusDatabase getArcturusDatabase(String instance, String organism)
	throws NamingException, SQLException {
	String key = instance + "/" + organism;
	ArcturusDatabase adb = (ArcturusDatabase)databases.get(organism);

	if (adb == null) {
	    adb = createArcturusDatabase(instance, organism);

	    if (adb != null)
		databases.put(organism, adb);
	}

	return adb;
    }

    public Color getColourForProject(String assembly, String project) {
	Preferences prefs = appPrefs.node(assembly);
	prefs = prefs.node(project);

	int icol = prefs.getInt("colour", -1);

	return (icol < 0) ? null : new Color(icol);
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

    public void run(final String[] args) {
	SwingUtilities.invokeLater(new Runnable() {
		public void run() {
		    restoreOldSessions();
		    createNewSessions(args);
		}
	    });
    }

    private void restoreOldSessions() {}

    private void createNewSessions(String[] args) {
	String instance = getStringParameter(args, "-instance");
	String organism = getStringParameter(args, "-organism");

	if (instance != null && organism != null) {
	    try {
		ArcturusDatabase adb = getArcturusDatabase(instance, organism);
		if (adb != null) {
		    MinervaFrame frame = new ProjectTableFrame(this, adb);
		    displayNewFrame(frame);
		}
	    }
	    catch (Exception e) {
		e.printStackTrace();
	    }
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

    public static void main(String[] args) {
	Minerva minerva = Minerva.getInstance();
	minerva.run(args);
    }
}
