package uk.ac.sanger.arcturus.gui.scaffold;

public class Range {
	protected int start;
	protected int end;

	public Range(int start, int end) {
		this.start = (start < end) ? start : end;
		this.end = (start < end) ? end : start;
	}

	public int getStart() {
		return start;
	}

	public int getEnd() {
		return end;
	}

	public int getLength() {
		return 1 + end - start;
	}

	public boolean overlaps(Range that) {
		return !(start > that.end || end < that.start);
	}

	public void shift(int offset) {
		start += offset;
		end += offset;
	}
}
