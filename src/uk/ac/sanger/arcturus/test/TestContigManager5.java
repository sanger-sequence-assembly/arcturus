package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;

import java.io.*;

public class TestContigManager5 implements ContigProcessor {
	private long lasttime;
	private Runtime runtime = Runtime.getRuntime();

	private Consensus consensus = new Consensus();

	private String instance = null;
	private String organism = null;

	private String algname = null;

	private int flags = ArcturusDatabase.CONTIG_BASIC_DATA;

	private boolean debug = false;
	private boolean lowmem = false;
	private boolean quiet = false;

	private String assemblyname = null;
	private String projectname = null;

	private boolean doConsensus = false;

	private PrintStream psCAF = null;

	private CAFWriter cafWriter = null;
	private ConsensusAlgorithm algorithm = null;

	private int minlen = 0;

	public static void main(String args[]) {
		TestContigManager5 tcm = new TestContigManager5();
		tcm.execute(args);
	}

	public void execute(String args[]) {
		lasttime = System.currentTimeMillis();

		System.err.println("TestContigManager5");
		System.err.println("==================");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-algorithm"))
				algname = args[++i];

			if (args[i].equalsIgnoreCase("-assembly"))
				assemblyname = args[++i];

			if (args[i].equalsIgnoreCase("-project"))
				projectname = args[++i];

			if (args[i].equalsIgnoreCase("-minlen"))
				minlen = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-debug"))
				debug = true;

			if (args[i].equalsIgnoreCase("-lowmem"))
				lowmem = true;

			if (args[i].equalsIgnoreCase("-silent")) {
			}

			if (args[i].equalsIgnoreCase("-quiet"))
				quiet = true;

			if (args[i].equalsIgnoreCase("-consensus"))
				doConsensus = true;

			if (args[i].equalsIgnoreCase("-caf")) {
				try {
					psCAF = new PrintStream(new FileOutputStream(args[++i]));
				} catch (FileNotFoundException fnfe) {
					psCAF = null;
				}
			}

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

		if (instance == null || organism == null || assemblyname == null
				|| projectname == null) {
			printUsage(System.err);
			System.exit(1);
		}

		if (algname == null)
			algname = System.getProperty("arcturus.default.algorithm");

		if (doConsensus)
			flags |= ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS
					| ArcturusDatabase.CONTIG_CONSENSUS;

		if (psCAF != null)
			flags |= ArcturusDatabase.CONTIG_TO_GENERATE_CAF;

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = Arcturus.getArcturusInstance(instance);

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

			Class algclass = Class.forName(algname);
			algorithm = (ConsensusAlgorithm) algclass.newInstance();

			if (debug
					&& algorithm instanceof uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus)
				((Gap4BayesianConsensus) algorithm)
						.setDebugPrintStream(System.out);

			cafWriter = new CAFWriter(psCAF);

			Assembly assembly = adb.getAssemblyByName(assemblyname);

			if (assembly == null) {
				System.err.println("Assembly \"" + assemblyname
						+ "\" is not known");
				System.exit(1);
			}

			Project project = adb.getProjectByName(assembly, projectname);

			if (project == null) {
				System.err.println("Project \"" + projectname
						+ "\" is not known");
				System.exit(1);
			}

			int processed = adb.processContigsByProject(project.getID(), flags,
					minlen, this);

			System.err.println(processed + " contigs were processed");
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public boolean processContig(Contig contig) {
		System.err.println("Contig " + contig.getID() + " : name="
				+ contig.getName() + ", length=" + contig.getLength()
				+ ", reads=" + contig.getReadCount());

		if (doConsensus) {
			long clockStart = System.currentTimeMillis();

			PrintStream debugps = debug ? System.out : null;

			if (calculateConsensus(contig, algorithm, consensus, debugps)) {
				long usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1024;
				long clockStop = System.currentTimeMillis() - clockStart;
				System.err.println("CONSENSUS: " + clockStop + " ms "
						+ usedMemory + " kb");

				byte[] dna = consensus.getDNA();
				byte[] quality = consensus.getQuality();

				byte[] dna2 = contig.getDNA();
				byte[] quality2 = contig.getQuality();

				if (dna.length != dna2.length
						|| quality.length != quality2.length) {
					System.err.println("Length mismatch: DNA " + dna.length
							+ " vs " + dna2.length + ", quality "
							+ quality.length + " vs " + quality2.length);
				} else {
					for (int k = 0; k < dna.length; k++) {
						if (dna[k] != dna2[k])
							System.err.println("MISMATCH: " + (k + 1) + " --> "
									+ dna[k] + " " + quality[k] + " vs "
									+ dna2[k] + " " + quality2[k]);
					}
				}
			} else
				System.err.println("Data missing, operation abandoned");

		}

		if (psCAF != null) {
			long clockStart = System.currentTimeMillis();
			cafWriter.writeContig(contig);
			long usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1024;
			long clockStop = System.currentTimeMillis() - clockStart;
			System.err.println("CAF: " + clockStop + " ms " + usedMemory
					+ " kb");
		}

		if (lowmem)
			contig.setMappings(null);

		return true;
	}

	public void report() {
		long timenow = System.currentTimeMillis();

		System.out.println("******************** REPORT ********************");
		System.out.println("Time: " + (timenow - lasttime));

		System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()
				/ 1024 + "/" + runtime.totalMemory() / 1024);
		System.out.println("************************************************");
		System.out.println();
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-assembly\tName of assembly");
		ps.println("\t-project\tName of project");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-algorithm\tName of class for consensus algorithm");
		ps.println("\t-consensus\tGenerate and check consensus");
		ps.println("\t-caf\t\tName of output CAF file");
		ps.println("\t-minlen\t\tMinimum contig length");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-lowmem", "-silent", "-quiet",
				"-loadMappings", "-loadSequenceDNA", "-loadContigConsensus",
				"-loadAuxiliaryData", "-loadMappingSegments",
				"-loadContigTags", "-loadForCAF", "-loadToCalculateConsensus" };
		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);
	}

	public boolean calculateConsensus(Contig contig,
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

	private class Consensus {
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

	class MyListener implements ManagerEventListener {
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
