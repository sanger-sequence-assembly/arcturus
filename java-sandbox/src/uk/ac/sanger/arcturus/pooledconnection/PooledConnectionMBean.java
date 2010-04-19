package uk.ac.sanger.arcturus.pooledconnection;

import java.sql.SQLException;
import java.util.Date;

public interface PooledConnectionMBean {
	public boolean isInUse();
	public boolean isValid(int timeout) throws SQLException;
	public long getCurrentLeaseTime();
	public long getIdleTime();
	public Date getLastLeaseTime();
	public long getTotalLeaseTime();
	public int getLeaseCounter();
	public int getConnectionID();
	public String getOwnerClassName();
}
