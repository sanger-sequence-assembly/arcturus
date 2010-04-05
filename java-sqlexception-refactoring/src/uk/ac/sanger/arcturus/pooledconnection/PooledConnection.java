package uk.ac.sanger.arcturus.pooledconnection;

import java.lang.management.ManagementFactory;
import java.sql.*;
import java.util.*;
import javax.management.*;

import uk.ac.sanger.arcturus.Arcturus;

public class PooledConnection implements Connection, PooledConnectionMBean {
	private static int counter = 0;

	private final int ID;

	protected int leaseCounter = 0;

	private ConnectionPool pool;

	private Connection conn;

	private boolean inuse;

	private long timestamp;

	private long lastLeaseTime = Integer.MIN_VALUE;

	private long totalLeaseTime = 0;

	private Object owner = null;

	protected ObjectName mbeanName = null;
	
	private int connectionID = -1;

	public PooledConnection(Connection conn, ConnectionPool pool) {
		this.conn = conn;
		this.pool = pool;
		this.inuse = false;
		this.timestamp = 0;

		synchronized (pool) {
			ID = ++counter;
		}
		
		initConnection();

		registerAsMBean();
	}
	
	private void initConnection() {
		String sql = "SELECT CONNECTION_ID()";
		
		try {
			Statement stmt = conn.createStatement();
			
			ResultSet rs = stmt.executeQuery(sql);
			
			if (rs.next())
				connectionID = rs.getInt(1);
			
			rs.close();
			stmt.close();
		}
		catch (SQLException sqle) {
			// Unable to get connection ID -- maybe we're not talking
			// to a MySQL server?  It's not a fatal condition, since
			// we only want the connection ID for debugging and monitoring
			// purposes anyway.
		}
	}

	public int getConnectionID() {
		return connectionID;
	}
	
