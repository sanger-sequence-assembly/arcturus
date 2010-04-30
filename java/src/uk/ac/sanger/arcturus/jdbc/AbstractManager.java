package uk.ac.sanger.arcturus.jdbc;

import java.sql.SQLException;

public abstract class AbstractManager {
	protected boolean cacheing = true;

	public void setCacheing(boolean cacheing) {
		this.cacheing = cacheing;
	}

	public boolean isCacheing() {
		return cacheing;
	}

	public abstract void clearCache();
	
	public abstract void preload() throws SQLException;
}
