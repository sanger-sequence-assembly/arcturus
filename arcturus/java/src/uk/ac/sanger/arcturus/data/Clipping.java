package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * An object which represents sequence clipping.
 */

public class Clipping {
    public final static int QUAL = 1;
    public final static int SVEC = 2;
    public final static int CVEC = 3;

    protected int type;
    protected int left;
    protected int right;

    public Clipping(int type, int left, int right) {
	this.type = type;
	this.left = left;
	this.right = right;
    }

    public int getType() { return type; }

    public int getLeft() { return type; }

    public int getRight() { return right; }

    public String toString() {
	String strtype;

	switch (type) {
	case QUAL: strtype = "QUAL"; break;
	case SVEC: strtype = "SVEC"; break;
	case CVEC: strtype = "CVEC"; break;
	default: strtype = "UNKNOWN"; break;
	}

	return getClass().getName() + "[type=" + strtype + ", left=" + left +
	    ", right=" + right + "]";
    }
}
