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
	private Vector connections;
	private DataSource dataSource;
	final private long timeout;
	private ConnectionReaper reaper;
	final private int poolsize = 10;

	public ConnectionPool(DataSource dataSource) {
		this(dataSource, DEFAULT_TIMEOUT);
	}

	public ConnectionPool(DataSource dataSource, long timeout) {
		this.timeout = timeout;
		this.dataSource = dataSource;
		
		initDataSource();
		
		connections = new Vector(poolsize);
		reaper = new ConnectionReaper(this, timeout);
		reaper.start();
		
		ObjectName cpName = null;
		
		try {
			cpName = new ObjectName("ConnectionPool");
		} catch (MalformedObjectNameException e) {
			Arcturus.logWarning("Failed to create ObjectName", e);
		}
		
		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
		
		try {
			mbs.registerMBean(this, cpName);
		} catch (Exception e) {
			Arcturus.logWarning("Failed to register connection pool as MBean", e);
		}
	}
	
	private void initDataSource() {
		if (dataSource instanceof MysqlDataSource) {
			MysqlDataSource mds = (MysqlDataSource)dataSource;
			mds.setNoAccessToProcedureBodies(true);
		}
	}

	public synchronized void reapConnections() {
		long stale = System.currentTimeMillis() - timeout;
		Enumeration connlist = connections.elements();

		while ((connlist != null) && (connlist.hasMoreElements())) {
			PooledConnection conn = (PooledConnection) connlist.nextElement();

			if ((!conn.inUse()) && (stale > conn.getLastUse())) {
				removeConnection(conn);
			}
		}
	}

	public synchronized void closeConnections() {
		Enumeration connlist = connections.elements();

		while ((connlist != null) && (connlist.hasMoreElements())) {
			PooledConnection conn = (PooledConnection) connlist.nextElement();
			removeConnection(conn);
		}
	}

	private synchronized void removeConnection(PooledConnection conn) {
		try {
			if (!conn.getConnection().isClosed())
				conn.getConnection().close();
		} catch (SQLException sqle) {
		}

		connections.removeElement(conn);
	}

	public synchronized Connection getConnection() throws SQLException {
		PooledConnection c;
		
		for (int i = 0; i < connections.size(); i++) {
			c = (PooledConnection) connections.elementAt(i);
			if (c.lease()) {
				return c;
			}
		}

		Connection conn = dataSource.getConnection();
		c = new PooledConnection(conn, this);
		c.setWaitTimeout(5*24*3600);
		c.lease();
		connections.addElement(c);
		return c;
	}

	public synchronized void returnConnection(PooledConnection conn) {
		conn.expireLease();
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
				pool.reapConnections();
			}
		}
	}

	public synchronized int getActiveConnectionCount() {
		int inuse = 0;
		
		for (int i = 0; i < connections.size(); i++) {
			PooledConnection c = (PooledConnection) connections.elementAt(i);
			if (c.inUse())
				inuse++;
		}

		return inuse;
	}

	public synchronized int getConnectionCount() {
		return connections.size();
	}
}
