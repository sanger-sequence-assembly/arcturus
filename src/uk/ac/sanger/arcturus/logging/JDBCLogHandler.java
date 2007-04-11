package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;
import java.sql.*;
import java.io.*;
import java.util.*;

public class JDBCLogHandler extends Handler {
	private Connection conn;
	private PreparedStatement pstmtInsertRecord;
	private PreparedStatement pstmtUpdateThrowableInfo;
	private PreparedStatement pstmtInsertStackTrace;
	private String username = System.getProperty("user.name");
	
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

	private Connection getConnection(String propsfile)
		throws SQLException, IOException, ClassNotFoundException {
		InputStream is = getClass().getResourceAsStream(propsfile);
		Properties myprops = new Properties();
		myprops.load(is);
		is.close();
		
		return getConnection(myprops);
	}
	
	private Connection getConnection(Properties props) throws SQLException, ClassNotFoundException {
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

	private void setWaitTimeout(int timeout) throws SQLException {
		String sql = "set session wait_timeout = " + timeout;
		Statement stmt = conn.createStatement();
		stmt.execute(sql);
		stmt.close();
	}

	private void prepareStatements() throws SQLException {
		setWaitTimeout(5*24*3600);
		
		String query =
			"INSERT INTO LOGRECORD(time,sequence,logger,level,class,method,thread,message,user,host,connid)" +
			" VALUES(?,?,?,?,?,?,?,?,?,substring_index(user(),'@',-1),connection_id())";
		
		pstmtInsertRecord = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
		
		query = "UPDATE LOGRECORD set exceptionclass = ?, exceptionmessage = ? where id = ?";
		
		pstmtUpdateThrowableInfo = conn.prepareStatement(query);
		
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
		try {
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
			
			int rc = pstmtInsertRecord.executeUpdate();
			
			if (rc == 1 && record.getThrown() != null) {
				ResultSet rs = pstmtInsertRecord.getGeneratedKeys();
				
				rs.next();
				
				int id = rs.getInt(1);
				
				Throwable thrown = record.getThrown();
				
				pstmtUpdateThrowableInfo.setString(1, thrown.getClass().getName());
				
				String emessage = thrown.getMessage();
				if (emessage == null)
					emessage = "[NULL]";
				
				pstmtUpdateThrowableInfo.setString(2, emessage);
				pstmtUpdateThrowableInfo.setInt(3, id);
				
				rc = pstmtUpdateThrowableInfo.executeUpdate();
				
				StackTraceElement ste[] = thrown.getStackTrace();
				
				for (int i = 0; i < ste.length; i++) {
					pstmtInsertStackTrace.setInt(1, id);
					pstmtInsertStackTrace.setInt(2, i);
					pstmtInsertStackTrace.setString(3, ste[i].getClassName());
					pstmtInsertStackTrace.setString(4, ste[i].getMethodName());
					pstmtInsertStackTrace.setInt(5, ste[i].getLineNumber());
					
					pstmtInsertStackTrace.executeUpdate();
				}
			}
		}
		catch (SQLException sqle) {
			sqle.printStackTrace();
		}
	}
}
