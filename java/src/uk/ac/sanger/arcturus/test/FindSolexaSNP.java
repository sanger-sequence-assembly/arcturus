package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus;
import uk.ac.sanger.arcturus.Arcturus;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Vector;
import java.util.zip.*;
import java.io.*;
import java.sql.*;

public class FindSolexaSNP {
	private final int MAX_ALLOWED_PACKET = 8 * 1024 * 1024;

	private long lasttime;
	private Runtime runtime = Runtime.getRuntime();

	private String instance = null;
	private String organism = null;

	private int flags = ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS
			| ArcturusDatabase.CONTIG_SEQUENCE_AUXILIARY_DATA;

	private ArcturusDatabase adb = null;
	private Connection conn = null;

	private boolean debug = false;
	private boolean lowmem = false;

	private PrintStream debugps = null;

	private String projectname = null;

	private final static int CONSENSUS_READ_MISMATCH = 1;
	private final static int LOW_QUALITY_PADDING = 2;

	private int mode = CONSENSUS_READ_MISMATCH;

	private String tagType;
	private String tagComment;

	private int tag_id = -1;
	private PreparedStatement pstmtCreateTag2Contig;

	private Gap4BayesianConsensus consensus = new Gap4BayesianConsensus();
	private Gap4BayesianConsensus consensus2 = new Gap4BayesianConsensus();

	public static void main(String args[]) {
		FindSolexaSNP finder = new FindSolexaSNP();
		finder.execute(args);
		System.exit(0);
	}

	public void execute(String args[]) {
		lasttime = System.currentTimeMillis();

		System.err.println("FindSolexaSNP");
		System.err.println("=============");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-debug"))
				debug = true;

			if (args[i].equalsIgnoreCase("-lowmem"))
				lowmem = true;

			if (args[i].equalsIgnoreCase("-project"))
				projectname = args[++i];

			if (args[i].equalsIgnoreCase("-crm"))
				mode = CONSENSUS_READ_MISMATCH;

			if (args[i].equalsIgnoreCase("-lqp"))
				mode = LOW_QUALITY_PADDING;

			if (args[i].equalsIgnoreCase("-tagtype"))
				tagType = args[++i];

			if (args[i].equalsIgnoreCase("-tagcomment"))
				tagComment = args[++i];
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			report(System.err);

			if (tagType != null && tagComment == null) {
				DateFormat formatter = new SimpleDateFormat("yyyy MMM dd HH:mm");
				java.util.Date now = new java.util.Date();
				tagComment = "Discrepancy tagged at " + formatter.format(now);
			}

			consensus.setMode(Gap4BayesianConsensus.MODE_PAD_IS_STAR);
			consensus2.setMode(Gap4BayesianConsensus.MODE_PAD_IS_STAR);

			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			adb = ai.findArcturusDatabase(organism);

			Project project = (projectname == null) ? null : adb
					.getProjectByName(null, projectname);

			if (lowmem)
				adb.setCacheing(ArcturusDatabase.SEQUENCE, false);

			conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			int nContigs = 0;

			Statement stmt = conn.createStatement();

			String query = "set session max_allowed_packet = "
					+ MAX_ALLOWED_PACKET;

			try {
				stmt.executeUpdate(query);
			} catch (SQLException sqle) {
				Arcturus.logWarning("Failed to increase max_allowed_packet to "
						+ MAX_ALLOWED_PACKET, sqle);
			}
			
			if (tagType != null) {
				query = "insert into TAG2CONTIG(contig_id, tag_id, cstart, cfinal) values(?,?,?,?)";
				pstmtCreateTag2Contig = conn.prepareStatement(query);
			}

			debugps = debug ? System.out : null;

			query = "select contig_id from CURRENTCONTIGS";

			if (project != null)
				query += " where project_id = " + project.getID();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int contig_id = rs.getInt(1);

				analyseContig(contig_id);
				nContigs++;
			}

			System.err.println(nContigs + " contigs were processed");