	protected void registerAsMBean() {
		try {
			mbeanName = new ObjectName("PooledConnection:pool="
					+ pool.getName() + ",ID=" + ID);
		} catch (MalformedObjectNameException e) {
			Arcturus.logWarning("Failed to create ObjectName", e);
		}

		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();

		try {
			mbs.registerMBean(this, mbeanName);
		} catch (Exception e) {
			Arcturus.logWarning(
					"Failed to register pooled connection as MBean", e);
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

	protected void closeConnection() {
		try {
			if (conn != null && !conn.isClosed())
				conn.close();
		}
		catch (SQLException e) {
			// Do nothing
		}
		
		conn = null;

		unregisterAsMBean();
	}

	public synchronized boolean lease(Object owner) {
		if (inuse || conn == null) {
			return false;
		} else {
			leaseCounter++;
			inuse = true;
			timestamp = System.currentTimeMillis();
			lastLeaseTime = timestamp;
			this.owner = owner;
			return true;
		}
	}

	public int getLeaseCounter() {
		return leaseCounter;
	}

	public int getID() {
		return ID;
	}

	public boolean validate() {
		try {
			conn.getMetaData();
		} catch (Exception e) {
			return false;
		}
		return true;
	}

	public boolean inUse() {
		return inuse;
	}

	public boolean isInUse() {
		return inuse;
	}

	public long getLastUse() {
		return timestamp;
	}

	public long getLastLeaseTime() {
		return lastLeaseTime;
	}

	public long getTotalLeaseTime() {
		return totalLeaseTime + getCurrentLeaseTime();
	}

	public long getCurrentLeaseTime() {
		return inuse ? System.currentTimeMillis() - lastLeaseTime : 0;
	}

	public long getIdleTime() {
		return inuse ? 0 : System.currentTimeMillis() - timestamp;
	}

	public Object getOwner() {
		return owner;
	}

	public String getOwnerClassName() {
		return (owner == null) ? "[null]" : owner.getClass().getName();
	}

	public ConnectionPool getConnectionPool() {
		return pool;
	}

	public synchronized void close() throws SQLException {
		timestamp = System.currentTimeMillis();
		totalLeaseTime += (timestamp - lastLeaseTime);
		owner = null;
		inuse = false;
		pool.returnConnection(this);
	}

	protected Connection getConnection() {
		return conn;
	}

	public PreparedStatement prepareStatement(String sql) throws SQLException {
		return conn.prepareStatement(sql);
	}

	public CallableStatement prepareCall(String sql) throws SQLException {
		return conn.prepareCall(sql);
	}

	public Statement createStatement() throws SQLException {
		return conn.createStatement();
	}

	public String nativeSQL(String sql) throws SQLException {
		return conn.nativeSQL(sql);
	}

	public void setAutoCommit(boolean autoCommit) throws SQLException {
		conn.setAutoCommit(autoCommit);
	}

	public boolean getAutoCommit() throws SQLException {
		return conn.getAutoCommit();
	}

	public void commit() throws SQLException {
		conn.commit();
	}

	public void rollback() throws SQLException {
		conn.rollback();
	}

	public boolean isClosed() throws SQLException {
		return conn.isClosed();
	}

	public DatabaseMetaData getMetaData() throws SQLException {
		return conn.getMetaData();
	}

	public void setReadOnly(boolean readOnly) throws SQLException {
		conn.setReadOnly(readOnly);
	}

	public boolean isReadOnly() throws SQLException {
		return conn.isReadOnly();
	}

	public void setCatalog(String catalog) throws SQLException {
		conn.setCatalog(catalog);
	}

	public String getCatalog() throws SQLException {
		return conn.getCatalog();
	}

	public void setTransactionIsolation(int level) throws SQLException {
		conn.setTransactionIsolation(level);
	}

	public int getTransactionIsolation() throws SQLException {
		return conn.getTransactionIsolation();
	}

	public SQLWarning getWarnings() throws SQLException {
		return conn.getWarnings();
	}

	public void clearWarnings() throws SQLException {
		conn.clearWarnings();
	}

	public Statement createStatement(int resultSetType, int resultSetConcurrency)
			throws SQLException {
		return conn.createStatement(resultSetType, resultSetConcurrency);
	}

	public Statement createStatement(int resultSetType,
			int resultSetConcurrency, int resultSetHoldability)
			throws SQLException {
		return conn.createStatement(resultSetType, resultSetConcurrency,
				resultSetHoldability);
	}

	public int getHoldability() throws SQLException {
		return conn.getHoldability();
	}

	public Map<String,Class<?>> getTypeMap() throws SQLException {
		return conn.getTypeMap();
	}

	public CallableStatement prepareCall(String sql, int resultSetType,
			int resultSetConcurrency) throws SQLException {
		return conn.prepareCall(sql, resultSetType, resultSetConcurrency);
	}

	public CallableStatement prepareCall(String sql, int resultSetType,
			int resultSetConcurrency, int resultSetHoldability)
			throws SQLException {
		return conn.prepareCall(sql, resultSetType, resultSetConcurrency,
				resultSetHoldability);
	}

	public PreparedStatement prepareStatement(String sql, int autoGeneratedKeys)
			throws SQLException {
		return conn.prepareStatement(sql, autoGeneratedKeys);
	}

	public PreparedStatement prepareStatement(String sql, int[] columnIndexes)
			throws SQLException {
		return conn.prepareStatement(sql, columnIndexes);
	}

	public PreparedStatement prepareStatement(String sql, String[] columnNames)
			throws SQLException {
		return conn.prepareStatement(sql, columnNames);
	}

	public PreparedStatement prepareStatement(String sql, int resultSetType,
			int resultSetConcurrency) throws SQLException {
		return conn.prepareStatement(sql, resultSetType, resultSetConcurrency);
	}

	public PreparedStatement prepareStatement(String sql, int resultSetType,
			int resultSetConcurrency, int resultSetHoldability)
			throws SQLException {
		return conn.prepareStatement(sql, resultSetType, resultSetConcurrency,
				resultSetHoldability);
	}

	public void releaseSavepoint(Savepoint savepoint) throws SQLException {
		conn.releaseSavepoint(savepoint);
	}

	public void rollback(Savepoint savepoint) throws SQLException {
		conn.rollback(savepoint);

	}

	public void setHoldability(int holdability) throws SQLException {
		conn.setHoldability(holdability);
	}

	public Savepoint setSavepoint() throws SQLException {
		return conn.setSavepoint();
	}

	public Savepoint setSavepoint(String name) throws SQLException {
		return conn.setSavepoint(name);
	}

	public void setTypeMap(Map <String,Class<?>> map) throws SQLException {
		conn.setTypeMap(map);
	}

	public void setWaitTimeout(int timeout) throws SQLException {
		String sql = "set session wait_timeout = " + timeout;
		Statement stmt = conn.createStatement();
		stmt.execute(sql);
		stmt.close();
	}

	public Array createArrayOf(String typeName, Object[] elements)
			throws SQLException {
		return conn.createArrayOf(typeName, elements);
	}

	public Blob createBlob() throws SQLException {
		return conn.createBlob();
	}

	public Clob createClob() throws SQLException {
		return conn.createClob();
	}

	public NClob createNClob() throws SQLException {
		return conn.createNClob();
	}

	public SQLXML createSQLXML() throws SQLException {
		return conn.createSQLXML();
	}

	public Struct createStruct(String typeName, Object[] attributes)
			throws SQLException {
		return conn.createStruct(typeName, attributes);
	}

	public Properties getClientInfo() throws SQLException {
		return conn.getClientInfo();
	}

	public String getClientInfo(String name) throws SQLException {
		return conn.getClientInfo(name);
	}

	public boolean isValid(int timeout) throws SQLException {
		return conn.isValid(timeout);
	}

	public void setClientInfo(Properties properties)
			throws SQLClientInfoException {
		conn.setClientInfo(properties);
	}

	public void setClientInfo(String name, String value)
			throws SQLClientInfoException {
		conn.setClientInfo(name, value);
	}

	public boolean isWrapperFor(Class<?> iface) throws SQLException {
		return conn.isWrapperFor(iface);
	}

	public <T> T unwrap(Class<T> iface) throws SQLException {
		return conn.unwrap(iface);
	}
}
