package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.ReadManager;
import uk.ac.sanger.arcturus.utils.*;
import uk.ac.sanger.arcturus.Arcturus;

import java.util.zip.*;
import java.util.*;
import java.io.*;
import java.sql.*;

public class TestConsensus {
	private String instance = null;
	private String organism = null;

	private String algname = null;

	private boolean quiet = false;

	private int flags = ArcturusDatabase.CONTIG_BASIC_DATA;

	private ArcturusDatabase adb = null;
	private Connection conn = null;

	private ConsensusAlgorithm algorithm = null;

	private PreparedStatement pstmtMappingsByPosition = null;
	private PreparedStatement pstmtSegmentsForMapping = null;

	public static void main(String args[]) {
		TestConsensus tc = new TestConsensus();
		tc.execute(args);
	}

	private void prepareStatements() throws SQLException {
		String query = "select MAPPING.seq_id,cstart,cfinish,direction,mapping_id,readname,strand,chemistry "
				+ " from MAPPING,SEQ2READ,READINFO "
				+ " where contig_id = ? and cstart <= ? and cfinish >= ? "
				+ " and MAPPING.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id "
				+ " order by cstart asc";

		pstmtMappingsByPosition = conn.prepareStatement(query);

		query = "select cstart,rstart,length from SEGMENT where mapping_id = ?";

		pstmtSegmentsForMapping = conn.prepareStatement(query);
	}

