package uk.ac.sanger.arcturus.scaffold;

public class GapSize {
    private int minsize = -1;
    private int maxsize = -1;

    public GapSize() {}

    public GapSize(int minsize, int maxsize) {
	this.minsize = minsize;
	this.maxsize = maxsize;
    }

    public GapSize(int size) {
	this(size, size);
    }

    public int getMinimum() { return minsize; }
    
    public int getMaximum() { return maxsize; }

    public void add(int value) {
	if (minsize < 0 || value < minsize)
	    minsize = value;
	
	if (maxsize < 0 || value > maxsize)
	    maxsize = value;
    }
    
    public void add(GapSize that) {
	if (minsize < 0 || (that.minsize >= 0 && that.minsize < minsize))
	    minsize = that.minsize;
	
	if (maxsize < 0 || (that.maxsize >=0 && that.maxsize > maxsize))
	    maxsize = that.maxsize;
    }
    
    public String toString() { return "GapSize[" + minsize + ":" + maxsize + "]"; }
}
