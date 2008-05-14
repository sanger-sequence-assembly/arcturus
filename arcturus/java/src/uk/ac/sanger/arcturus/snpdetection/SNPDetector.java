package uk.ac.sanger.arcturus.snpdetection;

import java.util.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus;

public class SNPDetector {
	protected ReadGroup[] readGroups;
	protected int numGroups;
	protected Set<Read>[] readSets;

	protected Gap4BayesianConsensus defaultConsensus = new Gap4BayesianConsensus();
	protected Gap4BayesianConsensus[] groupConsensus;

	@SuppressWarnings("unchecked")
	public SNPDetector(ReadGroup[] readGroups) {
		this.readGroups = readGroups;

		numGroups = readGroups.length;

		groupConsensus = new Gap4BayesianConsensus[numGroups];

		for (int i = 0; i < numGroups; i++)
			groupConsensus[i] = new Gap4BayesianConsensus();

		readSets = (Set<Read>[]) new Set[numGroups];

		for (int i = 0; i < numGroups; i++)
			readSets[i] = new HashSet<Read>();
	}

	public boolean processContig(Contig contig) throws Exception {
		if (contig == null || contig.getMappings() == null)
			return false;

		System.err.println("Processing contig " + contig.getID() + "("
				+ contig.getLength() + " bp, " + contig.getReadCount()
				+ " reads)");

		classifyReadsInContig(contig);

		for (int j = 0; j < numGroups; j++)
			System.err.println("There are " + readSets[j].size()
					+ " reads in group " + readGroups[j]);

		processReadsInContig(contig);

		return true;
	}

	private void classifyReadsInContig(Contig contig) {
		for (int j = 0; j < numGroups; j++)
			readSets[j].clear();

		Mapping[] mappings = contig.getMappings();

		for (int i = 0; i < mappings.length; i++) {
			Read read = mappings[i].getSequence().getRead();

			for (int j = 0; j < numGroups; j++) {
				if (readGroups[j].belongsTo(read)) {
					readSets[j].add(read);
					break;
				}
			}
		}
	}

	private void processReadsInContig(Contig contig) throws Exception {
		Mapping[] mappings = contig.getMappings();
		int nreads = mappings.length;
		int cpos, rdleft, rdright, oldrdleft, oldrdright;

		int cstart = mappings[0].getContigStart();
		int cfinal = mappings[0].getContigFinish();

		for (int i = 0; i < mappings.length; i++) {
			if (mappings[i].getSequence() == null
					|| mappings[i].getSequence().getDNA() == null
					|| mappings[i].getSequence().getQuality() == null
					|| mappings[i].getSegments() == null)
				throw new Exception("Data missing for mapping");

			if (mappings[i].getContigStart() < cstart)
				cstart = mappings[i].getContigStart();

			if (mappings[i].getContigFinish() > cfinal)
				cfinal = mappings[i].getContigFinish();
		}

		int maxdepth = -1;

		for (cpos = cstart, rdleft = 0, oldrdleft = 0, rdright = -1, oldrdright = -1; cpos <= cfinal; cpos++) {
			defaultConsensus.reset();

			for (int i = 0; i < groupConsensus.length; i++)
				groupConsensus[i].reset();

			while ((rdleft < nreads)
					&& (mappings[rdleft].getContigFinish() < cpos))
				rdleft++;

			while ((rdright < nreads - 1)
					&& (mappings[rdright + 1].getContigStart() <= cpos))
				rdright++;

			int depth = 1 + rdright - rdleft;

			if (rdleft != oldrdleft || rdright != oldrdright) {
				if (depth > maxdepth)
					maxdepth = depth;
			}

			oldrdleft = rdleft;
			oldrdright = rdright;

			for (int rdid = rdleft; rdid <= rdright; rdid++) {
				int rpos = mappings[rdid].getReadOffset(cpos);

				int qual = rpos >= 0 ? mappings[rdid].getQuality(rpos)
						: mappings[rdid].getPadQuality(cpos);
				char base = rpos >= 0 ? mappings[rdid].getBase(rpos) : '*';

				if (qual > 0) {
					Sequence sequence = mappings[rdid].getSequence();

					Clipping qclip = sequence.getQualityClipping();

					if (qclip == null || rpos < 0 || rpos <= qclip.getLeft()
							|| rpos >= qclip.getRight())
						continue;

					Read read = mappings[rdid].getSequence().getRead();

					char strand = mappings[rdid].isForward() ? 'F' : 'R';

					int chemistry = read == null ? Read.UNKNOWN : read
							.getChemistry();

					Gap4BayesianConsensus consensus = defaultConsensus;

					for (int i = 0; i < readSets.length; i++) {
						if (readSets[i].contains(read)) {
							consensus = groupConsensus[i];
							break;
						}
					}

					consensus.addBase(base, qual, strand, chemistry);
				}
			}

			int defaultReads = defaultConsensus.getReadCount();

			if (defaultReads > 0) {
				char defaultBase = defaultConsensus.getBestBase();
				int defaultScore = defaultConsensus.getBestScore();

				for (int i = 0; i < groupConsensus.length; i++) {
					int nReads = groupConsensus[i].getReadCount();

					if (nReads > 0) {
						char base = groupConsensus[i].getBestBase();
						int score = groupConsensus[i].getBestScore();

						if (base != defaultBase) {
							System.err.println(cpos + "\t" + defaultBase
									+ " (Q=" + defaultScore + ", N="
									+ defaultReads + ")\t" + i + "\t" + base
									+ " (Q=" + score + ", N=" + nReads + ")");
						}
					}
				}
			}
		}

	}
}
