package uk.ac.sanger.arcturus.test.scaffolding;

class Link {
	private int contig_id = -1;
	private int read_id = -1;
	private int cstart = -1;
	private int cfinish = -1;
	private boolean forward = true;

	public Link(int contig_id, int read_id, int cstart, int cfinish,
			boolean forward) {
		this.contig_id = contig_id;
		this.read_id = read_id;
		this.cstart = cstart;
		this.cfinish = cfinish;
		this.forward = forward;
	}

	public int getContigId() {
		return contig_id;
	}

	public int getReadId() {
		return read_id;
	}

	public int getCStart() {
		return cstart;
	}

	public int getCFinish() {
		return cfinish;
	}

	public boolean isForward() {
		return forward;
	}

	public String toString() {
		return "Link[contig=" + contig_id + ", read=" + read_id + ", cstart="
				+ cstart + ", cfinish=" + cfinish + ", sense="
				+ (forward ? "F" : "R") + "]";
	}
}
