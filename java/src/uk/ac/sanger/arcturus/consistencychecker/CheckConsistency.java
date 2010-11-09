package uk.ac.sanger.arcturus.consistencychecker;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.gui.OrganismChooserPanel;
import uk.ac.sanger.arcturus.logging.MailHandler;

import java.sql.*;
import java.io.*;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.text.MessageFormat;

import org.xml.sax.SAXException;

import com.mysql.jdbc.exceptions.MySQLStatementCancelledException;

import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

import javax.swing.JOptionPane;

public class CheckConsistency {
	protected CheckConsistencyListener listener = null;
	
	protected List<Test> tests;
	
	protected boolean cancelled = false;
	
	protected Statement stmt = null;
	
	protected String failedTestMessage = "";
	
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
		checkConsistency(adb, listener, false);
	}
	
	public void checkConsistency(ArcturusDatabase adb, CheckConsistencyListener listener, boolean criticalOnly)
		throws ArcturusDatabaseException {
		this.listener = listener;
		Connection conn = adb.getPooledConnection(this);
		String message = "";
		String organism = "Pass in the organism name";
		
		try {
			 checkConsistency(conn,criticalOnly);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An error occurred when checking the database consistency", conn, this);
		}
		finally {
			this.listener.sendEmail(organism);
			this.listener = null;
			
			try {
				conn.close();
			} catch (SQLException e) {
				adb.handleSQLException(e, "An error occurred whilst closing the connection", conn, this);
			}
		}
	}

	protected void checkConsistency(Connection conn, boolean criticalOnly) throws SQLException {
		cancelled = false;
		String message = "";
		Boolean isError = false;

		stmt = conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
	              java.sql.ResultSet.CONCUR_READ_ONLY);
		
		stmt.setFetchSize(Integer.MIN_VALUE);
		
		for (Test test : tests) {
			if (cancelled) {
				notifyListener("\n\n***** TASK WAS CANCELLED *****\n", true);
				break;
			}
			
			if (criticalOnly && !test.isCritical())
				continue;
			
			notifyListener(test.getDescription(), isError);
			notifyListener("", isError);

			MessageFormat format = new MessageFormat(test.getFormat());
			
			long t0 = System.currentTimeMillis();

			int rows = doQuery(stmt, test.getQuery(), format);
			
			long dt = System.currentTimeMillis() - t0;

			switch (rows) {
				case 0:
					message = "PASSED";
					break;

				case 1:
					message = "\n*** FAILED : 1 inconsistency ***";
					isError = true;
					break;

				default:
					message = "\n*** FAILED : " + rows + " inconsistencies ***";
					isError = true;
					break;
			}

			notifyListener(message, isError);
			isError = false;
			notifyListener("", isError);
			notifyListener("Time elapsed: " + dt + " ms", isError);
			notifyListener("--------------------------------------------------------------------------------", isError);
			
		}
		
		stmt.close();
		
		stmt = null;
		
		notifyListener("\n\n+++++ ALL TESTS COMPLETED +++++", true);
	
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

		int rows = 0;
		int cols = rsmd.getColumnCount();

		Object[] args = format != null ? new Object[cols] : null;

		while (rs.next()  && !cancelled) {
			for (int col = 1; col <= cols; col++)
				args[col - 1] = rs.getObject(col);

			notifyListener(format.format(args), true);

			rows++;
		}

		return rows;
	}

	protected void notifyListener(String message, boolean isError) {
		if (listener != null)
			listener.report(message, isError);
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
		final boolean testing = true;
		
		String instance = null;
		String organism = null;
		String log_full_path = null;
		boolean criticalOnly = false;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
			
			if (args[i].equalsIgnoreCase("-log_full_path"))
				log_full_path = args[++i];
			
			if (args[i].equalsIgnoreCase("-critical"))
				criticalOnly = true;
		}

		if (instance == null || organism == null || log_full_path == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.out.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			InputStream is = CheckConsistency.class.getResourceAsStream("/resources/xml/checkconsistency.xml");
			
			CheckConsistency cc = new CheckConsistency(is);
			
			is.close();

		CronCheckConsistencyListener listener = new CronCheckConsistencyListener(); 
		
			cc.checkConsistency(adb, listener, criticalOnly);
			
			System.out.println("Consistency check completed successfully");
			System.exit(0);
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}
}




