package test;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.Statement;
import java.sql.SQLException;
import java.util.Properties;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class Utility {
	public static ArcturusDatabase getTestDatabase() throws ArcturusDatabaseException {
		InputStream is = Utility.class
				.getResourceAsStream("test.props");

		Properties props = new Properties();

		try {
			props.load(is);

			is.close();
		} catch (IOException e) {
			throw new ArcturusDatabaseException(e, "Failed to load properties");
		}

		String instanceName = props.getProperty("instance");
		
		if (instanceName == null)
			throw new ArcturusDatabaseException(null, "Test instance name is not defined");
		
		String databaseName = props.getProperty("organism");
		
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
			clearDatabase(adb);
			return adb;
		} else {
			adb.closeConnectionPool();
			return null;
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

	private final static String[] COMMANDS = {
		"delete from SEQUENCE",
		"delete from READINFO",
		"delete from TEMPLATE",
		"delete from LIGATION",
		"delete from CLONE"
	};
	
	private static void clearDatabase(ArcturusDatabase adb) throws ArcturusDatabaseException {
		Connection conn = adb.getDefaultConnection();
		
		Statement stmt = null;
		
		try {
			stmt = conn.createStatement();
		}
		catch (SQLException e) {
			throw new ArcturusDatabaseException(e, "An error occurred whilst creating a statement");
		}
		
		for (String command : COMMANDS) {
			try {
				stmt.execute(command);
			}
			catch (SQLException e) {
				throw new ArcturusDatabaseException(e,
						"An error occurred whilst clearing the database.  The command being executed was: \"" + command + "\"");
			}
		}
		
		try {
			stmt.close();
		} catch (SQLException e) {
			throw new ArcturusDatabaseException(e, "An error occurred whilst closing the statement");
		}
	}
	
	public static void main(String[] args) {		
		try {
			ArcturusDatabase adb = Utility.getTestDatabase();
			
			if (adb != null) {
				adb.closeConnectionPool();
				System.out.println("If you are reading this message, everything worked.");
			} else {
				System.out.println("If you are reading this message, the ArcturusDatabase object was null.");
			}
		} catch (ArcturusDatabaseException e) {
			e.printStackTrace();
			System.out.println("If you are reading this message, something unexpected happened.");			
		} finally {
			System.exit(0);
		}
	}
}
