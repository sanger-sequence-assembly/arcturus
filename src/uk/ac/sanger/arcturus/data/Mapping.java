package uk.ac.sanger.arcturus.data;

import uk.ac.sanger.arcturus.database.*;

/**
 * An object which represents an alignment of a read to a contig.
 *
 * It is characterised by a Sequence, a start and end position on the contig,
 * and a direction.
 *
 * It may also have a set of Segment objects which specify the mapping in greater
 * detail.
 */

public class Mapping {
    protected Sequence sequence;
    protected int cstart;
    protected int cfinish;
    protected int direction;
    protected Segment[] segments;
    protected int nsegs;

    /**
     * A constant representing a read which is co-aligned with a contig.
     */

    public final static int FORWARD = 1;

    /**
     * A constant representing a read which is counter-aligned with a contig.
     */

    public final static int REVERSE = 2;

    /**
     * Constructs a mapping from the specified sequence, contig start and end position,
     * direction and number of segments.
     *
     * The array of Segment objects may be filled in by subsequence calls to addSegment.
     *
     * @param sequence the read sequence of this read-to-contig alignment.
     * @param cstart the start position of the alignment on the contig.
     * @param cfinish the end position of the alignment on the contig.
     * @param direction the direction in which the read is aligned to the contig. This
     * should be one of FORWARD or REVERSE.
     * @param numsegs the number of Segment objects which this alignment contains.
     */

    public Mapping(Sequence sequence, int cstart, int cfinish, int direction, int numsegs) {
	this.sequence = sequence;
	this.cstart = cstart;
	this.cfinish = cfinish;
	this.direction = direction;
	this.segments = new Segment[numsegs];
	nsegs = 0;
    }

    /**
     * Constructs a mapping from the specified sequence, contig start and end position,
     * direction and an array of Segment objects.
     *
     * @param sequence the read sequence of this read-to-contig alignment.
     * @param cstart the start position of the alignment on the contig.
     * @param cfinish the end position of the alignment on the contig.
     * @param direction the direction in which the read is aligned to the contig. This
     * should be one of FORWARD or REVERSE.
     * @param segments the array of Segment objects for this alignment.
     */

    public Mapping(Sequence sequence, int cstart, int cfinish, int direction, Segment[] segments) {
	this.sequence = sequence;
	this.cstart = cstart;
	this.cfinish = cfinish;
	this.direction = direction;
	this.segments = segments;
	nsegs = segments.length;
    }

    /**
     * Returns the Sequence object corresponding to this alignment.
     *
     * @return the Sequence object corresponding to this alignment.
     */

    public Sequence getSequence() { return sequence; }

    /**
     * Returns the start position of the alignment on the contig.
     *
     * @return the start position of the alignment on the contig.
     */

    public int getContigStart() { return cstart; }

    /**
     * Returns the end position of the alignment on the contig.
     *
     * @return the end position of the alignment on the contig.
     */

    public int getContigFinish() { return cfinish; }

    /**
     * Returns the array of Segment objects for this alignment.
     *
     * @return the array of Segment objects for this alignment.
     */

    public Segment[] getSegments() { return segments; }

    /**
     * Returns the number of Segment objects which this alignment currently contains.
     * This may be less than the number specified in the constructor if the segment
     * array has not been filled yet.
     *
     * @return the number of Segment objects which this alignment currently contains.
     */

    public int getSegmentCount() { return nsegs; }

    /**
     * Adds a Segment object to the array of segments for this alignment.
     *
     * @param segment the Segment object to be added to this alignment.
     *
     * @return true if the segment was successfully added; otherwise, false.
     * A false value will be returned when the array becomes full. There is
     * currently no mechanism to extend the array, so the size must be
     * correctly specified when the Mapping object is created.
     */

    public boolean addSegment(Segment segment) {
	if (nsegs < segments.length) {
	    segments[nsegs++] = segment;
	    return true;
	} else
	    return false;
    }
}