			report(System.err);
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}

	public void analyseContig(int contig_id) throws SQLException,
			DataFormatException {
		Contig contig = adb.getContigByID(contig_id, flags);

		analyseContig(contig);

		if (lowmem)
			contig.setMappings(null);
	}

	public void report(PrintStream ps) {
		long timenow = System.currentTimeMillis();

		ps.println("******************** REPORT ********************");
		ps.println("Time: " + (timenow - lasttime) + " ms");

		ps.println("Memory (kb): (free/total) " + runtime.freeMemory() / 1024
				+ "/" + runtime.totalMemory() / 1024);
		ps.println("************************************************");
		ps.println();
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-project\tName of project for contigs");
		ps.println("\t-tagtype\tGap4 tag type for discrepancies");
		ps.println("\t-tagcomment\tGap4 tag comment for discrepancies");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-lowmem", "-crm", "-lqp" };

		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);
	}

	public boolean analyseContig(Contig contig) {
		if (contig == null || contig.getMappings() == null)
			return false;

		int contig_id = contig.getID();

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
		}

		int maxdepth = -1;

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

			Vector<Base> bases = new Vector<Base>();

			for (int rdid = rdleft; rdid <= rdright; rdid++) {
				int rpos = mappings[rdid].getReadOffset(cpos);

				int qual = rpos >= 0 ? mappings[rdid].getQuality(rpos)
						: mappings[rdid].getPadQuality(cpos);
				char base = rpos >= 0 ? mappings[rdid].getBase(rpos) : '*';

				if (qual > 0) {
					Sequence sequence = mappings[rdid].getSequence();
					int seq_id = sequence.getID();
					Read read = mappings[rdid].getSequence().getRead();
					Template template = read.getTemplate();
					Ligation ligation = template == null ? null : template
							.getLigation();
					int ligation_id = ligation == null ? 0 : ligation.getID();

					char strand = mappings[rdid].isForward() ? 'F' : 'R';

					int chemistry = read == null ? Read.UNKNOWN : read
							.getChemistry();

					Clipping qclip = sequence.getQualityClipping();

					boolean clipOK = qclip != null && rpos >= 0
							&& rpos > qclip.getLeft()
							&& rpos < qclip.getRight();

					Base b = new Base(read, seq_id, rpos, clipOK,
							ligation_id, strand, chemistry, base, qual);

					bases.add(b);
				}
			}

			switch (mode) {
				case CONSENSUS_READ_MISMATCH:
					if (findConsensusReadMismatch(contig_id, cpos, bases)
							&& tagType != null)
						addContigTag(contig_id, cpos);
					break;

				case LOW_QUALITY_PADDING:
					findLowQualityPadding(contig_id, cpos, bases);
					break;

				default:
					System.err.println("Unknown mode!");
					System.exit(1);
			}
		}

		return true;
	}

	private void addContigTag(int contig_id, int cpos) {
		try {
			if (tag_id < 0)
				createContigTag();
			
			pstmtCreateTag2Contig.setInt(1, contig_id);
			pstmtCreateTag2Contig.setInt(2, tag_id);
			pstmtCreateTag2Contig.setInt(3, cpos);
			pstmtCreateTag2Contig.setInt(4, cpos);
			
			pstmtCreateTag2Contig.executeUpdate();
		} catch (SQLException e) {
			Arcturus.logSevere("An error occurred when adding a contig tag", e);
		}
	}

	private void createContigTag() throws SQLException {
		if (tagType == null)
			return;

		String query = "insert into CONTIGTAG(tagtype, tagcomment) values (?,?)";
		
		PreparedStatement pstmtCreateContigTag = conn.prepareStatement(query,
				Statement.RETURN_GENERATED_KEYS);
		
		pstmtCreateContigTag.setString(1, tagType);
		pstmtCreateContigTag.setString(2, tagComment);
		
		int rc = pstmtCreateContigTag.executeUpdate();

		if (rc == 1) {
			ResultSet rs = pstmtCreateContigTag.getGeneratedKeys();
			tag_id = rs.next() ? rs.getInt(1) : -1;
			rs.close();
		} else {
			Arcturus
					.logSevere("Failed to create a CONTIGTAG entry.  Cannot create contig tags.");
			tagType = null;
		}

		pstmtCreateContigTag.close();
	}

	private final String TAB = "\t";
	private final String PREFIX_A = "A ";
	private final String PREFIX_B = "B ";
	private final String EMPTY_STRING = "";

	private boolean findConsensusReadMismatch(int contig_id, int cpos,
			Vector<Base> bases) {
		if (bases == null || bases.isEmpty())
			return false;

		int depth = bases.size();

		consensus.reset();
		consensus2.reset();

		for (Base base : bases) {
			if (base.quality > 0) {
				consensus.addBase(base.base, base.quality, base.strand,
						base.chemistry);

				if (base.ligation_id != 0)
					consensus2.addBase(base.base, base.quality, base.strand,
							base.chemistry);
			}
		}

		int score = consensus.getBestScore();
		char bestbase = consensus.getBestBase();

		int score2 = consensus2.getBestScore();
		char bestbase2 = consensus2.getBestBase();
		int count2 = consensus2.getReadCount();

		if (consensus.getReadCount() == 0)
			return false;

		boolean result = false;

		for (Base base : bases) {
			if (base.ligation_id == 0 && base.base != bestbase) {
				System.out.println(PREFIX_A + contig_id + TAB + cpos + TAB
						+ depth + TAB + bestbase + TAB + score + TAB
						+ base.read.getID() + TAB + base.read.getName() + TAB
						+ base.sequence_id + TAB
						+ base.read_position + TAB + base.clipOK + TAB
						+ base.base + TAB + base.quality);

				result = true;
			} else if (count2 > 0 && base.ligation_id == 0
					&& base.base != bestbase2) {
				System.out.println(PREFIX_B + contig_id + TAB + cpos + TAB
						+ count2 + TAB + bestbase2 + TAB + score2 + TAB
						+ base.read.getID() + TAB + base.read.getName() + TAB
						+ base.sequence_id + TAB
						+ base.read_position + TAB + base.clipOK + TAB
						+ base.base + TAB + base.quality);

				result = true;
			}
		}

		return result;
	}

	private void findLowQualityPadding(int contig_id, int cpos,
			Vector<Base> bases) {
		if (bases == null || bases.isEmpty())
			return;

		int depth = bases.size();

		consensus.reset();

		for (Base base : bases) {
			if (base.quality > 0)
				consensus.addBase(base.base, base.quality, base.strand,
						base.chemistry);
		}

		int score = consensus.getBestScore();
		char bestbase = consensus.getBestBase();

		if (bestbase != '*')
			return;

		for (Base base : bases) {
			if (base.base != bestbase)
				System.out.println(EMPTY_STRING + contig_id + TAB + cpos + TAB
						+ depth + TAB + bestbase + TAB + score + TAB
						+ base.read.getID() + TAB + base.read.getName() + TAB
						+ base.sequence_id + TAB
						+ base.read_position + TAB + base.clipOK + TAB
						+ base.base + TAB + base.quality);
		}
	}

	class Base {
		protected Read read;
		protected int sequence_id;
		protected int read_position;
		protected boolean clipOK;
		protected int ligation_id;
		protected char strand;
		protected int chemistry;
		protected char base;
		protected int quality;

		public Base(Read read, int sequence_id, int read_position,
				boolean clipOK, int ligation_id, char strand, int chemistry,
				char base, int quality) {
			this.read = read;
			this.sequence_id = sequence_id;
			this.read_position = read_position;
			this.clipOK = clipOK;
			this.ligation_id = ligation_id;
			this.strand = strand;
			this.chemistry = chemistry;
			this.base = Character.toUpperCase(base);
			this.quality = quality;
		}
	}
}
