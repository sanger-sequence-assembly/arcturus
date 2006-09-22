package uk.ac.sanger.arcturus.test.scaffolding;


class Gap extends Core {
    private int size = -1;

    public Gap(int size) {
	this.size = size;
    }

    public int getSize() { return size; }

    public String toString() {
	int nBridges = children.size();

	if (nBridges > 0)
	    return "Gap[size=" + size + ", " + nBridges + " bridges]";
	else
	    return "Gap[size=" + size + ", no bridges]";
    }
}
