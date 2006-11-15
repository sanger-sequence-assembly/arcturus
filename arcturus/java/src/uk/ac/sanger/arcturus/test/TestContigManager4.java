package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;

import java.util.*;
import java.io.*;

public class TestContigManager4 {
	private static long lasttime;
	private static Runtime runtime = Runtime.getRuntime();

	private static Consensus consensus = new Consensus();

	public static void main(String args[]) {
		lasttime = System.currentTimeMillis();

		System.err.println("TestContigManager4");
		System.err.println("==================");
		System.err.println();

		String instance = null;
		String organism = null;

		String algname = null;

		int flags = ArcturusDatabase.CONTIG_BASIC_DATA;

		boolean debug = false;
		boolean lowmem = false;
		boolean silent = false;
		boolean quiet = false;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-algorithm"))
				algname = args[++i];

			if (args[i].equalsIgnoreCase("-debug"))
				debug = true;

			if (args[i].equalsIgnoreCase("-lowmem"))
				lowmem = true;

			if (args[i].equalsIgnoreCase("-silent"))
				silent = true;

			if (args[i].equalsIgnoreCase("-quiet"))
				quiet = true;

			if (args[i].equalsIgnoreCase("-loadMappings"))
				flags |= ArcturusDatabase.CONTIG_MAPPINGS_READS_AND_TEMPLATES;

			if (args[i].equalsIgnoreCase("-loadSequenceDNA"))
				flags |= ArcturusDatabase.CONTIG_SEQUENCE_DNA_AND_QUALITY;

			if (args[i].equalsIgnoreCase("-loadContigConsensus"))
				flags |= ArcturusDatabase.CONTIG_CONSENSUS;

			if (args[i].equalsIgnoreCase("-loadAuxiliaryData"))
				flags |= ArcturusDatabase.CONTIG_SEQUENCE_AUXILIARY_DATA;

			if (args[i].equalsIgnoreCase("-loadMappingSegments"))
				flags |= ArcturusDatabase.CONTIG_MAPPING_SEGMENTS;

			if (args[i].equalsIgnoreCase("-loadContigTags"))
				flags |= ArcturusDatabase.CONTIG_TAGS;

			if (args[i].equalsIgnoreCase("-loadForCAF"))
				flags |= ArcturusDatabase.CONTIG_TO_GENERATE_CAF;

			if (args[i].equalsIgnoreCase("-loadToCalculateConsensus"))
				flags |= ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS;
		}

