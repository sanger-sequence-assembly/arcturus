package uk.ac.sanger.arcturus.utils;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class CAFWriter {
	protected PrintStream ps = null;
	protected SegmentComparatorByReadPosition segmentComparator = new SegmentComparatorByReadPosition();

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

		BasicSequenceToContigMapping[] mappings = contig.getMappings();

		for (int i = 0; i < mappings.length; i++)
			writeRead(mappings[i].getSequence());
	}

	private void writeContigSequence(Contig contig) {
		ps.println("Sequence : Contig" + contig.getID());
		ps.println("Is_contig");
		ps.println("Unpadded");

		BasicSequenceToContigMapping[] mappings = contig.getMappings();

		for (int i = 0; i < mappings.length; i++)
			writeAssembledFrom(mappings[i]);
		
		try {
			contig.getArcturusDatabase().updateContig(contig, ArcturusDatabase.CONTIG_TAGS);
		} catch (Exception e) {
			Arcturus.logWarning("Error whilst fetching contig tags", e);
		}
		
		Vector<Tag> tags = contig.getTags();
		
		if (tags != null) {
			for (Tag tag : tags)
				ps.println(tag.toCAFString());
		}
	}

	private void writeAssembledFrom(BasicSequenceToContigMapping mapping) {
		Sequence sequence = mapping.getSequence();
		Read read = sequence.getRead();
		String readname = read.getName();
		
		AssembledFrom[] afdata = mapping.getAssembledFromRecords();

		for (int i = 0; i < afdata.length; i++) {
			ps.print("Assembled_from " + readname);

			Range readRange = afdata[i].getReadRange();
			Range contigRange = afdata[i].getContigRange();
			
			ps.print(" " + contigRange.getStart() + " " + contigRange.getEnd());
			ps.print(" " + readRange.getStart() + " " + readRange.getEnd());

			ps.println();
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

		if (read instanceof CapillaryRead)
			ps.print(((CapillaryRead)read).toCAFString());
		
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
			int qual = (int) quality[i];
			buffer.append(qual);
			// ps.print(qual);

			if ((i % 25) < 24)
				buffer.append(' ');
			// ps.print(' ');
			else
				buffer.append('\n');
			// ps.print('\n');
		}

		if ((quality.length % 25) != 0)
			buffer.append('\n');
		// ps.print('\n');

		ps.print(buffer.toString());
	}

	class SegmentComparatorByReadPosition implements Comparator<BasicSegment> {
		public int compare(BasicSegment segment1, BasicSegment segment2) {
			int diff = segment1.getSubjectStart() - segment2.getSubjectStart();

			return diff;
		}

		public boolean equals(Object obj) {
			if (obj instanceof SegmentComparatorByReadPosition) {
				SegmentComparatorByReadPosition that = (SegmentComparatorByReadPosition) obj;
				return this == that;
			} else
				return false;
		}
	}
}
