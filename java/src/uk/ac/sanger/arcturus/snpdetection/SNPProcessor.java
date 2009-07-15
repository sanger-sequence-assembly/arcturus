package uk.ac.sanger.arcturus.snpdetection;

import uk.ac.sanger.arcturus.data.Contig;

public interface SNPProcessor {
	public void processSNP(Contig contig, int contig_position,
			char defaultBase, int defaultScore, int defaultReads, Base base);
}
