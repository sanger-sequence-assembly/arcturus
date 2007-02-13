package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

import java.sql.*;
import java.io.*;

public class TestFreeReads {
	private String instance = null;
	private String organism = null;
	private String username = null;
	private String password = null;
	
	private ArcturusDatabase adb = null;
	private Connection conn = null;
	
	public static void main(String[] args) {
		TestFreeReads tfr = new TestFreeReads();
		tfr.execute(args);
	}

	public void execute(String args[]) {
		System.err.println("TestFreeReads");
		System.err.println("=============");
		System.err.println();
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
			
			if (args[i].equalsIgnoreCase("-username"))
				username = args[++i];
			
			if (args[i].equalsIgnoreCase("-password"))
				password = args[++i];
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			System.err.flush();

			adb = ai.findArcturusDatabase(organism);

			conn = (username == null || password == null ) ?
					adb.getConnection() : adb.getConnection(username, password);
			
			String sql = "{call procFreeReads}";
			
			CallableStatement cstmt = conn.prepareCall(sql);
			
			cstmt.execute();
			
			while (cstmt.getMoreResults() || cstmt.getUpdateCount() != -1) {
				int updateCount = cstmt.getUpdateCount();
				
				if (updateCount == -1) {
					int rows = 0;
					
					ResultSet rs = cstmt.getResultSet();
					
					while (rs.next())
						rows++;
					
					System.out.println("ResultSet with " + rows + " rows");
				} else {
					System.out.println("Update count = " + updateCount);
				}
			}

			conn.close();
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-username\tUsername for database connection");
		ps.println("\t-password\tPassword for database connection");
	}

}
