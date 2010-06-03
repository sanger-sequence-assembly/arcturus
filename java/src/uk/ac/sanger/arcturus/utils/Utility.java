package uk.ac.sanger.arcturus.utils;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Properties;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class Utility {
	private static final String PROPS_FILENAME = ".arcturus/testdb.props";
	
	public static ArcturusDatabase getTestDatabase() throws ArcturusDatabaseException {
		String instanceName = System.getProperty("testdb.instance");
		String databaseName = System.getProperty("testdb.organism");
		
		if (instanceName == null || databaseName == null) {
			String propsFilename = System.getProperty("testdb.props");

			File testprops = propsFilename == null ? new File(System
					.getProperty("user.home"), PROPS_FILENAME) : new File(
					propsFilename);

			Properties props = new Properties();

			if (testprops.exists() && testprops.canRead()) {
				try {
					InputStream is = new FileInputStream(testprops);

					props.load(is);

					is.close();
				} catch (IOException e) {
					throw new ArcturusDatabaseException(e,
							"Failed to load properties from file " + testprops);
				}
			}

			instanceName = props.getProperty("instance");

			databaseName = props.getProperty("organism");
		}
		
		if (instanceName == null)
			throw new ArcturusDatabaseException(null, "Test instance name is not defined");
		
		if (databaseName == null)
			throw new ArcturusDatabaseException(null, "Test organism name is not defined");

		ArcturusInstance instance = null;

		try {
			instance = ArcturusInstance.getInstance(instanceName);
		} catch (NamingException e) {
			throw new ArcturusDatabaseException(e,
					"Failed to find a database named " + databaseName
							+ " in instance " + instanceName);
		}

		ArcturusDatabase adb = instance.findArcturusDatabase(databaseName);
		
		if (verifyThatThisIsATestDatabase(adb)) {
			return adb;
		} else {
			adb.closeConnectionPool();
			throw new ArcturusDatabaseException("The database is not a valid test database");
		}
	}
	
	private final static String VERIFY_COMMAND = "select count(*) from THIS_IS_A_TEST_DATABASE";
	
	private static boolean verifyThatThisIsATestDatabase(ArcturusDatabase adb)
		throws ArcturusDatabaseException {
		Connection conn = adb.getDefaultConnection();
		
		try {
			Statement stmt = conn.createStatement();
			stmt.execute(VERIFY_COMMAND);
			stmt.close();
			return true;
		}
		catch (SQLException e) {
			return false;
		}
	}

}
