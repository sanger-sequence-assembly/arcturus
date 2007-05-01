package uk.ac.sanger.arcturus.pooledconnection;

import java.sql.*;
import java.util.*;
import javax.sql.*;

import javax.management.*;

import uk.ac.sanger.arcturus.Arcturus;

import java.lang.management.*;

import com.mysql.jdbc.jdbc2.optional.MysqlDataSource;

public class ConnectionPool implements ConnectionPoolMBean {
	public final static long DEFAULT_TIMEOUT = 60000;
	private HashSet connections;
	private DataSource dataSource;
	final private long timeout;
	private ConnectionReaper reaper;
	final private int poolsize = 10;
	protected ObjectName mbeanName = null;
	protected boolean closed = false;
	protected long lastReaping = 0;
	protected int nCreated = 0;
	protected int nReaped = 0;

	public ConnectionPool(DataSource dataSource) {
		this(dataSource, DEFAULT_TIMEOUT);
	}

	public ConnectionPool(DataSource dataSource, long timeout) {
		this.timeout = timeout;
		this.dataSource = dataSource;
		
		initDataSource();
		
		connections = new HashSet(poolsize);
		reaper = new ConnectionReaper(this, timeout);
		reaper.start();
		
		registerAsMBean();
	}
	
	protected void registerAsMBean() {
		try {
			mbeanName = new ObjectName("ConnectionPool:name=" + getName());
		} catch (MalformedObjectNameException e) {
			Arcturus.logWarning("Failed to create ObjectName", e);
		}
		
		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
		
		try {
			mbs.registerMBean(this, mbeanName);
		} catch (Exception e) {
			Arcturus.logWarning("Failed to register connection pool as MBean", e);
		}
	}
	
	public String getName() {
		if (dataSource instanceof MysqlDataSource) {
			MysqlDataSource mds = (MysqlDataSource)dataSource;
			return mds.getDatabaseName();
		} else
			return "@" + Integer.toHexString(hashCode());

	}
	
	private void initDataSource() {
		if (dataSource instanceof MysqlDataSource) {
			MysqlDataSource mds = (MysqlDataSource)dataSource;
			mds.setNoAccessToProcedureBodies(true);
		}
	}

	public synchronized void reapConnections() {
		reapConnections(timeout);
	}
	
	public synchronized void reapConnections(long timeout) {
		Iterator iter = connections.iterator();

		while ((iter != null) && (iter.hasNext())) {
			PooledConnection conn = (PooledConnection) iter.next();

			if ((!conn.inUse()) && (conn.getIdleTime() > timeout)) {
				try {
					conn.closeConnection();
				} catch (SQLException sqle) {
					Arcturus.logWarning("An error occurred when closing a pooled connection", sqle);
				}
				iter.remove();
				nReaped++;
			}
		}
		
		lastReaping = System.currentTimeMillis();
	}

	public synchronized void closeConnections() {
		Iterator iter = connections.iterator();

		while ((iter != null) && (iter.hasNext())) {
			PooledConnection conn = (PooledConnection) iter.next();
			try {
				conn.closeConnection();
			} catch (SQLException sqle) {
				Arcturus.logWarning("An error occurred when closing a pooled connection", sqle);
			}
		}
		
		connections.clear();
	}

	public synchronized Connection getConnection(Object owner) throws SQLException {
		PooledConnection c;
		
		for (Iterator iter = connections.iterator(); iter.hasNext();) {
			c = (PooledConnection) iter.next();
			
			if (c.lease(owner))
				return c;
		}

		Connection conn = dataSource.getConnection();
		c = new PooledConnection(conn, this);
		c.setWaitTimeout(5*24*3600);
		c.lease(owner);
		connections.add(c);
		nCreated++;
		return c;
	}

	public synchronized void returnConnection(PooledConnection conn) {
		// This method allows a pooled connection to notify its parent
		// pool that it has been closed.  It does nothing in this
		// implementation.
	}

	class ConnectionReaper extends Thread {
		private ConnectionPool pool;
		private final long delay;

		ConnectionReaper(ConnectionPool pool, long delay) {
			this.pool = pool;
			this.delay = delay;
			setDaemon(true);
		}

		public void run() {
			while (true) {
				try {
					sleep(delay);
				} catch (InterruptedException e) {
				}
				if (pool.isClosed())
					return;
				else
					pool.reapConnections();
			}
		}
	}
	
	public synchronized boolean isClosed() {
		return closed;
	}
	
	public synchronized void close() {
		closed = true;
		closeConnections();
		unregisterAsMBean();
	}
		
	protected void unregisterAsMBean() {
		if (mbeanName != null) {
			MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
			
			try {
				mbs.unregisterMBean(mbeanName);
				mbeanName = null;
			} catch (Exception e) {
				Arcturus.logWarning("Failed to unregister connection pool as MBean", e);
			}
		}
	}

	public synchronized int getActiveConnectionCount() {
		int inuse = 0;
		
		for (Iterator iter = connections.iterator(); iter.hasNext();) {
			PooledConnection c = (PooledConnection) iter.next();
			if (c.inUse())
				inuse++;
		}

		return inuse;
	}
	
	public synchronized int getCreatedConnectionCount() {
		return nCreated;
	}
	
	public synchronized int getReapedConnectionCount() {
		return nReaped;
	}

	public synchronized int getConnectionCount() {
		return connections.size();
	}
}
