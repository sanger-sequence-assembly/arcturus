package uk.ac.sanger.arcturus.pooledconnection;

import java.sql.SQLException;

public interface PooledConnectionMBean {
	public boolean isInUse();
	public boolean isValid(int timeout) throws SQLException;
	public long getCurrentLeaseTime();
	public long getIdleTime();
	public long getLastLeaseTime();
	public long getTotalLeaseTime();
	public int getLeaseCounter();
	public int getConnectionID();
	public String getOwnerClassName();
}
