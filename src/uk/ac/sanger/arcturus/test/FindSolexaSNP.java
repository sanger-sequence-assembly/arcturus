package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.Gap4BayesianConsensus;
import uk.ac.sanger.arcturus.Arcturus;

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

	private int flags = ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS;

	private ArcturusDatabase adb = null;
	private Connection conn = null;

	private boolean debug = false;
	private boolean lowmem = false;

	private PrintStream debugps = null;

	private String projectname = null;

	private Gap4BayesianConsensus alg1 = new Gap4BayesianConsensus();
	private Gap4BayesianConsensus alg2 = new Gap4BayesianConsensus();

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
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

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
		ps.println("\t-project\tName of project for contigs");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-lowmem" };

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
				int qual = mappings[rdid].getQuality(rpos);

				if (qual > 0) {
					Sequence sequence = mappings[rdid].getSequence();
					int seq_id = sequence.getID();
					Read read = mappings[rdid].getSequence().getRead();
					int read_id = read.getID();
					Template template = read.getTemplate();
					Ligation ligation = template == null ? null : template
							.getLigation();
					int ligation_id = ligation == null ? 0 : ligation.getID();

					char strand = mappings[rdid].isForward() ? 'F' : 'R';

					int chemistry = read == null ? Read.UNKNOWN : read
							.getChemistry();

					char base = rpos >= 0 ? mappings[rdid].getBase(rpos) : '*';

					Base b = new Base(read_id, seq_id, rpos, ligation_id, strand, chemistry, base, qual);
					
					bases.add(b);
				}
			}
			
			processBases(contig_id, cpos, bases);

		}

		return true;
	}
	
	private void processBases(int contig_id, int cpos, Vector<Base> bases) {
		alg1.reset();
		alg2.reset();
		
		for (Base base : bases) {
			if (base.ligation_id != 0)
				alg1.addBase(base.base, base.quality, base.strand, base.chemistry);
			else
				alg2.addBase(base.base, base.quality, base.strand, base.chemistry);
		}
		
		int score1 = alg1.getBestScore();
		char best1 = alg1.getBestBase();

		int score2 = alg2.getBestScore();
		char best2 = alg2.getBestBase();

		if (score1 > 0 && alg2.getReadCount() > 0 && best1 != best2)
			System.out.println("" + contig_id + TAB + cpos + TAB + best1
					+ TAB + score1 + TAB + best2 + TAB + score2);	
	}

	private final String TAB = "\t";

	class Base {
		protected int read_id;
		protected int sequence_id;
		protected int read_position;
		protected int ligation_id;
		protected char strand;
		protected int chemistry;
		protected char base;
		protected int quality;
		
		public Base(int read_id, int sequence_id, int read_position, int ligation_id, char strand, int chemistry, char base, int quality) {
			this.read_id = read_id;
			this.sequence_id = sequence_id;
			this.read_position = read_position;
			this.ligation_id = ligation_id;
			this.strand = strand;
			this.chemistry = chemistry;
			this.base = base;
			this.quality = quality;
		}
	}
}
