package uk.ac.sanger.arcturus.database;

public abstract class AbstractManager {
    protected boolean cacheing = true;

    public void setCacheing(boolean cacheing) {
	this.cacheing = cacheing;
    }

    public boolean isCacheing() { return cacheing; }

    public abstract void clearCache();
}
