package uk.ac.sanger.arcturus.pooledconnection;

public interface ConnectionPoolMBean {
	public int getConnectionCount();
	public int getActiveConnectionCount();
	public int getCreatedConnectionCount();
	public int getReapedConnectionCount();
	public void reapConnections(long timeout);
}
