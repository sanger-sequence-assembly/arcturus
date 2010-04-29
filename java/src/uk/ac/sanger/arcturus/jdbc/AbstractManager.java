package uk.ac.sanger.arcturus.jdbc;

import java.sql.Connection;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public abstract class AbstractManager {
	protected boolean cacheing = true;
	protected Connection conn;

	public void setCacheing(boolean cacheing) {
		this.cacheing = cacheing;
	}

	public boolean isCacheing() {
		return cacheing;
	}

	public abstract void clearCache();
	
	public abstract void preload() throws ArcturusDatabaseException;
	
	protected abstract void prepareConnection() throws SQLException;
	
	protected void setConnection(Connection conn) throws SQLException {
		this.conn = conn;		
		prepareConnection();
	}
}
