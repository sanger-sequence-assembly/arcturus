package uk.ac.sanger.arcturus.gui.scaffold;

import uk.ac.sanger.arcturus.data.Contig;

public class ContigBox {
	protected Contig contig;
	protected int row;
	protected Range range;
	protected boolean forward;

	public ContigBox(Contig contig, int row, Range range, boolean forward) {
		this.contig = contig;
		this.row = row;
		this.range = range;
		this.forward = forward;
	}

	public Contig getContig() {
		return contig;
	}

	public int getRow() {
		return row;
	}

	public Range getRange() {
		return range;
	}

	public int getLeft() {
		return range.getStart();
	}

	public int getRight() {
		return range.getEnd();
	}

	public int getLength() {
		return range.getLength();
	}

	public boolean isForward() {
		return forward;
	}

	public String toString() {
		return "ContigBox[contig=" + contig.getID() + ", row=" + row
				+ ", range=" + range.getStart() + ".." + range.getEnd()
				+ ", " + (forward ? "forward" : "reverse") + "]";
	}
}
