package scaffolding;

class Bridge extends SuperBridge {
    private int gapsize = -1;

    public Bridge(int template_id, int silow, int sihigh, int gapsize,
		  Link linka, Link linkb) {
	super(template_id, silow, sihigh, linka, linkb);
	this.gapsize = gapsize;
    }

    public Bridge(int template_id, int silow, int sihigh, int gapsize) {
	super(template_id, silow, sihigh);
	this.gapsize = gapsize;
    }

    public int getGapSize() { return gapsize; }

    public String toString() {
	return "Bridge[template_id=" + template_id +
	    ", silow=" + silow +
	    ", sihigh=" + sihigh +
	    ", gapsize=" + gapsize +
	    ", linka=" + linka + ", linkb=" + linkb + "]";
    }
}
