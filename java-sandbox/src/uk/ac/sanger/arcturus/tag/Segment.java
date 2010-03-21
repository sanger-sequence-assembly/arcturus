package uk.ac.sanger.arcturus.tag;

public class Segment {
	protected int cstart;
	protected int pstart;
	protected int pfinish;

	public Segment(int cstart, int pstart, int length, boolean forward) {
		if (forward) {
			this.cstart = cstart;
			this.pstart = pstart;
			this.pfinish = pstart + length - 1;
		} else {
			this.cstart = cstart + length - 1;
			this.pstart = pstart - length + 1;
			this.pfinish = pstart;
		}
	}

	public int mapToChild(int pos, boolean forward) {
		return mapToChild(pos, forward, false);
	}

	public int mapToChild(int pos, boolean forward, boolean force) {
		if (force || (pos >= pstart && pos <= pfinish)) {
			int offset = pos - pstart;
			return forward ? cstart + offset : cstart - offset;
		} else
			return -1;
	}

	public String toString() {
		return "Segment[pstart=" + pstart + ", pfinish=" + pfinish
				+ ", cstart=" + cstart + "]";
	}

}
