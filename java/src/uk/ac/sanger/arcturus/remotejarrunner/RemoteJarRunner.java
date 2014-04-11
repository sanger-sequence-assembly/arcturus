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

package uk.ac.sanger.arcturus.remotejarrunner;

import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.JarURLConnection;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.InvocationTargetException;
import java.util.Properties;
import java.util.jar.Attributes;
import java.io.IOException;
import java.io.InputStream;

import javax.swing.JOptionPane;

public class RemoteJarRunner {
	private String url;
	private URLClassLoader cl;

	public RemoteJarRunner(String url) throws MalformedURLException {
		this.url = url;		
		initUrl();
	}
	
	public RemoteJarRunner() throws MalformedURLException {
		this.url = getUrlFromProperties();
		initUrl();
	}
			
	private void initUrl() throws MalformedURLException {	
		URL jarUrl = new URL(url);

		cl = new URLClassLoader(new URL[] { jarUrl }, Thread.currentThread().getContextClassLoader());
		
		Thread.currentThread().setContextClassLoader(cl);
	}

	protected String getUrlFromProperties() {
		String jarURL = System.getProperty("arcturus.remotejarrunner.url");
		
		if (jarURL != null) {
			System.err.println("Using user-defined URL for application JAR file: " + jarURL);
			return jarURL;
		}
		
		try {
			InputStream is = getClass().getResourceAsStream("/resources/remotejarrunner.props");
			
			Properties props = new Properties();
			
			props.load(is);
			
			is.close();
			
			return props.getProperty("arcturus.remotejarrunner.url");
		} catch (IOException ioe) {
			String message = "An error occurred: " + ioe.getMessage();
			JOptionPane.showMessageDialog(null, message,
					"Failed to load preferences", JOptionPane.ERROR_MESSAGE);
			System.exit(1);
		}
		
		return null;
	}

	/**
	 * Returns the name of the jar file main class, or null if no "Main-Class"
	 * manifest attributes was defined.
	 */
	public String getMainClassName() throws IOException {
		URL u = new URL("jar", "", url + "!/");
		JarURLConnection uc = (JarURLConnection) u.openConnection();
		Attributes attr = uc.getMainAttributes();
		return attr != null ? attr.getValue(Attributes.Name.MAIN_CLASS) : null;
	}

	/**
	 * Invokes the application in this jar file given the name of the main class
	 * and an array of arguments. The class must define a static method "main"
	 * which takes an array of String arguemtns and is of return type "void".
	 * 
	 * @param name
	 *            the name of the main class
	 * @param args
	 *            the arguments for the application
	 * @exception ClassNotFoundException
	 *                if the specified class could not be found
	 * @exception NoSuchMethodException
	 *                if the specified class does not contain a "main" method
	 * @exception InvocationTargetException
	 *                if the application raised an exception
	 */
	public void invokeClass(String name, String[] args)
			throws ClassNotFoundException, NoSuchMethodException,
			InvocationTargetException {
		Class<?> c = cl.loadClass(name);
		Method m = c.getMethod("main", new Class[] { args.getClass() });
		m.setAccessible(true);
		int mods = m.getModifiers();
		if (m.getReturnType() != void.class || !Modifier.isStatic(mods)
				|| !Modifier.isPublic(mods)) {
			throw new NoSuchMethodException("main");
		}
		try {
			m.invoke(null, new Object[] { args });
		} catch (IllegalAccessException e) {
			// This should not happen, as we have disabled access checks
		}
	}

	public static void main(String[] args) {
		// This system property causes Mac OS X to put Swing menus in
		// the Mac OS menu bar at the top of the screen.
		System.setProperty("com.apple.macos.useScreenMenuBar", "true");
		
		RemoteJarRunner runner = null;
		
		try {
			runner = new RemoteJarRunner();
		} catch (MalformedURLException e1) {
			e1.printStackTrace();
		}

		// Get the application's main class name
		String name = null;
		
		try {
			name = runner.getMainClassName();
		} catch (IOException e) {
			System.err.println("I/O error while loading JAR file:");
			e.printStackTrace();
			System.exit(1);
		}
		
		if (name == null) {
			System.err.println("Specified jar file does not contain a 'Main-Class'"
					+ " manifest attribute");
			System.exit(1);
		}
		
		// Invoke application's main class
		try {
			runner.invokeClass(name, args);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
