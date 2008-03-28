package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.Arcturus;

import java.util.Vector;
import java.util.zip.*;
import java.io.*;
import java.sql.*;

public class CalculateConsensus {
	private final int defaultPaddingMode = Gap4BayesianConsensus.MODE_PAD_IS_N;

	private final int MAX_ALLOWED_PACKET = 8 * 1024 * 1024;

	private final int MAX_NORMAL_READ_LENGTH = 8000;

	private long lasttime;
	private Runtime runtime = Runtime.getRuntime();

	private Consensus consensus = new Consensus();

	private String instance = null;
	private String organism = null;

	private String algname = null;

	private int flags = ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS;

	private ArcturusDatabase adb = null;
	private Connection conn = null;

	private boolean debug = false;
	private boolean lowmem = false;
	private boolean quiet = false;
	private boolean allcontigs = false;

	private int mode = defaultPaddingMode;

	private String projectname = null;

	private ConsensusAlgorithm algorithm = null;

	private PreparedStatement insertStmt = null;
	private PreparedStatement updateStmt = null;

	private Deflater compresser = new Deflater(Deflater.BEST_COMPRESSION);

	private String consensustable = null;

	private int maxNormalReadLength = MAX_NORMAL_READ_LENGTH;

	public static void main(String args[]) {
		CalculateConsensus cc = new CalculateConsensus();
		cc.execute(args);
		System.exit(0);
	}

	public void execute(String args[]) {
		lasttime = System.currentTimeMillis();

		System.err.println("CalculateConsensus");
		System.err.println("==================");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-algorithm"))
				algname = args[++i];

			if (args[i].equalsIgnoreCase("-consensustable"))
				consensustable = args[++i];

			if (args[i].equalsIgnoreCase("-debug"))
				debug = true;

			if (args[i].equalsIgnoreCase("-lowmem"))
				lowmem = true;

			if (args[i].equalsIgnoreCase("-quiet"))
				quiet = true;

			if (args[i].equalsIgnoreCase("-allcontigs"))
				allcontigs = true;

			if (args[i].equalsIgnoreCase("-project"))
				projectname = args[++i];

			if (args[i].equalsIgnoreCase("-pad_is_n"))
				mode = Gap4BayesianConsensus.MODE_PAD_IS_N;

			if (args[i].equalsIgnoreCase("-pad_is_star"))
				mode = Gap4BayesianConsensus.MODE_PAD_IS_STAR;

			if (args[i].equalsIgnoreCase("-no_pad"))
				mode = Gap4BayesianConsensus.MODE_NO_PAD;

			if (args[i].equalsIgnoreCase("-maxnormalreadlength"))
				maxNormalReadLength = Integer.parseInt(args[++i]);
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		if (consensustable == null)
			consensustable = "CONSENSUS";

		if (algname == null)
			algname = Arcturus.getProperty("arcturus.default.algorithm");

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			adb = ai.findArcturusDatabase(organism);

			Project project = (projectname == null) ? null : adb
					.getProjectByName(null, projectname);

			if (lowmem)
				adb.getSequenceManager().setCacheing(false);

			conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			if (!quiet)
				adb.addContigManagerEventListener(new MyListener());

			Class algclass = Class.forName(algname);
			algorithm = (ConsensusAlgorithm) algclass.newInstance();

			if (algorithm instanceof Gap4BayesianConsensus) {
				Gap4BayesianConsensus g4bc = (Gap4BayesianConsensus) algorithm;

				if (debug)
					g4bc.setDebugPrintStream(System.out);

				g4bc.setMode(mode);
			}

			int nContigs = 0;

			Statement stmt = conn.createStatement();

			String query = "set session max_allowed_packet = "
					+ MAX_ALLOWED_PACKET;

			try {
				int rc = stmt.executeUpdate(query);
			} catch (SQLException sqle) {
				Arcturus.logWarning("Failed to increase max_allowed_packet to "
						+ MAX_ALLOWED_PACKET, sqle);
			}

			insertStmt = conn.prepareStatement("insert into " + consensustable
					+ " (contig_id,sequence,length,quality)"
					+ " VALUES(?,?,?,?)");

			updateStmt = conn.prepareStatement("update " + consensustable
					+ " set sequence=?,length=?,quality=? where contig_id=?");

			query = allcontigs ? "select CONTIG.contig_id,length(sequence) from CONTIG left join "
					+ consensustable + " using(contig_id)"
					: "select CONTIG.contig_id from CONTIG left join "
							+ consensustable
							+ " using(contig_id) where sequence is null";

			if (project != null)
				query += (allcontigs ? " where" : " and") + " project_id = "
						+ project.getID();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int contig_id = rs.getInt(1);

				boolean doUpdate = false;

				if (allcontigs) {
					rs.getInt(2);
					doUpdate = !rs.wasNull();
				}

				calculateConsensusForContig(contig_id, doUpdate);
				nContigs++;
			}

