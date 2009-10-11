package uk.ac.sanger.arcturus.data;

/**
 * An object which represents a single contiguous segment of a mapping between a
 * read and a contig.
 * 
 * It has a start position on the read, a start position on the contig and a
 * length. The direction is a property of the parent Mapping.
 */

public class Segment implements java.lang.Comparable {
	protected int cstart;
	protected int rstart;
	protected int length;

	protected int cfinish;

	/**
	 * Constructs a segment object with the given start positions and length.
	 * 
	 * @param cstart
	 *            the start position on the contig.
	 * @param rstart
	 *            the start position on the read.
	 * @param length
	 *            the length of this segment.
	 */

	public Segment(int cstart, int rstart, int length) {
		this.cstart = cstart;
		this.rstart = rstart;
		this.length = length;

		this.cfinish = cstart + length - 1;
	}

	/**
	 * Returns the start position on the contig.
	 * 
	 * @return the start position on the contig.
	 */

	public int getContigStart() {
		return cstart;
	}

	/**
	 * Returns the end position on the contig.
	 * 
	 * @return the end position on the contig.
	 */

	public int getContigFinish() {
		return cfinish;
	}

	/**
	 * Returns the start position on the read.
	 * 
	 * @return the start position on the read.
	 */

	public int getReadStart() {
		return rstart;
	}

	/**
	 * Returns the end position on the read, given the orientation.
	 * 
	 * @param forward
	 *            true if the parent mapping represents a read that is
	 *            co-aligned to the contig, false if the read is counter-aligned
	 *            to the contig.
	 * 
	 * @return the end position on the read.
	 */

	public int getReadFinish(boolean forward) {
		return forward ? rstart + (length - 1) : rstart - (length - 1);
	}

	/**
	 * Returns the length of this segment.
	 * 
	 * @return the length of this segment.
	 */

	public int getLength() {
		return length;
	}

	/**
	 * Returns the read offset corresponding to the specified contig offset and
	 * orientation.
	 * 
	 * @param cpos
	 *            the contig offset position.
	 * @param forward
	 *            true if the parent mapping represents a read that is
	 *            co-aligned to the contig, false if the read is counter-aligned
	 *            to the contig.
	 * 
	 * @return the read offset position, or -1 if the contig offset position
	 *         falls outside the range of this segment.
	 */

	public int getReadOffset(int cpos, boolean forward) {
		if (cpos < cstart || cpos > cfinish)
			return -1;
		else
			return forward ? rstart + (cpos - cstart) : rstart
					- (cpos - cstart);
	}

	/**
	 * Returns a string representation of this object.
	 * 
	 * @return a string representation of this object.
	 */

	public String toString() {
		return "Segment[cstart=" + cstart + ", rstart=" + rstart + ", length="
				+ length + "]";
	}

	/**
	 * Compares this object with the specified object for order.
	 * 
	 * @return a negative integer, zero, or a positive integer as this object is
	 *         less than, equal to, or greater than the specified object.
	 */

	public int compareTo(Object o) {
		Segment that = (Segment) o;

		return this.cstart - that.cstart;
	}
}
