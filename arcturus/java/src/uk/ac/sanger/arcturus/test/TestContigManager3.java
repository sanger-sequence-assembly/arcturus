package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;

import java.util.*;
import java.io.*;

public class TestContigManager3 {
	private static long lasttime;
	private static Runtime runtime = Runtime.getRuntime();

	private static Consensus consensus = new Consensus();

	public static void main(String args[]) {
		lasttime = System.currentTimeMillis();

		System.err.println("TestContigManager3");
		System.err.println("==================");
		System.err.println();

		String instance = null;
		String organism = null;

		String url = null;
		String username = null;
		String password = null;

		String algname = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-url"))
				url = args[++i];

			if (args[i].equalsIgnoreCase("-username"))
				username = args[++i];

			if (args[i].equalsIgnoreCase("-password"))
				password = args[++i];

			if (args[i].equalsIgnoreCase("-algorithm"))
				algname = args[++i];
		}

		if (instance == null && organism == null && url == null
				&& username == null && password == null) {
			printUsage(System.err);
			System.exit(1);
		}

		if (algname == null)
			algname = System.getProperty("arcturus.default.algorithm");

		try {
			java.sql.Connection conn = null;

			if (instance != null && organism != null) {
				System.err.println("Creating an ArcturusInstance for "
						+ instance);
				System.err.println();

				ArcturusInstance ai = ArcturusInstance.getInstance(instance);

				System.err.println("Creating an ArcturusDatabase for "
						+ organism);
				System.err.println();

				ArcturusDatabase adb = ai.findArcturusDatabase(organism);

				conn = adb.getConnection();
			} else if (url != null && username != null && password != null) {
				Class.forName("com.mysql.jdbc.Driver").newInstance();

				conn = java.sql.DriverManager.getConnection(url, username,
						password);
			}

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			Manager manager = new Manager(conn);

			boolean quiet = Boolean.getBoolean("quiet");
			boolean silent = Boolean.getBoolean("silent");

			if (!quiet)
				manager.addManagerEventListener(new MyListener());

			BufferedReader stdin = new BufferedReader(new InputStreamReader(
					System.in));

			Class algclass = Class.forName(algname);
			ConsensusAlgorithm algorithm = (ConsensusAlgorithm) algclass
					.newInstance();

			String line = null;
			Contig contig = null;
			CAFWriter cafWriter = new CAFWriter(System.out);

			int sequenceCounter = 0;
			while (true) {
				if (!quiet)
					System.err.print(">");

				line = stdin.readLine();

				if (line == null)
					System.exit(0);

				String[] words = tokenise(line);

				for (int i = 0; i < words.length; i++) {
					if (words[i].equalsIgnoreCase("quit")
							|| words[i].equalsIgnoreCase("exit"))
						System.exit(0);

					if (words[i].equalsIgnoreCase("caf")) {
						if (contig != null)
							cafWriter.writeContig(contig);
					} else if (words[i].equalsIgnoreCase("cons")) {
						if (contig != null) {
							System.err.println("Calculate consensus ["
									+ contig.getLength() + " bp]");
							long clockStart = System.currentTimeMillis();

							if (calculateConsensus(contig, algorithm,
									consensus, null)) {
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
					} else {
						manager.clearSequenceMap();

						int contig_id = Integer.parseInt(words[i]);

						long clockStart = System.currentTimeMillis();

						contig = manager.loadContigByID(contig_id);

						if (quiet) {
							if (!silent)
								System.err.println("Contig " + contig_id
										+ " : " + contig.getLength() + " bp, "
										+ contig.getReadCount() + " reads");
						} else {
							long clockStop = System.currentTimeMillis()
									- clockStart;
							System.err.println("TOTAL TIME: " + clockStop
									+ " ms");
							System.err.println();

							if (Boolean.getBoolean("showMemory")) {
								sequenceCounter += manager.getSequenceMapSize();
								long usedMemory = (runtime.totalMemory() - runtime
										.freeMemory()) / 1024;
								System.out.println(sequenceCounter + " "
										+ usedMemory);
							}
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
		ps.println("\t\t --- OR ---");
		ps.println("\t-url\t\tJDBC URL");
		ps.println("\t-username\tUsername");
		ps.println("\t-password\tPassword");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-algorithm\tName of class for consensus algorithm");
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
				debugps.print("CONSENSUS POSITION: " + (1 + cpos - cstart));
			}

			algorithm.reset();

			for (int rdid = rdleft; rdid <= rdright; rdid++) {
				int rpos = mappings[rdid].getReadOffset(cpos);
				if (rpos >= 0) {
					char base = mappings[rdid].getBase(rpos);
					int qual = mappings[rdid].getQuality(rpos);

					if (qual > 0)
						algorithm.addBase(base, qual, mappings[rdid]
								.getSequence().getRead().getStrand(),
								mappings[rdid].getSequence().getRead()
										.getChemistry());
				} else {
					int qual = mappings[rdid].getPadQuality(cpos);
					if (qual > 0)
						algorithm.addBase('*', qual, mappings[rdid]
								.getSequence().getRead().getStrand(),
								mappings[rdid].getSequence().getRead()
										.getChemistry());
				}
			}

			try {
				sequence[cpos - cstart] = (byte) algorithm.getBestBase();
				if (debugps != null)
					debugps.print(" --> " + algorithm.getBestBase());
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
