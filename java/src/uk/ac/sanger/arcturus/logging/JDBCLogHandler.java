package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;
import java.sql.*;
import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;

public class JDBCLogHandler extends Handler {
	protected Connection conn;
	protected PreparedStatement pstmtInsertRecord;
	protected PreparedStatement pstmtInsertStackTrace;
	protected String username = System.getProperty("user.name");
	
	public JDBCLogHandler(String propsfile) throws SQLException, IOException, ClassNotFoundException {
		conn = getConnection(propsfile);		
		prepareStatements();
	}
	
	public JDBCLogHandler(Connection conn) throws SQLException {
		this.conn = conn;	
		prepareStatements();
	}
	
	public JDBCLogHandler(Properties props) throws SQLException, ClassNotFoundException {
		conn = getConnection(props);
		prepareStatements();
	}

	protected Connection getConnection(String propsfile)
		throws SQLException, IOException, ClassNotFoundException {
		InputStream is = getClass().getResourceAsStream(propsfile);
		Properties myprops = new Properties();
		myprops.load(is);
		is.close();
		
		return getConnection(myprops);
	}
	
	protected Connection getConnection(Properties props) throws SQLException, ClassNotFoundException {
		String host = props.getProperty("jdbcloghandler.host");
		String port = props.getProperty("jdbcloghandler.port");
		String database = props.getProperty("jdbcloghandler.database");
		
		String url = "jdbc:mysql://" + host + ":" + port + "/" + database;
		
		String driver = "com.mysql.jdbc.Driver";
		
		String username = props.getProperty("jdbcloghandler.username");
		String password = props.getProperty("jdbcloghandler.password");
		
		Class.forName(driver);
		
		return DriverManager.getConnection(url, username, password);
	}

	protected void setWaitTimeout(int timeout) throws SQLException {
		String sql = "set session wait_timeout = " + timeout;
		Statement stmt = conn.createStatement();
		stmt.execute(sql);
		stmt.close();
	}

	protected void prepareStatements() throws SQLException {
		setWaitTimeout(5*24*3600);
		
		String query =
			"INSERT INTO LOGRECORD(time,sequence,logger,level,class,method,thread,message,user,host,connid,revision,parent,exceptionclass,exceptionmessage)" +
			" VALUES(?,?,?,?,?,?,?,?,?,substring_index(user(),'@',-1),connection_id(),?,?,?,?)";
		
		pstmtInsertRecord = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
				
		query = "INSERT INTO STACKTRACE(id,sequence,class,method,line) VALUES(?,?,?,?,?)";
		
		pstmtInsertStackTrace = conn.prepareStatement(query);
	}

	public void close() throws SecurityException {
		try {
			if (conn != null)
				conn.close();
		}
		catch (SQLException sqle) {
			sqle.printStackTrace();
		}
	}

	public void flush() {
		// Does nothing
	}

	public void publish(LogRecord record) {
		if (!isLoggable(record))
			return;
		
		try {
			Throwable thrown = record.getThrown();
			
			int parent = storeException(record, thrown, 0);
			
			if (thrown != null) {
				while ((thrown = thrown.getCause()) != null)
					parent = storeException(record, thrown, parent);
			}
		}
		catch (SQLException sqle) {
			sqle.printStackTrace();
		}
	}
	
	private int storeException(LogRecord record, Throwable thrown, int parent) throws SQLException {
		pstmtInsertRecord.setLong(1, record.getMillis());
		pstmtInsertRecord.setLong(2, record.getSequenceNumber());
		pstmtInsertRecord.setString(3, record.getLoggerName());
		pstmtInsertRecord.setInt(4, record.getLevel().intValue());
		pstmtInsertRecord.setString(5, record.getSourceClassName());
		pstmtInsertRecord.setString(6, record.getSourceMethodName());
		pstmtInsertRecord.setInt(7, record.getThreadID());

		String message = record.getMessage();
		if (message == null)
			message = "[NULL]";

		pstmtInsertRecord.setString(8, message);

		pstmtInsertRecord.setString(9, username);

		String revision = Arcturus.getProperty(Arcturus.BUILD_VERSION_KEY,
				"[NOT KNOWN]");
		pstmtInsertRecord.setString(10, revision);

		pstmtInsertRecord.setInt(11, parent);
		
		if (thrown != null) {
			pstmtInsertRecord.setString(12, thrown.getClass().getName());
			
			String emessage = thrown.getMessage();
			
			if (emessage == null)
				emessage = "[NULL]";
			
			pstmtInsertRecord.setString(13, emessage);
		} else {
			pstmtInsertRecord.setNull(12, Types.CHAR);
			pstmtInsertRecord.setNull(13, Types.CHAR);
		}

		int rc = pstmtInsertRecord.executeUpdate();

		if (rc == 1 && record.getThrown() != null) {
			ResultSet rs = pstmtInsertRecord.getGeneratedKeys();

			rs.next();

			int id = rs.getInt(1);

			StackTraceElement ste[] = thrown.getStackTrace();

			for (int i = 0; i < ste.length; i++) {
				pstmtInsertStackTrace.setInt(1, id);
				pstmtInsertStackTrace.setInt(2, i);
				pstmtInsertStackTrace.setString(3, ste[i].getClassName());
				pstmtInsertStackTrace.setString(4, ste[i].getMethodName());
				pstmtInsertStackTrace.setInt(5, ste[i].getLineNumber());

				pstmtInsertStackTrace.executeUpdate();
			}
			
			return id;
		} else
			return 0;
	}
}