	public void execute(String args[]) {
		System.err.println("TestConsensus");
		System.err.println("=============");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-algorithm"))
				algname = args[++i];

			if (args[i].equalsIgnoreCase("-quiet"))
				quiet = true;
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		if (algname == null)
			algname = Arcturus.getProperty("arcturus.default.algorithm");

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			System.err.flush();

			adb = ai.findArcturusDatabase(organism);

			adb.setCacheing(ArcturusDatabase.SEQUENCE, false);

			conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			Class algclass = Class.forName(algname);
			algorithm = (ConsensusAlgorithm) algclass.newInstance();

			if (algorithm instanceof Gap4BayesianConsensus) {
				Gap4BayesianConsensus g4bc = (Gap4BayesianConsensus) algorithm;

				g4bc.setDebugPrintStream(System.out);

				g4bc.setMode(Gap4BayesianConsensus.MODE_PAD_IS_STAR);
			}

			prepareStatements();

			BufferedReader br = new BufferedReader(new InputStreamReader(
					System.in));

			while (true) {
				if (!quiet)
					System.out.print("Contig>");

				String line = br.readLine();

				if (line == null || line.length() == 0)
					break;

				int contig_id = -1;

				try {
					contig_id = Integer.parseInt(line);
				} catch (NumberFormatException nfe) {
					System.err.println("The string \"" + line
							+ "\" did not parse to an integer");
					continue;
				}

				Contig contig = adb.getContigByID(contig_id, flags);

				if (contig == null) {
					System.err.println("No contig exists with that id");
					continue;
				}

				System.out.println("Contig " + contig_id + " : "
						+ contig.getLength() + " bp, " + contig.getReadCount()
						+ " reads, created " + contig.getCreated());

				int contiglen = contig.getLength();

				while (true) {
					if (!quiet)
						System.out.print("  Position>");

					line = br.readLine();

					if (line == null || line.length() == 0)
						break;

					int position = -1;

					try {
						position = Integer.parseInt(line);
					} catch (NumberFormatException nfe) {
						System.err.println("The string \"" + line
								+ "\" did not parse to an integer");
						continue;
					}

					if (position < 1 || position > contiglen) {
						System.err.println("Position " + position
								+ " is outside the valid range (1 to "
								+ contiglen + ")");
						continue;
					}

					calculateConsensus(contig, position);
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	private char[] allbases = { 'A', 'C', 'G', 'T', '*' };

	private void calculateConsensus(Contig contig, int position)
			throws SQLException, DataFormatException {
		System.out.println("Starting consensus calculation for contig "
				+ contig.getID() + " position " + position);

		algorithm.reset();

		pstmtMappingsByPosition.setInt(1, contig.getID());
		pstmtMappingsByPosition.setInt(2, position);
		pstmtMappingsByPosition.setInt(3, position);

		ResultSet rsMappings = pstmtMappingsByPosition.executeQuery();

		while (rsMappings.next()) {
			int seq_id = rsMappings.getInt(1);
			int cstart = rsMappings.getInt(2);
			int cfinish = rsMappings.getInt(3);
			boolean direction = rsMappings.getString(4).equalsIgnoreCase(
					"Forward");
			int mapping_id = rsMappings.getInt(5);
			String readname = rsMappings.getString(6);
			String str_strand = rsMappings.getString(7);
			int strand = ReadManager.parseStrand(str_strand);
			String str_chemistry = rsMappings.getString(8);
			int chemistry = ReadManager.parseChemistry(str_chemistry);

			if (!quiet) {
				System.out.println("Read: " + readname);
				System.out.println("  seq_id = " + seq_id);
				System.out.println("  mapping = " + cstart + " - " + cfinish
						+ " " + (direction ? "F" : "R") + " (mapping "
						+ mapping_id + ")");
				System.out.println("  strand = " + str_strand + " (" + strand
						+ ")");
				System.out.println("  chemistry = " + str_chemistry + " ("
						+ chemistry + ")");
			}
			char cStrand = '?';

			// In the Gap4 consensus algorithm, "strand" refers to the read-to-contig
			// alignment direction, not the physical strand from which the read has
			// been sequenced.
			strand = direction ? Read.FORWARD : Read.REVERSE;
			
			switch (strand) {
				case Read.FORWARD:
					cStrand = 'F';
					break;

				case Read.REVERSE:
					cStrand = 'R';
					break;
			}

			char cChemistry = '?';

			switch (chemistry) {
				case Read.DYE_PRIMER:
					cChemistry = 'P';
					break;

				case Read.DYE_TERMINATOR:
					cChemistry = 'T';
					break;
			}

			Sequence sequence = adb.getFullSequenceBySequenceID(seq_id);

			Segment[] segments = getSegments(mapping_id);

			Mapping mapping = new Mapping(sequence, cstart, cfinish, direction,
					segments);

			int rpos = mapping.getReadOffset(position);

			if (rpos >= 0) {
				char base = mapping.getBase(rpos);
				int qual = mapping.getQuality(rpos);

				System.out.println("  base = " + base + " " + qual + " "
						+ cStrand + " " + cChemistry);

				if (qual > 0)
					algorithm.addBase(base, qual, strand, chemistry);
			} else {
				int qual = mapping.getPadQuality(position);

				System.out.println("  base = * " + qual + " " + cStrand + " "
						+ cChemistry);

				if (qual > 0)
					algorithm.addBase('*', qual, strand, chemistry);
			}

			System.out.println();
		}

		char bestbase = algorithm.getBestBase();
		int bestscore = algorithm.getBestScore();

		System.out.println("BEST BASE = " + bestbase + "(" + bestscore + ")");

		System.out.println();

		for (int i = 0; i < allbases.length; i++)
			System.out.println("Score for " + allbases[i] + " is "
					+ algorithm.getScoreForBase(allbases[i]));

		System.out.println();
	}

	private final Segment[] emptySegmentArray = new Segment[0];

	private Segment[] getSegments(int mapping_id) throws SQLException {
		pstmtSegmentsForMapping.setInt(1, mapping_id);

		ResultSet rsSegments = pstmtSegmentsForMapping.executeQuery();

		Vector vSegs = new Vector();

		while (rsSegments.next()) {
			int cstart = rsSegments.getInt(1);
			int rstart = rsSegments.getInt(2);
			int length = rsSegments.getInt(3);

			vSegs.add(new Segment(cstart, rstart, length));
		}

		return (Segment[]) vSegs.toArray(emptySegmentArray);
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-algorithm\tName of class for consensus algorithm");
	}
}
