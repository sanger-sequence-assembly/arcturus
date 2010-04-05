package uk.ac.sanger.arcturus;

import java.awt.GraphicsEnvironment;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.lang.management.ManagementFactory;
import java.net.BindException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.Properties;
import java.util.logging.ConsoleHandler;
import java.util.logging.FileHandler;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;

import javax.management.MBeanServer;
import javax.management.remote.JMXConnectorServer;
import javax.management.remote.JMXConnectorServerFactory;
import javax.management.remote.JMXServiceURL;

import uk.ac.sanger.arcturus.logging.JDBCLogHandler;
import uk.ac.sanger.arcturus.logging.LongMessageFormatter;
import uk.ac.sanger.arcturus.logging.MailHandler;
import uk.ac.sanger.arcturus.logging.MessageDialogHandler;

public class Arcturus {
	protected static final String PROJECT_PROPERTIES_FILE = ".arcturus.props";

	public final static String BUILD_DATE_KEY = "build.date";
	public final static String BUILD_VERSION_KEY = "build.version";
	public final static String BUILD_BY_KEY = "build.by";
	public final static String BUILD_HOST_KEY = "build.host";


	protected static Properties arcturusProps = new Properties(System
			.getProperties());
	protected static Logger logger = Logger.getLogger("uk.ac.sanger.arcturus");

	protected static long jarFileTimestamp = 0L;
	
	protected static final boolean LINUX; 

	static {
		setJarFileTimestamp();
		loadProperties();
		initialiseLogging();
		initialiseJMXRemoteServer();
		
		String osname = System.getProperty("os.name");
		
		LINUX = osname != null && osname.equalsIgnoreCase("linux")
			&& !Boolean.getBoolean("emulateWindows");
	}
	
	public static boolean isLinux() {
		return LINUX;
	}

	private static void setJarFileTimestamp() {
		String jarfilename = System.getProperty("arcturus.jar");

		if (jarfilename != null) {
			File jarfile = new File(jarfilename);

			if (jarfile.exists())
				jarFileTimestamp = jarfile.lastModified();
		}

		if (jarFileTimestamp > 0) {
			java.util.Date date = new java.util.Date(jarFileTimestamp);
			System.err.println("JAR file was last modified at " + date);
		}
	}

	public static long getJarFileTimestamp() {
		return jarFileTimestamp;
	}

	private static void loadProperties() {
		// Load the properties in the user's private version of the properties
		// file,
		// if it exists. If not, use the properties file in the JAR file.

		File userhome = new File(System.getProperty("user.home"));
		File dotarcturus = new File(userhome, ".arcturus");
		File privateprops = (dotarcturus != null && dotarcturus.isDirectory()) ? new File(
				dotarcturus, "arcturus.props")
				: null;

		InputStream is = null;

		if (privateprops != null && privateprops.isFile()
				&& privateprops.canRead()) {
			try {
				is = new FileInputStream(privateprops);
			} catch (FileNotFoundException fnfe) {
				System.err.println("Failed to open properties file "
						+ privateprops.getPath());
				System.exit(1);
			}
		} else
			is = Arcturus.class
					.getResourceAsStream("/resources/arcturus.props");

		if (is != null) {
			try {
				arcturusProps.load(is);
				is.close();
			} catch (IOException ioe) {
				ioe.printStackTrace();
			}
		} else {
			System.err.println("Unable to find a resource file");
			System.exit(2);
		}

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
		
		loadBuildProperties();
	}

	private static void loadBuildProperties() {
		try {
			InputStream is = Arcturus.class.getResourceAsStream("/resources/build.props");
			if (is != null) {
				arcturusProps.load(is);
				is.close();
			}
		} catch (IOException ioe) {
			// Do nothing
		}		
	}
	
	private static void initialiseJMXRemoteServer() {
		String hostname = "UNKNOWN";
		
		try {
			hostname = InetAddress.getLocalHost().getHostName();
		} catch (UnknownHostException e1) {
		}

		try {
			String url = "service:jmx:jmxmp://" + hostname + "/";

			MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();

			JMXServiceURL jurl = new JMXServiceURL(url);

			JMXConnectorServer server = JMXConnectorServerFactory
					.newJMXConnectorServer(jurl, null, mbs);

			server.start();

			jurl = server.getAddress();

			System.err.println("JMX URL is " + jurl);

			storeJMXURL(jurl);
		} catch (BindException be) {
			//logInfo("Bind exception whilst initialising JMX remote server on "
			//		+ hostname, be);
			System.err
					.println("Bind exception whilst initialising JMX remote server on "
							+ hostname);
			reportBindException("adh@sanger.ac.uk", be);
		} catch (Exception e) {
			logWarning("Error whilst initialising JMX remote server", e);
		}
	}

	private static void reportBindException(String recipient, BindException be) {
		MailHandler handler = new MailHandler(recipient);
		LogRecord record = new LogRecord(Level.INFO,
				"Bind exception whilst initialising JMX remote server");
		record.setThrown(be);
		handler.publish(record);
		handler.close();
	}

	private static void storeJMXURL(JMXServiceURL jurl) throws SQLException,
			ClassNotFoundException {
		String url = getProperty("jmxdb.url");

		String driver = "com.mysql.jdbc.Driver";

		String username = getProperty("jmxdb.username");
		String password = getProperty("jmxdb.password");

		Class.forName(driver);

		Connection conn = DriverManager.getConnection(url, username, password);

		String sql = "insert into JMXURL(url,user) values (?,?)";

		PreparedStatement pstmtInsert = conn.prepareStatement(sql);

		String user = System.getProperty("user.name");

		pstmtInsert.setString(1, jurl.toString());
		pstmtInsert.setString(2, user);

		pstmtInsert.executeUpdate();

		pstmtInsert.close();

		conn.close();
	}

	public static Properties getProperties() {
		return arcturusProps;
	}

	public static String getProperty(String key) {
		return arcturusProps.getProperty(key);
	}
	
	public static String getProperty(String key, String defaultValue) {
		String value = getProperty(key);
		return (value == null) ? defaultValue : value;
	}
	
	public static boolean getBoolean(String key) {
		String value = arcturusProps.getProperty(key);
		
		return value != null && value.equalsIgnoreCase("true");
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

		if (GraphicsEnvironment.isHeadless()
				|| Boolean.getBoolean("useConsoleLogHandler"))
			warner = new ConsoleHandler();
		else
			warner = new MessageDialogHandler();

		warner.setLevel(Level.INFO);

		logger.addHandler(warner);

		try {
			File homedir = new File(System.getProperty("user.home"));

			File dotarcturus = new File(homedir, ".arcturus");

			if (dotarcturus.exists() || dotarcturus.mkdir()) {
				FileHandler filehandler = new FileHandler(
						"%h/.arcturus/arcturus%u.%g.log");
				filehandler.setLevel(Level.INFO);
				filehandler.setFormatter(new LongMessageFormatter());
				logger.addHandler(filehandler);
			} else
				throw new IOException(
						".arcturus directory could not be created");
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

		if (!Boolean.getBoolean("testing")) {
			try {
				MailHandler mailhandler = new MailHandler(null);
				mailhandler.setLevel(Level.WARNING);
				logger.addHandler(mailhandler);
			} catch (Exception e) {
				logger.log(Level.WARNING,
						"Unable to create a MailHandler for logging", e);
			}
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

	public static void logInfo(Throwable throwable) {
		logger.log(Level.INFO, throwable.getMessage(), throwable);
	}

	public static void logInfo(String message, Throwable throwable) {
		logger.log(Level.INFO, message, throwable);
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
