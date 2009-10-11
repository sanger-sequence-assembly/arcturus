package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.Arcturus;

import java.io.*;
import java.net.*;
import java.util.*;
import java.util.zip.*;

public class TestArcturusUpdater {
	private static final String JAR_FILE_NAME = "arcturus.jar";

	public static void main(String[] args) {
		TestArcturusUpdater tau = new TestArcturusUpdater();
		tau.run();
	}

	public void run() {
		String classpath = System.getProperty("java.class.path");
		String pathsep = System.getProperty("path.separator");

		String[] pathitems = classpath.split(pathsep);

		Date jardate = null;
		String jarname = null;

		for (int i = 0; i < pathitems.length; i++) {
			System.out.println(pathitems[i]);

			if (pathitems[i].endsWith(JAR_FILE_NAME)) {
				File jarfile = new File(pathitems[i]);

				if (jarfile.exists() && jarfile.isFile() && jardate == null) {
					try {
						jarname = jarfile.getCanonicalPath();
					} catch (IOException e) {
						e.printStackTrace();
					}
					jardate = new Date(jarfile.lastModified());
				}
			}
		}

		if (jardate == null)
			System.out.println("Unable to determine date of JAR file");
		else
			System.out.println("JAR file " + jarname + " last modified at " + jardate);

		String locator = Arcturus.getProperty("arcturus.update.url");

		Date zipjardate = findZipJARDate(locator);
		
		if (zipjardate == null)
			System.out.println("Unable to determine date of zip file JAR");
		else
			System.out.println("Zip JAR file last modified at " + zipjardate);
		
		if (jardate != null && zipjardate != null && zipjardate.compareTo(jardate) > 0)
			System.out.println("There is a more recent version of Arcturus at " + locator);
	}

	private Date findZipJARDate(String locator) {
		try {
			URL url = new URL(locator);
			URLConnection conn = url.openConnection();
			InputStream is = conn.getInputStream();
			ZipInputStream zis = new ZipInputStream(is);

			ZipEntry entry;

			while ((entry = zis.getNextEntry()) != null) {
				if (entry.getName().endsWith(JAR_FILE_NAME)) {
					zis.close();
					return new Date(entry.getTime());
				}
			}
			
			zis.close();
		}
		catch (IOException ioe) {
			ioe.printStackTrace();
		}
		
		return null;
	}
}
