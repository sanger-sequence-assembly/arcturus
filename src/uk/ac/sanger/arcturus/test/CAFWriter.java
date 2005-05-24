import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.data.*;

public class CAFWriter {
    protected PrintStream ps = null;

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

	for (int i = 0; i < mappings.length; i++)
	    writeAssembledFrom(mappings[i]);
    }

    private void writeAssembledFrom(Mapping mapping) {
	Segment[] segments = mapping.getSegments();
	Sequence sequence = mapping.getSequence();
	Read read = sequence.getRead();
	String readname = read.getName();

	boolean forward = mapping.isForward();

	for (int i = 0; i < segments.length; i++) {
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
	ps.println("Sequence : " + sequence.getRead().getName());
	ps.println("Is_read");
	ps.println("Unpadded");

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
	for (int i = 0; i < quality.length; i++) {
	    int qual = (int)quality[i];
	    ps.print(qual);

	    if ((i % 25) < 24)
		ps.print(' ');
	    else
		ps.print('\n');
	}

	if ((quality.length % 25) != 0)
	    ps.print('\n');
    }
}
