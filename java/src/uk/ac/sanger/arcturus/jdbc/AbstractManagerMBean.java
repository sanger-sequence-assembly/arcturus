package uk.ac.sanger.arcturus.jdbc;

public interface AbstractManagerMBean {
	public boolean isCacheing();
	public void setCacheing(boolean cacheing);
	
	public String getCacheStatistics();
}
