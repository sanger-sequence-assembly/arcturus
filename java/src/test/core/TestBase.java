package test.core;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestBase {
	public ArcturusDatabase getTestDatabase() throws ArcturusDatabaseException {
		InputStream is = TestBase.class
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

		return instance.findArcturusDatabase(databaseName);
	}
	
	public static void main(String[] args) {
		TestBase tb = new TestBase();
		
		try {
			ArcturusDatabase adb = tb.getTestDatabase();
			
			adb.closeConnectionPool();
		} catch (ArcturusDatabaseException e) {
			e.printStackTrace();
		}
		
		System.exit(0);
	}
}
