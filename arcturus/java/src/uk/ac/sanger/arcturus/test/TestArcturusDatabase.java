import arcturus.database.*;

import javax.naming.*;
import javax.sql.*;
import java.sql.*;
import java.util.Properties;

public class TestArcturusDatabase {
    public static void main(String args[]) {
	System.out.println("TestArcturusDatabase");
	System.out.println("====================");
	System.out.println();

	try {
	    testExistingDatabase("cn=dev,cn=jdbc", "cn=EIMER");
	}
	catch (Exception e) {
	    e.printStackTrace();
	}

	DataSource ds = null;

	try {
	    ds = testNewMysqlDatabase("pcs3", 14642, "EIMER", "arcturus", "***REMOVED***");
	}
	catch (Exception e) {
	    e.printStackTrace();
	}

	setLDAPCredentials();

	try {
	    testBindDataSource(ds, "cn=test,cn=jdbc", "cn=EIMER");
	}
	catch (Exception e) {
	    e.printStackTrace();
	}

	try {
	    testExistingDatabase("cn=test,cn=jdbc", "cn=EIMER");
	}
	catch (Exception e) {
	    e.printStackTrace();
	}
    }

    public static void setLDAPCredentials() {
	Properties env = System.getProperties();

	env.put(Context.SECURITY_AUTHENTICATION,
		"simple");
	env.put(Context.SECURITY_PRINCIPAL,
		"cn=Manager,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk");
	env.put(Context.SECURITY_CREDENTIALS,
		"murgatroyd");
    }

    public static void testExistingDatabase(String instance, String organism)
	throws NamingException, SQLException {
	System.out.println("testExistingDatabase(\"" + instance + "\", \"" + organism + "\")");
	ArcturusDatabase adb = new ArcturusDatabase(instance, organism);
	Connection conn = adb.getConnection();
	DatabaseMetaData dmd = conn.getMetaData();
	System.out.println("Connection URL = " + dmd.getURL());
	conn.close();
    }

    public static DataSource testNewMysqlDatabase(String hostname, int port, String database,
						  String username, String password)
	throws SQLException {
	System.out.println("testNewMysqlDatabase(\"" + hostname + ", " + port + ", \"" + database +
			   "\", \"" + username + "\", \"" + password +
			   "\")");
	DataSource ds = ArcturusDatabase.createMysqlDataSource(hostname, port, database,
							       username, password);

	if (ds != null) {
	    Connection conn = ds.getConnection();
	    DatabaseMetaData dmd = conn.getMetaData();
	    System.out.println("Connection URL = " + dmd.getURL());
	    conn.close();
	    
	}

	return ds;
    }

    public static void testBindDataSource(DataSource ds, String instance, String organism)
	throws SQLException, NamingException {
	System.out.println("testBindDataSource(" + ds + ", \"" + instance + "\", \"" +
			   organism + "\")");
	ArcturusDatabase adb = new ArcturusDatabase(ds);
	adb.bind(instance, organism);
    }
}
