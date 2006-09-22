package uk.ac.sanger.arcturus.test;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.data.*;

public class CAFWriter {
    protected PrintStream ps = null;
    protected Segment[] segments = null;
    protected SegmentComparatorByReadPosition segmentComparator =
	new SegmentComparatorByReadPosition();

    public CAFWriter(PrintStream ps) {
	this.ps = ps;
    }

    public void writeContig(Contig contig) {
	writeContigSequence(contig);

	if (contig.getDNA() != null) {
	    ps.println();
	    
	    writeContigDNA(contig);
	}

	if (contig.getQuality() != null) {
	    ps.println();

	    writeContigQuality(contig);
	}

	ps.println();

	Mapping[] mappings = contig.getMappings();

	for (int i = 0; i < mappings.length; i++)
	    writeRead(mappings[i].getSequence());
    }

    private void writeContigSequence(Contig contig) {
	ps.println("Sequence : Contig" + contig.getID());
	ps.println("Is_contig");
	ps.println("Unpadded");

	Mapping[] mappings = contig.getMappings();

	int maxsegcount = 0;

	for (int i = 0; i < mappings.length; i++) {
	    int segcount = mappings[i].getSegmentCount();
	    if (segcount > maxsegcount)
		maxsegcount = segcount;
	}

	if (segments == null || segments.length < maxsegcount)
	    segments = new Segment[maxsegcount];

	for (int i = 0; i < mappings.length; i++)
	    writeAssembledFrom(mappings[i]);
    }

    private void writeAssembledFrom(Mapping mapping) {
	Segment[] rawsegments = mapping.getSegments();

	for (int i = 0; i < rawsegments.length; i++)
	    segments[i] = rawsegments[i];

	Arrays.sort(segments, 0, rawsegments.length, segmentComparator);

	Sequence sequence = mapping.getSequence();
	Read read = sequence.getRead();
	String readname = read.getName();

	boolean forward = mapping.isForward();

	for (int i = 0; i < rawsegments.length; i++) {
	    int cstart = segments[i].getContigStart();
	    int rstart = segments[i].getReadStart();
	    int length = segments[i].getLength();

	    int cfinish = cstart + length - 1;

	    ps.print("Assembled_from " + readname);

	    if (forward) {
		int rfinish = rstart + length - 1;

		ps.println(" " + cstart + " " + cfinish +
			   " " + rstart + " " + rfinish);
	    } else {
		int rfinish = rstart - (length - 1);

		ps.println(" " + cfinish + " " + cstart +
			   " " + rfinish + " " + rstart);
	    }
	}
    }

    private void writeContigDNA(Contig contig) {
	ps.println("DNA : Contig" + contig.getID());
	writeDNA(contig.getDNA());
    }

    private void writeContigQuality(Contig contig) {
	ps.println("BaseQuality : Contig" + contig.getID());
	writeQuality(contig.getQuality());
    }

    private void writeRead(Sequence sequence) {
	Read read = sequence.getRead();

	ps.print(read.toCAFString());
	ps.print(sequence.toCAFString());

	ps.println();

	writeSequenceDNA(sequence);

	ps.println();

	writeSequenceQuality(sequence);

	ps.println();
    }

    private void writeSequenceDNA(Sequence sequence) {
	ps.println("DNA : " + sequence.getRead().getName());
	writeDNA(sequence.getDNA());
    }

 
    private void writeSequenceQuality(Sequence sequence) {
	ps.println("BaseQuality : " + sequence.getRead().getName());
	writeQuality(sequence.getQuality());
    }

    private void writeDNA(byte[] dna) {
	for (int i = 0; i < dna.length; i += 50) {
	    int sublen = (i + 50 < dna.length) ? 50 : dna.length - i;
	    ps.write(dna, i, sublen);
	    ps.print('\n');
	}
    }

    private void writeQuality(byte[] quality) {
	StringBuffer buffer = new StringBuffer();

	for (int i = 0; i < quality.length; i++) {
	    int qual = (int)quality[i];
	    buffer.append(qual);
	    //ps.print(qual);

	    if ((i % 25) < 24)
		buffer.append(' ');
		//ps.print(' ');
	    else
		buffer.append('\n');
		//ps.print('\n');
	}

	if ((quality.length % 25) != 0)
	    buffer.append('\n');
	    //ps.print('\n');

	ps.print(buffer.toString());
    }

    class SegmentComparatorByReadPosition implements Comparator {
	public int compare(Object o1, Object o2) {
	    Segment segment1 = (Segment)o1;
	    Segment segment2 = (Segment)o2;

	    int diff = segment1.getReadStart() - segment2.getReadStart();

	    return diff;
	}

	public boolean equals(Object obj) {
	    if (obj instanceof SegmentComparatorByReadPosition) {
		SegmentComparatorByReadPosition that = (SegmentComparatorByReadPosition)obj;
		return this == that;
	    } else
		return false;
	}
    }
}
