package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.OrganismChooserPanel;

import java.sql.*;
import java.io.*;
import java.util.List;
import java.util.Vector;
import java.text.MessageFormat;

import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.helpers.DefaultHandler;

import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

import javax.swing.JOptionPane;

public class CheckConsistency {
	protected CheckConsistencyListener listener = null;
	
	protected List<Test> tests;
	
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
		throws SQLException {
		checkConsistency(adb, listener, false);
	}
	
	public void checkConsistency(ArcturusDatabase adb, CheckConsistencyListener listener, boolean criticalOnly)
	throws SQLException {
		this.listener = listener;
		Connection conn = adb.getPooledConnection(this);
		checkConsistency(conn,criticalOnly);
		conn.close();
		this.listener = null;
	}

	protected void checkConsistency(Connection conn, boolean criticalOnly) throws SQLException {
		Statement stmt = conn.createStatement();

		for (Test test : tests) {
			if (criticalOnly && !test.isCritical())
				continue;
			
			notifyListener(test.getDescription());
			notifyListener("");

			MessageFormat format = new MessageFormat(test.getFormat());

			int rows = doQuery(stmt, test.getQuery(), format);

			String message;

			switch (rows) {
				case 0:
					message = "PASSED";
					break;

				case 1:
					message = "\n*** FAILED : 1 inconsistency ***";
					break;

				default:
					message = "\n*** FAILED : " + rows + " inconsistencies ***";
					break;
			}

			notifyListener(message);
			notifyListener("");
			notifyListener("--------------------------------------------------------------------------------");
		}
	}

	protected int doQuery(Statement stmt, String query, MessageFormat format)
			throws SQLException {
		ResultSet rs = stmt.executeQuery(query);

		ResultSetMetaData rsmd = rs.getMetaData();

		int rows = 0;
		int cols = rsmd.getColumnCount();

		Object[] args = format != null ? new Object[cols] : null;

		while (rs.next()) {
			for (int col = 1; col <= cols; col++)
				args[col - 1] = rs.getObject(col);

			notifyListener(format.format(args));

			rows++;
		}

		return rows;
	}

	protected void notifyListener(String message) {
		if (listener != null)
			listener.report(message);
	}
	
	public interface CheckConsistencyListener {
		public void report(String message);
	}

	public static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
	}

	public static void main(String args[]) {
		String instance = null;
		String organism = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
		}

		if (instance == null || organism == null) {
			OrganismChooserPanel orgpanel = new OrganismChooserPanel();

			int result = orgpanel.showDialog(null);

			if (result == JOptionPane.OK_OPTION) {
				instance = orgpanel.getInstance();
				organism = orgpanel.getOrganism();
			}
		}

		if (instance == null || instance.length() == 0 || organism == null
				|| organism.length() == 0) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			InputStream is = CheckConsistency.class.getResourceAsStream("/resources/xml/checkconsistency.xml");
			
			CheckConsistency cc = new CheckConsistency(is);
			
			is.close();

			CheckConsistencyListener listener = new CheckConsistencyListener() {
				public void report(String message) {
					System.out.println(message);
				}
				
			};
			
			cc.checkConsistency(adb, listener);

			System.exit(0);
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}
	
	class MyHandler extends DefaultHandler {
		private List<Test> tests;
		private String description;
		private String query;
		private String format;
		private boolean critical;
		private StringBuilder content;
		
		public List<Test> getTests() {
			return tests;
		}
		
		public void startDocument() throws SAXException {
			//System.out.println("startDocument");
			tests = new Vector<Test>();
		}	

		public void endDocument() throws SAXException {
			//System.out.println("endDocument");
		}

		private int getTypeCode(String lName, String qName) {
			if (lName != null && lName.length() > 0)
				return getTypeCode(lName);
			else if (qName != null && qName.length() > 0)
				return getTypeCode(qName);
			else
				return -1;
		}

		private int getTypeCode(String name) {
			if (name.equals("description"))
				return Test.DESCRIPTION;

			if (name.equals("query"))
				return Test.QUERY;

			if (name.equals("format"))
				return Test.FORMAT;
			
			if (name.equals("test"))
				return Test.TEST;

			return -1;
		}
		
		public void startElement(String namespaceURI, String lName, String qName,
				Attributes attrs) throws SAXException {
			//String name = (lName != null && lName.length() > 0) ? lName : qName;		
			//System.out.println("startElement(" + name + ")");
			
			int type = getTypeCode(lName, qName);
			
			switch (type) {
				case Test.TEST:
					description = null;
					query = null;
					format = null;				
					String criticality = attrs.getValue("critical");
					critical = criticality != null && criticality.equalsIgnoreCase("YES");
					break;
					
				case Test.DESCRIPTION:
				case Test.QUERY:
				case Test.FORMAT:
					content = new StringBuilder();
					break;
					
				default:
					content = null;
					break;
			}
		}
		
		public void endElement(String namespaceURI, String lName,String qName) throws SAXException {
			//String name = (lName != null && lName.length() > 0) ? lName : qName;			
			//System.out.println("endElement(" + name + ")");
		
			int type = getTypeCode(lName, qName);
			
			switch (type) {
				case Test.TEST:
					Test test = new Test(description, query, format, critical);
					tests.add(test);
					break;
					
				case Test.DESCRIPTION:
					description = removeWhiteSpace(content);
					break;
					
				case Test.QUERY:
					query = removeWhiteSpace(content);
					break;
					
				case Test.FORMAT:
					format = removeWhiteSpace(content);
					break;				
			}
		
		}
		
		public void ignorableWhitespace(char[] ch,
                int start,
                int length)
                throws SAXException	{
			//System.out.println("ignorableWhitespace(length=" + length + ")");
		}
		
		public void characters(char[] ch, int start, int length)
                throws SAXException {
			//String string = new String(ch, start, length);
			//System.out.println("characters(" + string + ")");
			
			if (content != null)
				content.append(ch, start, length);
		}
		
		public void error(SAXParseException e) throws SAXParseException {
			throw e;
		}

		public void warning(SAXParseException err) throws SAXParseException {
			System.out.println("** Warning" + ", line " + err.getLineNumber()
					+ ", uri " + err.getSystemId());
			System.out.println("   " + err.getMessage());
		}
	
		private String removeWhiteSpace(StringBuilder sb) {
			String str = sb.toString();
			String[] lines = str.split("[\\n\\r]");
			
			sb = new StringBuilder();
			for (int i = 0; i < lines.length; i++) {
				if (i > 0)
					sb.append(' ');
				
				sb.append(lines[i].trim());
			}
			
			return sb.toString().trim();
		}
	}

	class Test {
		public static final int DESCRIPTION = 1;
		public static final int QUERY = 2;
		public static final int FORMAT = 3;
		public static final int TEST = 4;
		
		private final String description;
		private final String query;
		private final String format;
		private final boolean critical;
		
		public Test(String description, String query, String format, boolean critical) {
			this.description = description;
			this.query = query;
			this.format = format;
			this.critical = critical;
		}
		
		public String getDescription() {
			return description;
		}
		
		public String getQuery() {
			return query;
		}
		
		public String getFormat() {
			return format;
		}
		
		public boolean isCritical() {
			return critical;
		}
		
		public String toString() {
			return "Test[description=\"" + description +
				"\", query=\"" + query +
				"\", format=\"" + format + "\"" +
				", critical=" + (critical ? "YES" : "NO") +
				"]";
		}
	}
}
