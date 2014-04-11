// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.consistencychecker;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.io.*;
import java.util.List;
import java.text.MessageFormat;
import java.util.Vector;

import org.xml.sax.SAXException;

import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

import com.mysql.jdbc.exceptions.MySQLStatementCancelledException;

public class CheckConsistency {
	// This error code corresponds to the server error ER_QUERY_INTERRUPTED, but that
	// symbol does not appear in the set of constants defined in com.mysql.jdbc.MysqlErrorCodes
	// so we define it here.
	private static final int MYSQL_QUERY_INTERRUPTED = 1317;
	
	protected CheckConsistencyListener listener = null;
	
	protected List<Test> tests;
	
	protected boolean cancelled = false;
	
	protected Statement stmt = null;
	
	protected String failedTestMessage = "";
	
	protected static Vector <String> emailRecipients = new Vector<String> ();
	
	public CheckConsistency(InputStream is) throws SAXException, IOException, ParserConfigurationException {
		tests = parseXML(is);
	}
	
	private List<Test> parseXML(InputStream is) throws SAXException, IOException, ParserConfigurationException {
		MyHandler handler = new MyHandler();
		SAXParserFactory factory = SAXParserFactory.newInstance();
		factory.setValidating(true);
		
		SAXParser saxParser = factory.newSAXParser();
		saxParser.parse(is, handler);

		return handler.getTests();
	}

	public void checkConsistency(ArcturusDatabase adb, CheckConsistencyListener listener)
		throws ArcturusDatabaseException {
		checkConsistency(adb, listener, true);
	}
	
	public void checkConsistency(ArcturusDatabase adb, CheckConsistencyListener listener, boolean criticalOnly)
		throws ArcturusDatabaseException {
		this.listener = listener;
		Connection conn = adb.getPooledConnection(this);
		String organism = adb.getName();
		
		try {
			 checkConsistency(adb, conn, criticalOnly);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An error occurred when checking the database consistency for organism " + organism, conn, this);
		}
		catch (Exception e) {
			this.listener = null;
			Arcturus.logSevere(e);
		}
		finally {
			this.listener = null;
			
			try {
				conn.close();
			} catch (SQLException e) {
				adb.handleSQLException(e, "An error occurred whilst closing the connection", conn, this);
			}
		}
	}

	protected void checkConsistency(ArcturusDatabase adb, Connection conn, boolean criticalOnly)
	throws SQLException, ArcturusDatabaseException {
		cancelled = false;
		boolean all_tests_passed = true;
		
		CheckConsistencyEvent event = new CheckConsistencyEvent(this);
		
		event.setEvent(null, CheckConsistencyEvent.Type.START_TEST_RUN);
		notifyListener(event);
		
		stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
	              java.sql.ResultSet.CONCUR_READ_ONLY);
		
		stmt.setFetchSize(Integer.MIN_VALUE);
		
		for (Test test : tests) {
			if (cancelled) {
				event.setEvent("\n\n***** TASK WAS CANCELLED *****\n", CheckConsistencyEvent.Type.CANCELLED);
				notifyListener(event);
				break;
			}
			
			if (criticalOnly && !test.isCritical()) continue;
			
			event.setEvent( "\n--------------------------------------------------------------------------------\n" + 
					test.getDescription(),CheckConsistencyEvent.Type.START_TEST);
			
			notifyListener(event);
			
			MessageFormat format = new MessageFormat(test.getFormat());
			
			long t0 = System.currentTimeMillis();
			
			int rows = -1;
			
			try {
				rows = doQuery(stmt, test.getQuery(), format);
			}
			catch (SQLException e) {
				if (e instanceof MySQLStatementCancelledException || e.getErrorCode() == MYSQL_QUERY_INTERRUPTED) {
					// Another thread has called our 'cancel' method.
					cancelled = true;
					break;
				} else {
					String organism = adb.getName();
					adb.handleSQLException(e, "An error occurred when checking the database consistency for organism " + organism, conn, this);
				}
			}
			
			long dt = System.currentTimeMillis() - t0;

			switch (rows) {
				case 0:
					event.setEvent("\nPASSED Time elapsed: " + dt + " ms", 
							CheckConsistencyEvent.Type.TEST_PASSED);
					break;
					
				default:
					String word = rows > 1 ? " inconsistencies" : " inconsistency";
					
					event.setEvent("\n*** FAILED : " + rows + word + " Time elapsed: " + dt + " ms***", 
							CheckConsistencyEvent.Type.TEST_FAILED);
					
					all_tests_passed = false;
					break;
			}
			
			notifyListener(event);
		}
		
