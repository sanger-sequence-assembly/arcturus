package uk.ac.sanger.arcturus.logging;

import java.util.logging.*;
import java.sql.*;
import java.io.*;
import java.lang.management.ManagementFactory;
import java.util.*;

import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;

import uk.ac.sanger.arcturus.Arcturus;

public class JDBCLogHandler extends Handler implements JDBCLogHandlerMBean {
	protected Connection conn;
	protected PreparedStatement pstmtInsertRecord;
	protected PreparedStatement pstmtInsertStackTrace;
	protected String username = System.getProperty("user.name");
	
	public JDBCLogHandler(String propsfile) throws SQLException, IOException, ClassNotFoundException {
		conn = getConnection(propsfile);		
		initialise();
	}
	
	public JDBCLogHandler(Connection conn) throws SQLException {
		this.conn = conn;	
		initialise();
	}
	
	public JDBCLogHandler(Properties props) throws SQLException, ClassNotFoundException {
		conn = getConnection(props);
		initialise();
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
	
	protected void initialise() throws SQLException {
		prepareStatements();
		registerAsMBean();
	}

	protected void prepareStatements() throws SQLException {
		setWaitTimeout(5*24*3600);
		
		String query =
			"INSERT INTO LOGRECORD(time,sequence,logger,level,class,method,thread,message,user,host,connid,revision,parent,exceptionclass,exceptionmessage,errorcode,errorstate)" +
			" VALUES(?,?,?,?,?,?,?,?,?,substring_index(user(),'@',-1),connection_id(),?,?,?,?,?,?)";
		
		pstmtInsertRecord = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
				
		query = "INSERT INTO STACKTRACE(id,sequence,class,method,line) VALUES(?,?,?,?,?)";
		
		pstmtInsertStackTrace = conn.prepareStatement(query);
	}
	
	protected int getConnectionID() throws SQLException {
		int connectionID = -1;
		
		String sql = "SELECT CONNECTION_ID()";
	
		Statement stmt = conn.createStatement();
		
		ResultSet rs = stmt.executeQuery(sql);
		
		if (rs.next())
			connectionID = rs.getInt(1);
		
		rs.close();
		stmt.close();
		
		return connectionID;
	}

	public void close() throws SecurityException {
		try {
			if (conn != null)
				conn.close();
			
			unregisterAsMBean();
		}
		catch (SQLException sqle) {
			sqle.printStackTrace();
		}
	}

	public void flush() {
		// Does nothing
	}

	public void publish(LogRecord record) {
		if (!isLoggable(record) || record.getThrown() == null)
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
			
			if (thrown instanceof SQLException) {
				SQLException sqle = (SQLException)thrown;
				
				int errorcode = sqle.getErrorCode();
				String sqlstate = sqle.getSQLState();
				
				pstmtInsertRecord.setInt(14, errorcode);
				pstmtInsertRecord.setString(15, sqlstate);
			} else {
				pstmtInsertRecord.setNull(14, Types.INTEGER);
				pstmtInsertRecord.setNull(15, Types.CHAR);				
			}
		} else {
			pstmtInsertRecord.setNull(12, Types.CHAR);
			pstmtInsertRecord.setNull(13, Types.CHAR);
			pstmtInsertRecord.setNull(14, Types.INTEGER);
			pstmtInsertRecord.setNull(15, Types.CHAR);
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

	private Level oldLevel;
	private final Level infoLevel = Level.INFO;
	
	public boolean isDebugging() {
		return getLevel().intValue() <= infoLevel.intValue();
	}

	public void setDebugging(boolean debugging) {
		if (debugging) {
			oldLevel = getLevel();
			
			if (!isDebugging())
				setLevel(infoLevel);
		} else {
			if (oldLevel != null)
				setLevel(oldLevel);
		}
	}

	protected ObjectName mbeanName = null;
	
	protected void registerAsMBean() {
		try {
			int connectionID = getConnectionID();
			mbeanName = new ObjectName("JDBCLogHandler:connid=" + connectionID);
		} catch (MalformedObjectNameException e) {
			Arcturus.logWarning("Failed to create ObjectName", e);
		} catch (SQLException e) {
			Arcturus.logWarning("Failed to get the connection ID when registering JDBCLogHandler as MBean", e);
		}

		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();

		try {
			mbs.registerMBean(this, mbeanName);
		} catch (Exception e) {
			Arcturus.logWarning(
					"Failed to register JDBCLogHandler as MBean", e);
		}
	}

	protected void unregisterAsMBean() {
		if (mbeanName != null) {
			MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();

			try {
				mbs.unregisterMBean(mbeanName);
				mbeanName = null;
			} catch (Exception e) {
				Arcturus.logWarning(
						"Failed to unregister pooled connection as MBean", e);
			}
		}
	}
}
