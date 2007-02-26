package uk.ac.sanger.arcturus;

import java.io.IOException;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.File;
import java.util.Properties;
import java.util.logging.*;
import java.awt.GraphicsEnvironment;

import uk.ac.sanger.arcturus.logging.*;

public class Arcturus {
	protected static final String PROJECT_PROPERTIES_FILE = ".arcturus.props";

	protected static Properties arcturusProps = new Properties(System.getProperties());
	protected static Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

	static {
		loadProperties();
		initialiseLogging();
	}
	
	private static void loadProperties() {
		// Load the properties that are embedded in the JAR file

		InputStream is = Arcturus.class.getResourceAsStream("/resources/arcturus.props");

		if (is != null) {
			try {
				arcturusProps.load(is);
				is.close();
			} catch (IOException ioe) {
				ioe.printStackTrace();
			}
		} else
			System.err.println("Unable to open resource /resources/arcturus.props as stream");

		// Find the project-specific properties, if they exist, by walking up
		// the
		// directory tree from the application's current working directory,
		// looking
		// for a file named .arcturus.props

		String cwd = System.getProperty("user.dir");

		File dir = new File(cwd);

		boolean found = false;

		while (dir != null && !found) {
			File file = new File(dir, PROJECT_PROPERTIES_FILE);

			if (file.exists() && file.canRead()) {
				try {
					FileInputStream fis = new FileInputStream(file);
					arcturusProps.load(fis);
					fis.close();
					found = true;
				} catch (IOException ioe) {
					ioe.printStackTrace();
				}
			} else
				dir = dir.getParentFile();
		}
	}

	public static Properties getProperties() {
		return arcturusProps;
	}

	public static String getProperty(String key) {
		return arcturusProps.getProperty(key);
	}

	public static String getDefaultInstance() {
		String instance = getProperty("arcturus.instance");

		if (instance != null)
			return instance;
		else
			return getProperty("arcturus.default.instance");
	}

	public static String getDefaultOrganism() {
		return getProperty("arcturus.organism");
	}

	private static void initialiseLogging() {
		Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

		logger.setUseParentHandlers(false);

		Handler warner = null;
		
		if (GraphicsEnvironment.isHeadless())
			warner = new ConsoleHandler();
		else
			warner = new MessageDialogHandler();

		warner.setLevel(Level.WARNING);

		logger.addHandler(warner);

		try {
			FileHandler filehandler = new FileHandler("%h/.arcturus/arcturus%u.%g.log");
			filehandler.setLevel(Level.INFO);
			filehandler.setFormatter(new SimpleFormatter());
			logger.addHandler(filehandler);
		} catch (IOException ioe) {
			logger.log(Level.WARNING,
					"Unable to create a FileHandler for logging", ioe);
		}

		try {
			Properties props = Arcturus.getProperties();
			JDBCLogHandler jdbcloghandler = new JDBCLogHandler(props);
			jdbcloghandler.setLevel(Level.INFO);
			logger.addHandler(jdbcloghandler);
		} catch (Exception e) {
			logger.log(Level.WARNING,
					"Unable to create a JDBCLogHandler for logging", e);
		}

		System.err.println("Using logger " + logger.getName());
	}

	public static void log(Level level, String message, Throwable throwable) {
		logger.log(level, message, throwable);
	}

	public static void log(Level level, String message) {
		logger.log(level, message);
	}

	public static void logInfo(String message) {
		logger.log(Level.INFO, message);
	}

	public static void logWarning(String message) {
		logger.log(Level.WARNING, message);
	}

	public static void logWarning(Throwable throwable) {
		logger.log(Level.WARNING, throwable.getMessage(), throwable);
	}

	public static void logWarning(String message, Throwable throwable) {
		logger.log(Level.WARNING, message, throwable);
	}

	public static void logSevere(String message) {
		logger.log(Level.SEVERE, message);
	}

	public static void logSevere(Throwable throwable) {
		logger.log(Level.SEVERE, throwable.getMessage(), throwable);
	}

	public static void logSevere(String message, Throwable throwable) {
		logger.log(Level.SEVERE, message, throwable);
	}
}
