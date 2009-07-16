package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

import java.sql.*;
import java.io.*;

public class TestFreeReads {
	private String instance = null;
	private String organism = null;

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
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			System.out.flush();

			adb = ai.findArcturusDatabase(organism);

			conn = adb.getConnection();

			String sql = "{call procFreeReads}";

			CallableStatement cstmt = conn.prepareCall(sql);

			if (cstmt.execute()) {
				ResultSet rs = cstmt.getResultSet();

				if (rs != null) {
					int rows = 0;

					while (rs.next())
						rows++;

					System.out.println("ResultSet with " + rows + " rows");
				}
			}

			conn.close();
		} catch (Exception e) {
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