		if (instance == null && organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		if (algname == null)
			algname = System.getProperty("arcturus.default.algorithm");

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			if (lowmem)
				adb.getSequenceManager().setCacheing(false);

			java.sql.Connection conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			if (!quiet)
				adb.addContigManagerEventListener(new MyListener());

			BufferedReader stdin = new BufferedReader(new InputStreamReader(
					System.in));

			Class algclass = Class.forName(algname);
			ConsensusAlgorithm algorithm = (ConsensusAlgorithm) algclass
					.newInstance();

			if (debug
					&& algorithm instanceof uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus)
				((Gap4BayesianConsensus) algorithm)
						.setDebugPrintStream(System.out);

			String line = null;
			Contig contig = null;
			CAFWriter cafWriter = new CAFWriter(System.out);

			long peakMemory = 0;

			while (true) {
				if (!quiet)
					System.err.print(">");

				line = stdin.readLine();

				if (line == null) {
					System.err.println("Peak memory usage: " + peakMemory
							+ " kb");
					System.exit(0);
				}

				String[] words = tokenise(line);

				for (int i = 0; i < words.length; i++) {
					if (words[i].equalsIgnoreCase("quit")
							|| words[i].equalsIgnoreCase("exit")) {
						System.err.println("Peak memory usage: " + peakMemory
								+ " kb");
						System.exit(0);
					}

					if (words[i].equalsIgnoreCase("caf")) {
						if (contig != null)
							cafWriter.writeContig(contig);
					} else if (words[i].equalsIgnoreCase("cons")) {
						if (contig != null) {
							System.err.println("Calculate consensus ["
									+ contig.getLength() + " bp]");
							long clockStart = System.currentTimeMillis();

							PrintStream debugps = debug ? System.out : null;

							if (calculateConsensus(contig, algorithm,
									consensus, debugps)) {
								long clockStop = System.currentTimeMillis()
										- clockStart;
								System.err.println("TOTAL TIME: " + clockStop
										+ " ms");

								byte[] dna = consensus.getDNA();
								byte[] quality = consensus.getQuality();

								byte[] dna2 = contig.getDNA();
								byte[] quality2 = contig.getQuality();

								if (dna.length != dna2.length
										|| quality.length != quality2.length) {
									System.err.println("Length mismatch: DNA "
											+ dna.length + " vs " + dna2.length
											+ ", quality " + quality.length
											+ " vs " + quality2.length);
								} else {
									for (int k = 0; k < dna.length; k++) {
										if (dna[k] != dna2[k])
											System.err.println("MISMATCH: "
													+ (k + 1) + " --> "
													+ dna[k] + " " + quality[k]
													+ " vs " + dna2[k] + " "
													+ quality2[k]);
									}
								}
							} else
								System.err
										.println("Data missing, operation abandoned");
						} else
							System.err.println("No current contig");
					} else if (words[i].equalsIgnoreCase("dump")) {
						if (contig != null) {
							System.out.println("Contig id=" + contig.getID()
									+ ", length=" + contig.getLength()
									+ ", reads=" + contig.getReadCount());

							Mapping[] mappings = contig.getMappings();

							if (mappings != null) {
								for (int imap = 0; imap < mappings.length; imap++) {
									Mapping mapping = mappings[imap];

									Sequence sequence = mapping.getSequence();

									Read read = sequence.getRead();

									boolean forward = mapping.isForward();

									System.out.println("Mapping " + imap
											+ " : seq_id=" + sequence.getID()
											+ ", cstart="
											+ mapping.getContigStart()
											+ ", cfinish="
											+ mapping.getContigFinish()
											+ ", sense="
											+ (forward ? "forward" : "reverse")
											+ ", read=" + read.getName());

									Segment segments[] = mapping.getSegments();

									if (segments != null) {
										for (int iseg = 0; iseg < segments.length; iseg++) {
											Segment segment = segments[iseg];
											int cstart = segment
													.getContigStart();
											int rstart = segment.getReadStart();
											int length = segment.getLength();
											int cfinish = cstart + length - 1;
											int rfinish = forward ? rstart
													+ length - 1 : rstart
													- (length - 1);
											System.err.println("    " + cstart
													+ " " + cfinish + " --> "
													+ rstart + " " + rfinish);
										}

										System.out.println();
									}
								}
							} else
								System.out.println("No mappings to display");
						} else
							System.err.println("No current contig");
					} else {
						if (lowmem) {
							if (contig != null)
								contig.setMappings(null);
						}

						int contig_id = Integer.parseInt(words[i]);

						long clockStart = System.currentTimeMillis();

						contig = adb.getContigByID(contig_id, flags);

						long usedMemory = (runtime.totalMemory() - runtime
								.freeMemory()) / 1024;

						if (usedMemory > peakMemory)
							peakMemory = usedMemory;

						if (!silent) {
							long clockStop = System.currentTimeMillis()
									- clockStart;

							System.err
									.println("Contig " + contig_id + " : "
											+ contig.getLength() + " bp, "
											+ contig.getReadCount()
											+ " reads (" + clockStop + " ms, "
											+ usedMemory + " kb)");
						}
					}
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public static String[] tokenise(String str) {
		StringTokenizer tok = new StringTokenizer(str);

		int ntokens = tok.countTokens();

		String[] tokens = new String[ntokens];

		for (int i = 0; i < ntokens && tok.hasMoreTokens(); i++)
			tokens[i] = tok.nextToken();

		return tokens;
	}

	public static void report() {
		long timenow = System.currentTimeMillis();

		System.out.println("******************** REPORT ********************");
		System.out.println("Time: " + (timenow - lasttime));

		System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()
				/ 1024 + "/" + runtime.totalMemory() / 1024);
		System.out.println("************************************************");
		System.out.println();
	}

	public static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-algorithm\tName of class for consensus algorithm");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-lowmem", "-silent", "-quiet",
				"-loadMappings", "-loadSequenceDNA", "-loadContigConsensus",
				"-loadAuxiliaryData", "-loadMappingSegments",
				"-loadContigTags", "-loadForCAF", "-loadToCalculateConsensus" };
		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);
	}

	public static boolean calculateConsensus(Contig contig,
			ConsensusAlgorithm algorithm, Consensus consensus,
			PrintStream debugps) {
		if (contig == null || contig.getMappings() == null)
			return false;

		Mapping[] mappings = contig.getMappings();
		int nreads = mappings.length;
		int cpos, rdleft, rdright, oldrdleft, oldrdright;
		int maxdepth = -1;

		int cstart = mappings[0].getContigStart();
		int cfinal = mappings[0].getContigFinish();

		for (int i = 0; i < mappings.length; i++) {
			if (mappings[i].getSequence() == null
					|| mappings[i].getSequence().getDNA() == null
					|| mappings[i].getSequence().getQuality() == null
					|| mappings[i].getSegments() == null)
				return false;

			if (mappings[i].getContigStart() < cstart)
				cstart = mappings[i].getContigStart();

			if (mappings[i].getContigFinish() > cfinal)
				cfinal = mappings[i].getContigFinish();
		}

		int truecontiglength = 1 + cfinal - cstart;

		byte[] sequence = new byte[truecontiglength];
		byte[] quality = new byte[truecontiglength];

		for (cpos = cstart, rdleft = 0, oldrdleft = 0, rdright = -1, oldrdright = -1; cpos <= cfinal; cpos++) {
			while ((rdleft < nreads)
					&& (mappings[rdleft].getContigFinish() < cpos))
				rdleft++;

			while ((rdright < nreads - 1)
					&& (mappings[rdright + 1].getContigStart() <= cpos))
				rdright++;

			int depth = 1 + rdright - rdleft;

			if (rdleft != oldrdleft || rdright != oldrdright) {
				if (depth > maxdepth) {
					maxdepth = depth;
				}
			}

			if (depth == maxdepth) {
			}

			oldrdleft = rdleft;
			oldrdright = rdright;

			if (debugps != null) {
				debugps.println("CONSENSUS POSITION: " + (1 + cpos - cstart));
			}

			algorithm.reset();

			for (int rdid = rdleft; rdid <= rdright; rdid++) {
				int rpos = mappings[rdid].getReadOffset(cpos);
				Read read = mappings[rdid].getSequence().getRead();

				if (rpos >= 0) {
					char base = mappings[rdid].getBase(rpos);
					int qual = mappings[rdid].getQuality(rpos);

					// if (debugps != null)
					// debugps.println(" MAPPING " + rdid + ", READ " + read_id
					// + " : position=" + rpos +
					// ", base=" + base + ", quality=" + qual);

					if (qual > 0)
						algorithm.addBase(base, qual, read.getStrand(), read
								.getChemistry());
				} else {
					int qual = mappings[rdid].getPadQuality(cpos);

					// if (debugps != null)
					// debugps.println(" MAPPING " + rdid + ", READ " + read_id
					// + " : pad quality=" + qual);

					if (qual > 0)
						algorithm.addBase('*', qual, read.getStrand(), read
								.getChemistry());
				}
			}

			try {
				sequence[cpos - cstart] = (byte) algorithm.getBestBase();
				if (debugps != null)
					debugps.print("RESULT --> " + algorithm.getBestBase());
			} catch (ArrayIndexOutOfBoundsException e) {
				System.err.println("Sequence array overflow: " + cpos
						+ " (base=" + cstart + ")");
			}

			try {
				quality[cpos - cstart] = (byte) algorithm.getBestScore();
				if (debugps != null)
					debugps.println(" [" + algorithm.getBestScore() + "]");
			} catch (ArrayIndexOutOfBoundsException e) {
				System.err.println("Quality array overflow: " + cpos
						+ " (base=" + cstart + ")");
			}
		}

		consensus.setDNA(sequence);
		consensus.setQuality(quality);

		return true;
	}

	private static class Consensus {
		protected byte[] dna = null;
		protected byte[] quality = null;

		public void setDNA(byte[] dna) {
			this.dna = dna;
		}

		public byte[] getDNA() {
			return dna;
		}

		public void setQuality(byte[] quality) {
			this.quality = quality;
		}

		public byte[] getQuality() {
			return quality;
		}
	}

	static class MyListener implements ManagerEventListener {
		private long clock;
		private Runtime runtime = Runtime.getRuntime();

		public void managerUpdate(ManagerEvent event) {
			switch (event.getState()) {
				case ManagerEvent.START:
					System.err.println("START -- " + event.getMessage());
					clock = System.currentTimeMillis();
					break;

				case ManagerEvent.WORKING:
					// System.err.print('.');
					break;

				case ManagerEvent.END:
					// System.err.println();
					clock = System.currentTimeMillis() - clock;
					System.err.println("END   -- " + clock + " ms");
					System.err.println("MEM      FREE=" + runtime.freeMemory()
							/ 1024 + ", TOTAL=" + runtime.totalMemory() / 1024);
					System.err.println();
					break;
			}
		}
	}
}
