package uk.ac.sanger.arcturus.pooledconnection;

public interface ConnectionPoolMBean {
	public int getConnectionCount();
	public int getActiveConnectionCount();
}
