package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * An object which represents a single contiguous segment of a mapping between
 * a read and a contig.
 *
 * It has a start position on the read, a start position on the contig and a
 * length. The direction is a property of the parent Mapping.
 */

public class Segment {
    protected int cstart;
    protected int rstart;
    protected int length;

    /**
     * Constructs a segment object with the given start positions and length.
     *
     * @param cstart the start position on the contig.
     * @param rstart the start position on the read.
     * @param length the length of this segment.
     */

    public Segment(int cstart, int rstart, int length) {
	this.cstart = cstart;
	this.rstart = rstart;
	this.length = length;
    }

    /**
     * Returns the start position on the contig.
     *
     * @return the start position on the contig.
     */

    public int getContigStart() { return cstart; }

    /**
     * Returns the start position on the read.
     *
     * @return the start position on the read.
     */

    public int getReadStart() { return rstart; }

    /**
     * Returns the length of this segment.
     *
     * @return the length of this segment.
     */

    public int getLength() { return length; }
}
