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
    protected boolean forward;
    protected Segment[] segments;
    protected int nsegs;

    /**
     * Constructs a mapping from the specified sequence, contig start and end position,
     * direction and number of segments.
     *
     * The array of Segment objects may be filled in by subsequence calls to addSegment.
     *
     * @param sequence the read sequence of this read-to-contig alignment.
     * @param cstart the start position of the alignment on the contig.
     * @param cfinish the end position of the alignment on the contig.
     * @param forward true if the sequence is co-aligned to the contig, false if the
     * read is counter-aligned to the contig.
     * @param numsegs the number of Segment objects which this alignment contains.
     */

    public Mapping(Sequence sequence, int cstart, int cfinish, boolean forward, int numsegs) {
	this.sequence = sequence;
	this.cstart = cstart;
	this.cfinish = cfinish;
	this.forward = forward;
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
     * @param forward true if the sequence is co-aligned to the contig, false if the
     * read is counter-aligned to the contig.
     * @param segments the array of Segment objects for this alignment.
     */

    public Mapping(Sequence sequence, int cstart, int cfinish, boolean forward, Segment[] segments) {
	this.sequence = sequence;
	this.cstart = cstart;
	this.cfinish = cfinish;
	this.forward = forward;
	this.segments = segments;

	if (segments == null)
	    nsegs = 0;
	else {
	    java.util.Arrays.sort(segments);
	    nsegs = segments.length;
	}
    }

    /**
     * Constructs a mapping from the specified sequence, contig start and end position,
     * and a direction.
     *
     * @param sequence the read sequence of this read-to-contig alignment.
     * @param cstart the start position of the alignment on the contig.
     * @param cfinish the end position of the alignment on the contig.
     * @param forward true if the sequence is co-aligned to the contig, false if the
     * read is counter-aligned to the contig.
     */

    public Mapping(Sequence sequence, int cstart, int cfinish, boolean forward) {
	this(sequence, cstart, cfinish, forward, null);
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
     * Returns the direction of the alignment on the contig.
     *
     * @return the direction of the alignment on the contig.
     */

    public boolean isForward() { return forward; }

    /**
     * Returns the array of Segment objects for this alignment.
     *
     * @return the array of Segment objects for this alignment.
     */

    public Segment[] getSegments() { return segments; }

    /**
     * Sets the array of Segment objects for this alignment.
     *
     * @param segments the array of Segment objects for this alignment.
     */

    public void setSegments(Segment[] segments) {
	this.segments = segments;

	if (segments != null)
	    java.util.Arrays.sort(segments);
    }

    /**
     * Returns the number of Segment objects which this alignment currently contains.
     *
     * @return the number of Segment objects which this alignment currently contains.
     */

    public int getSegmentCount() {
	if (segments != null) {
	    int count = 0;
	    for (int i = 0; i < segments.length; i++)
		if (segments[i] != null)
		    count++;

	    return count;
	} else
	    return nsegs;
    }

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
	    java.util.Arrays.sort(segments, 0, nsegs);
	    return true;
	} else
	    return false;
    }

    /**
     * Returns the base corresponding to the specified position in the sequence,
     * reverse complemented if necessary.
     *
     * @param i the position in the sequence.
     *
     * @return the base corresponding to the specified position in the sequence,
     * reverse complemented if necessary. If the sequence or its DNA is not defined,
     * or if the position is outside the valid range, returns '?'.
     */

    public char getBase(int i) {
	if (sequence == null)
	    return '?';

	byte[] dna = sequence.getDNA();

	char base;

	if (dna != null && i > 0 && i <= dna.length)
	    base = (char)dna[i-1];
	else
	    base = '?';

	if (!forward) {
	    switch (base) {
	    case 'a': base = 't'; break;
	    case 'c': base = 'g'; break;
	    case 'g': base = 'c'; break;
	    case 't': base = 'a'; break;
	    case 'A': base = 'T'; break;
	    case 'C': base = 'G'; break;
	    case 'G': base = 'C'; break;
	    case 'T': base = 'A'; break;
	    }
	}

	return base;
    }

    /**
     * Returns the quality corresponding to the specified position in the sequence,
     * reverse complemented if necessary.
     *
     * @param i the position in the sequence.
     *
     * @return the quality corresponding to the specified position in the sequence,
     * reverse complemented if necessary. If the sequence or its quality is not defined,
     * or if the position is outside the valid range, returns -1.
     */

    public int getQuality(int i) {
	if (sequence == null)
	    return -1;

	byte[] quality = sequence.getQuality();

	if (quality != null && i > 0 && i <= quality.length)
	    return (int)quality[i-1];
	else
	    return -1;
    }

    /**
     * Returns the read offset corresponding to the specified contig offset
     * and orientation.
     *
     * @param cpos the contig offset position.
     * @param forward true if the parent mapping represents a read that is
     * co-aligned to the contig, false if the read is counter-aligned to the
     * contig.
     *
     * @return the read offset position, or -1 if the contig offset position
     * falls outside the range of this mapping.
     */

    public int getReadOffset(int cpos) {
	if (cpos < cstart || cpos > cfinish || segments == null)
	    return -1;

	int rpos;

	for (int i = 0; i < segments.length; i++) {
	    if (segments[i] != null) {
		rpos = segments[i].getReadOffset(cpos, forward);
		if (rpos >= 0)
		    return rpos;
	    }
	}

	return -1;
    }

    /**
     * Returns the quality of the pad at the specified contig offset.
     *
     * @param cpos the contig offset position.
     * @param quality the base quality array of the sequence of this mapping.
     *
     * @return the quality of the pad at the specified contig position,
     * or -1 if there is no pad at that position in this mapping.
     */

    public int getPadQuality(int cpos) {
	if (cpos < cstart || cpos > cfinish || sequence == null ||
	    segments == null || getSegmentCount() < 2)
	    return -1;

	int rpos;

	byte[] quality = sequence.getQuality();

	if (quality == null)
	    return -1;

	for (int i = 1; i < segments.length; i++) {
	    if (segments[i-1] != null && segments[i] != null) {
		int cleft = segments[i-1].getContigFinish();

		if (cpos <= cleft)
		    return -1;

		int cright = segments[i].getContigStart();

		int rleft = -1, rright = -1, qleft = -1, qright = -1, q = -1;

		if (cpos > cleft && cpos < cright) {
		    rleft = segments[i-1].getReadFinish(forward);
		    rright = segments[i].getReadStart();
		    qleft = (int)quality[rleft-1];
		    qright = (int)quality[rright-1];
		    q = qleft + ((qright - qleft) * (cpos - cleft))/(cright - cleft);
		    return q;
		}
	    }
	}
	
	return -1;
    }


    /**
     * Returns a string representation of this object.
     *
     * @return a string representation of this object.
     */

    public String toString() {
	String text= "Mapping[sequence=" + sequence.getID() + ", cstart=" + cstart +
	    ", cfinish=" + cfinish + ", direction=" + (forward ? "Forward" : "Reverse");

	if (segments != null) {
	    text += "\nsegments={\n";
	    for (int i = 0; i < segments.length; i++) {
		if (segments[i] != null)
		    text += "    " + segments[i] + "\n";
	    }
	    text += "}";
	}

	text += "]";

	return text;
    }
}