		stmt.close();
		stmt = null;
		
		if (cancelled) {
			event.setEvent("\n\n+++++ SOME TESTS WERE NOT COMPLETED BECAUSE THE RUN WAS CANCELLED +++++", CheckConsistencyEvent.Type.CANCELLED);			
		} else {
			if (all_tests_passed)
				event.setEvent("\n\n+++++ ALL TESTS COMPLETED AND PASSED +++++", CheckConsistencyEvent.Type.ALL_TESTS_PASSED);
			else
				event.setEvent("\n\n+++++ ALL TESTS COMPLETED BUT WITH SOME INCONSISTENCIES +++++", CheckConsistencyEvent.Type.SOME_TESTS_FAILED);
		}
		notifyListener(event);
	}
	
	public void cancel() {
		if (stmt != null)
			try {
				stmt.cancel();
			} catch (SQLException e) {
				Arcturus.logWarning(e);
			}
		
		cancelled = true;
	}

	protected int doQuery(Statement stmt, String query, MessageFormat format)
			throws SQLException {
		ResultSet rs = stmt.executeQuery(query);
		ResultSetMetaData rsmd = rs.getMetaData();
		CheckConsistencyEvent event = new CheckConsistencyEvent(this);

		int rows = 0;
		int cols = rsmd.getColumnCount();

		Object[] args = format != null ? new Object[cols] : null;

		while (rs.next()  && !cancelled) {
			for (int col = 1; col <= cols; col++)
				args[col - 1] = rs.getObject(col);
			event.setEvent(format.format(args), CheckConsistencyEvent.Type.INCONSISTENCY);
			notifyListener(event);
			rows++;
		}

		return rows;
	}
	
	protected Vector<String> findSenderAndRecipients(ArcturusDatabase adb)
	throws ArcturusDatabaseException, SQLException {

		Connection conn = adb.getPooledConnection(this);
		stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
	              java.sql.ResultSet.CONCUR_READ_ONLY);
		
		stmt.setFetchSize(Integer.MIN_VALUE);
		
		String query = "select distinct username from USER where role = 'coordinator' order by username";
	
		ResultSet rs = stmt.executeQuery(query);
		ResultSetMetaData rsmd = rs.getMetaData();
		int cols = rsmd.getColumnCount();

		Vector<String> emailNames = new Vector<String>();
		// first name is the sender of the email
		// others are the cc recipients
		// arcturus-help will be the recipient

		while (rs.next()) {
			for (int col = 1; col <= cols; col++) {
				emailNames.add((String) rs.getObject(col));
			}
		}
		return emailNames;
	}

	protected void notifyListener(CheckConsistencyEvent event) {
		if (listener != null)
			listener.report(event);
	}
	
	public static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-log_full_path\tFull directory path to place the logs in");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-critical\tOnly run the critical tests");
	}

	public static void main(String args[]) {
		boolean testing = false;
		
		String instance = null;
		String organism = null;
		String logFullPath = null;
		boolean criticalOnly = false;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
			
			if (args[i].equalsIgnoreCase("-log_full_path"))
				logFullPath = args[++i];
			
			if (args[i].equalsIgnoreCase("-critical"))
				criticalOnly = true;
		}

		if (instance == null || organism == null || logFullPath == null) {
			printUsage(System.err);
			System.exit(1);
		}
		
		if (instance == "TESTSCHISTO")
			testing = true;
		
		try {
			System.out.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			InputStream is = CheckConsistency.class.getResourceAsStream("/resources/xml/checkconsistency.xml");
			CheckConsistency cc = new CheckConsistency(is);
			is.close();

			emailRecipients = cc.findSenderAndRecipients(adb);
			
			CronCheckConsistencyListener listener = new CronCheckConsistencyListener(instance,organism,logFullPath, emailRecipients); 
			cc.checkConsistency(adb, listener, criticalOnly);
			
			System.out.println("Consistency check completed successfully");
			System.exit(0);
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}
}




