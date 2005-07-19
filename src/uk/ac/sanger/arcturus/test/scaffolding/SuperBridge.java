package scaffolding;

class SuperBridge extends Core {
    protected int template_id = -1;
    protected int silow = -1;
    protected int sihigh = -1;
    protected Link linka = null;
    protected Link linkb = null;

    public SuperBridge(int template_id, int silow, int sihigh,
		  Link linka, Link linkb) {
	this.template_id = template_id;
	this.silow = silow;
	this.sihigh = sihigh;
	this.linka = linka;
	this.linkb = linkb;
    }

    public SuperBridge(int template_id, int silow, int sihigh) {
	this.template_id = template_id;
	this.silow = silow;
	this.sihigh = sihigh;
    }

    public boolean addLink(Link link) {
	if (linka == null) {
	    linka = link;
	    return true;
	}

	if (linkb == null) {
	    linkb = link;
	    return true;
	}

	return false;
    }

    public int getTemplateId() { return template_id; }

    public int getSilow() { return silow; }

    public int getSihigh() { return sihigh; }

    public Link getLinkA() { return linka; }

    public Link getLinkB() { return linkb; }

    public String toString() {
	return "SuperBridge[template_id=" + template_id +
	    ", silow=" + silow +
	    ", sihigh=" + sihigh +
	    ", linka=" + linka + ", linkb=" + linkb + "]";
    }
}
