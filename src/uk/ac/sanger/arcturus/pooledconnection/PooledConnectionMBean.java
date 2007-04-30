package uk.ac.sanger.arcturus.pooledconnection;

public interface PooledConnectionMBean {
	public boolean isInUse();
	public long getCurrentLeaseTime();
	public long getIdleTime();
	public long getLastLeaseTime();
	public long getTotalLeaseTime();
	public int getLeaseCounter();
	public String getOwnerClassName();
}
