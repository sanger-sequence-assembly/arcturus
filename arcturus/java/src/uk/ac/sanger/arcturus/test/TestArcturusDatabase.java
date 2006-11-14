package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

import javax.naming.*;
import javax.sql.*;
import java.sql.*;
import java.util.*;
import java.text.SimpleDateFormat;

public class TestArcturusDatabase {
	private static SimpleDateFormat dateformat = new SimpleDateFormat(
			"yyyy-MM-dd 'at' kk:mm:ss z");

	public static void main(String args[]) {
		System.out.println("TestArcturusDatabase");
		System.out.println("====================");
		System.out.println();

		String separator = "                    --------------------                    ";

		try {
			System.out.println("TEST 0: Creating an ArcturusInstance");
			System.out.println();

			ArcturusInstance ai = Arcturus.getArcturusInstance("dev");

			System.out.println("Created " + ai);

			System.out.println();
			System.out.println(separator);
			System.out.println();

			System.out.println("TEST 1: Looking up EIMER");
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase("EIMER");

			testArcturusDatabase(adb);

			System.out.println();
			System.out.println(separator);
			System.out.println();

			System.out.println("TEST 2: Iterating over the entries");
			System.out.println();

			listEntries(ai);

			System.out.println();
			System.out.println(separator);
			System.out.println();

			System.out
					.println("TEST 3: Creating and binding a new ArcturusDatabase");
			System.out.println();

			Properties props = Arcturus.getProperties();
			
			setLDAPCredentials(props);

			ai = Arcturus.getArcturusInstance("test");

			System.out.println("Created " + ai);

			System.out.println();
			System.out.println();

			System.out.println("Listing:");
			System.out.println();

			listEntries(ai);

			String description = "Streptomyces scabies";
			String name = "SCAB";

			System.out.println();

			DataSource ds = ArcturusDatabase.createMysqlDataSource("pcs3",
					14642, "SCAB", "arcturus", "***REMOVED***");

			adb = new ArcturusDatabase(ds, description, name);

			System.out.println("Testing new ArcturusDatabase object");

			testArcturusDatabase(adb);

			System.out.println();

			ai.putArcturusDatabase(adb, name);

			System.out.println("Listing:");
			System.out.println();

			listEntries(ai);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public static void listEntries(ArcturusInstance ai) {
		Iterator iter = ai.iterator();

		while (iter.hasNext()) {
			ArcturusDatabase adb = (ArcturusDatabase) iter.next();

			try {
				testArcturusDatabase(adb);
			} catch (SQLException sqle) {
				System.out.println("SQLException: " + sqle.getMessage());
			}

			System.out.println();
		}
	}

	public static void setLDAPCredentials(Properties props) {
		props.put(Context.SECURITY_AUTHENTICATION, "simple");
		props.put(Context.SECURITY_PRINCIPAL,
				"cn=Manager,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk");
		props.put(Context.SECURITY_CREDENTIALS, "murgatroyd");
	}

	public static void testArcturusDatabase(ArcturusDatabase adb)
			throws SQLException {
		System.out.println(adb);
		Connection conn = adb.getConnection();
		DatabaseMetaData dmd = conn.getMetaData();
		System.out.println("Connection URL = " + dmd.getURL());

		String query = "select count(*),sum(nreads),sum(length),round(avg(length)),round(std(length)),max(length),max(updated)"
				+ " from CONTIG left join C2CMAPPING on CONTIG.contig_id = C2CMAPPING.parent_id"
				+ " where C2CMAPPING.parent_id is null and length >= ?";

		PreparedStatement pstmt = conn.prepareStatement(query);

		pstmt.setInt(1, 2000);

		ResultSet rs = pstmt.executeQuery();

		if (rs.next()) {
			int nContigs = rs.getInt(1);
			int nReads = rs.getInt(2);
			int nLength = rs.getInt(3);
			int avgLength = rs.getInt(4);
			int stdLength = rs.getInt(5);
			int maxLength = rs.getInt(6);
			java.sql.Timestamp updated = rs.getTimestamp(7);

			System.out.print(nContigs + " contigs, containing " + nReads
					+ " reads and " + nLength + " bp (length stats: "
					+ avgLength + " +/- " + stdLength + ", max " + maxLength);

			if (updated != null)
				System.out.print(", most recent " + dateformat.format(updated));

			System.out.println(")");
		}

		rs.close();
		pstmt.close();
		conn.close();
	}
}
