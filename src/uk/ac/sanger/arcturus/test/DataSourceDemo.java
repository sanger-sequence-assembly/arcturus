package uk.ac.sanger.arcturus.test;

import java.sql.Connection;
import javax.sql.DataSource;
import javax.naming.Context;
import javax.naming.InitialContext;
import java.util.Properties;

// Notice that the URL of the LDAP server is *not* hard-coded in the Java
// client. Instead, it is specified as a run-time property which can be
// set in a wrapper script:
//
// set JNDI_FACTORY=com.sun.jndi.ldap.LdapCtxFactory
// set JNDI_URL="ldap://ldap/cn=test,cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk"
// ...
// set JNDI_OPTS="-Djava.naming.factory.initial=$JNDI_FACTORY -Djava.naming.provider.url=$JNDI_URL"
// ...
// java $JNDI_OPTS ... DataSourceDemo args ...

public class DataSourceDemo {
    public static void main(String args) {
	try {
	    // 0. Create an LDAP context using parameters specified in the run-time
	    // properties.

	    Properties env = System.getProperties();

	    Context ctx = new InitialContext(env);

	    // 1. Create and bind a data source
	    
	    boolean useMysql = Boolean.getBoolean("mysql");

	    String alias;
	    DataSource ds1;

	    if (useMysql) {
		com.mysql.jdbc.jdbc2.optional.MysqlDataSource mysqlds =
		    new com.mysql.jdbc.jdbc2.optional.MysqlDataSource();

		mysqlds.setServerName("pcs3");
		mysqlds.setDatabaseName("EIMER");
		mysqlds.setPort(14642);
		mysqlds.setUser("arcturus");
		mysqlds.setPassword("myPassword");
		
		alias = "cn=EIMER";
		ds1 = mysqlds;
	    } else {
		oracle.jdbc.pool.OracleDataSource oracleds =
		    new oracle.jdbc.pool.OracleDataSource();

		oracleds.setServerName("ocs2");
		oracleds.setDatabaseName("wgs");
		oracleds.setPortNumber(1522);
		oracleds.setUser("pathlook");
		oracleds.setPassword("pathlook");
		oracleds.setDriverType("thin");

		alias = "cn=WGS";
		ds1 = oracleds;
	    }

	    ctx.bind(alias, ds1);

	    // 2. Lookup the data source

	    DataSource ds2 = (DataSource)ctx.lookup(alias);

	    // 3. Establish a connection to the database

	    Connection conn1 = ds2.getConnection();

	    // 4. Establish a second connection, over-riding the default username and
	    // password

	    Connection conn2 = ds2.getConnection("dba", "adminpassword");

	    // 5. Close the connections.

	    conn1.close();
	    conn2.close();
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }
}