			System.err.println(nContigs + " contigs were processed");
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}

	public void calculateConsensusForContig(int contig_id, boolean doUpdate)
			throws SQLException, DataFormatException {
		long clockStart = System.currentTimeMillis();

		Contig contig = adb.getContigByID(contig_id, flags);

		PrintStream debugps = debug ? System.out : null;

		if (calculateConsensus(contig, algorithm, consensus, debugps)) {
			long usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1024;
			long clockStop = System.currentTimeMillis() - clockStart;
			System.err.print("CONTIG " + contig_id + ": " + contig.getLength()
					+ " bp, " + contig.getReadCount() + " reads, " + clockStop
					+ " ms, " + usedMemory + " kb");
			storeConsensus(contig_id, consensus, doUpdate);
			System.err.println(doUpdate ? "    UPDATED" : "    STORED");
		} else
			System.err.println("Data missing, operation abandoned");

		if (lowmem)
			contig.setMappings(null);
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
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-algorithm\tName of class for consensus algorithm");
		ps.println("\t-consensustable\tName of consensus table");
		ps.println("\t-project\tName of project for contigs");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-lowmem", "-quiet", "-allcontigs" };

		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);

		ps.println();
		ps.print("PADDING MODES");

		ps.print(" (default mode is ");
		switch (defaultPaddingMode) {
			case Gap4BayesianConsensus.MODE_PAD_IS_N:
				ps.print("-pad_is_n");
				break;

			case Gap4BayesianConsensus.MODE_PAD_IS_STAR:
				ps.print("-pad_is_star");
				break;

			case Gap4BayesianConsensus.MODE_NO_PAD:
				ps.print("-no_pad");
				break;

			default:
				ps.print("unknown");
				break;
		}
		ps.println(")");

		String[] padmodes = { "-pad_is_n", "-pad_is_star", "-no_pad" };

		for (int i = 0; i < padmodes.length; i++)
			ps.println("\t" + padmodes[i]);

	}

	public boolean calculateConsensus(Contig contig,
			ConsensusAlgorithm algorithm, Consensus consensus,
			PrintStream debugps) {
		if (contig == null || contig.getMappings() == null)
			return false;

		Mapping[] mappings = contig.getMappings();
		int cpos, rdleft, rdright, oldrdleft, oldrdright;

		int cstart = mappings[0].getContigStart();
		int cfinal = mappings[0].getContigFinish();

		Vector<Mapping> normalReads = new Vector<Mapping>();
		Vector<Mapping> longReads = new Vector<Mapping>();

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

			Read read = mappings[i].getSequence().getRead();

			if (read == null)
				Arcturus.logWarning("Read was null for sequence "
						+ mappings[i].getSequence() + " in database "
						+ adb.getName(), new Throwable("Read object was null"));

			if (mappings[i].getSequence().getLength() > maxNormalReadLength)
				longReads.add(mappings[i]);
			else
				normalReads.add(mappings[i]);
		}

		System.err.println("Of " + mappings.length + " mappings, "
				+ normalReads.size() + " are of normal  length and "
				+ longReads.size() + " are oversize");

		mappings = normalReads.toArray(new Mapping[0]);

		int truecontiglength = 1 + cfinal - cstart;

		byte[] sequence = new byte[truecontiglength];
		byte[] quality = new byte[truecontiglength];

		int maxdepth = -1;

		int nreads = mappings.length;

		for (cpos = cstart, rdleft = 0, oldrdleft = 0, rdright = -1, oldrdright = -1; cpos <= cfinal; cpos++) {
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

			if (debugps != null) {
				debugps.println("CONSENSUS POSITION: " + (1 + cpos - cstart));
			}

			algorithm.reset();

			// Process the normal reads
			for (int rdid = rdleft; rdid <= rdright; rdid++)
				processMapping(mappings[rdid], cpos);

			// Process the oversize (consensus) reads
			for (Mapping mapping : longReads)
				processMapping(mapping, cpos);

			if (cpos % 1000 == 0)
				System.err.println("Base " + cpos + " done");

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

	private void processMapping(Mapping mapping, int cpos) {
		int rpos = mapping.getReadOffset(cpos);

		int qual = (rpos >= 0) ? mapping.getQuality(rpos) : mapping
				.getPadQuality(cpos);

		if (qual <= 0)
			return;

		Read read = mapping.getSequence().getRead();

		// In the Gap4 consensus algorithm, "strand" refers to the
		// read-to-contig
		// alignment direction, not the physical strand from which the
		// read has
		// been sequenced.
		int strand = mapping.isForward() ? Read.FORWARD : Read.REVERSE;

		int chemistry = read == null ? Read.UNKNOWN : read.getChemistry();

		char base = (rpos >= 0) ? mapping.getBase(rpos) : '*';

		algorithm.addBase(base, qual, strand, chemistry);
	}

	public void storeConsensus(int contig_id, Consensus consensus,
			boolean doUpdate) throws SQLException {
		byte[] sequence = consensus.getDNA();
		byte[] quality = consensus.getQuality();

		int seqlen = sequence.length;

		byte[] buffer = new byte[12 + (5 * seqlen) / 4];

		compresser.reset();
		compresser.setInput(sequence);
		compresser.finish();
		int compressedSequenceLength = compresser.deflate(buffer);
		byte[] compressedSequence = new byte[compressedSequenceLength];
		for (int i = 0; i < compressedSequenceLength; i++)
			compressedSequence[i] = buffer[i];

		compresser.reset();
		compresser.setInput(quality);
		compresser.finish();
		int compressedQualityLength = compresser.deflate(buffer);
		byte[] compressedQuality = new byte[compressedQualityLength];
		for (int i = 0; i < compressedQualityLength; i++)
			compressedQuality[i] = buffer[i];

		if (doUpdate) {
			updateStmt.setInt(4, contig_id);
			updateStmt.setBytes(1, compressedSequence);
			updateStmt.setInt(2, seqlen);
			updateStmt.setBytes(3, compressedQuality);
			updateStmt.executeUpdate();
		} else {
			insertStmt.setInt(1, contig_id);
			insertStmt.setBytes(2, compressedSequence);
			insertStmt.setInt(3, seqlen);
			insertStmt.setBytes(4, compressedQuality);
			insertStmt.executeUpdate();
		}
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
