package uk.ac.sanger.arcturus.test;

import java.sql.Connection;
import javax.sql.DataSource;

import java.io.IOException;
import java.io.InputStream;

import javax.naming.Context;
import javax.naming.InitialContext;

import java.util.Properties;

public class DataSourceDemo {
	public static void main(String[] args) {
		DataSourceDemo demo = new DataSourceDemo();
		try {
			demo.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
		System.exit(0);
	}

	private Properties props = new Properties();

	public void run() throws Exception {
		// 0. Create an LDAP context using parameters specified in the
		// properties file.
		
		loadProperties();

		Context ctx = new InitialContext(props);

		// 1. Create and bind a data source

		String dstype = System.getProperty("type", "mysql");
		
		String alias = null;
		DataSource ds1 = null;

		if (dstype.equalsIgnoreCase("mysql")) {
			com.mysql.jdbc.jdbc2.optional.MysqlDataSource mysqlds = new com.mysql.jdbc.jdbc2.optional.MysqlDataSource();

			mysqlds.setServerName("mcs3a");
			mysqlds.setDatabaseName("EIMER");
			mysqlds.setPort(15001);
			mysqlds.setUser("arcturus");
			mysqlds.setPassword("***REMOVED***");

			alias = "cn=EIMER";
			ds1 = mysqlds;
		} else if (dstype.equalsIgnoreCase("oracle")){
			oracle.jdbc.pool.OracleDataSource oracleds = new oracle.jdbc.pool.OracleDataSource();

			oracleds.setServerName("ocs2");
			oracleds.setDatabaseName("wgs");
			oracleds.setPortNumber(1522);
			oracleds.setUser("pathlook");
			oracleds.setPassword("pathlook");
			oracleds.setDriverType("thin");

			alias = "cn=WGS";
			ds1 = oracleds;
		} else if (dstype.equalsIgnoreCase("postgresql")) {
			org.postgresql.ds.PGSimpleDataSource pgds = new org.postgresql.ds.PGSimpleDataSource();
			
			pgds.setServerName("pcs4d");
			pgds.setPortNumber(15003);
			pgds.setDatabaseName("test");
			pgds.setUser("arcturus");
			pgds.setPassword("***REMOVED***");
			
			pgds.setPrepareThreshold(1);
			
			alias = "cn=pgtest";
			ds1 = pgds;
		} else
			throw new Exception("Unknown datasource type: " + dstype);

		ctx.bind(alias, ds1);

		// 2. Lookup the data source

		DataSource ds2 = (DataSource) ctx.lookup(alias);

		// 3. Establish a connection to the database

		Connection conn1 = ds2.getConnection();

		// 4. Establish a second connection, over-riding the default
		// user-name and password

		Connection conn2 = ds2.getConnection("dba", "adminpassword");

		// 5. Close the connections.

		conn1.close();
		conn2.close();
	}

	protected void loadProperties() throws IOException {
		InputStream is = getClass().getResourceAsStream("datasourcedemo.props");
		props.load(is);
		is.close();
	}
}
