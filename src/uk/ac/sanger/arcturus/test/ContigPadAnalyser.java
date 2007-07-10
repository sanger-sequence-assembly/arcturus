package uk.ac.sanger.arcturus.test;

import java.io.FileOutputStream;
import java.io.PrintStream;
import java.sql.*;
import java.util.zip.DataFormatException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ContigPadAnalyser {
	protected ArcturusDatabase adb;

	public ContigPadAnalyser(ArcturusDatabase adb) {
		this.adb = adb;
	}

	public void analyseContig(int contig_id, int thresh, PrintStream ps)
			throws SQLException, DataFormatException {
		int flags = ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS
				| ArcturusDatabase.CONTIG_CONSENSUS;

		Contig contig = adb.getContigByID(contig_id, flags);

		byte[] dna = contig.getDNA();
		byte[] quality = contig.getQuality();

		Mapping[] mappings = contig.getMappings();

		int nreads = mappings.length;

		int maxdepth = -1;

		int cpos, rdleft, rdright, oldrdleft, oldrdright;

		int cstart = mappings[0].getContigStart();
		int cfinal = mappings[0].getContigFinish();

		for (int i = 0; i < mappings.length; i++) {
			if (mappings[i].getContigStart() < cstart)
				cstart = mappings[i].getContigStart();

			if (mappings[i].getContigFinish() > cfinal)
				cfinal = mappings[i].getContigFinish();
		}

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

			if (dna[cpos - 1] == 'N') {
				analysePad(cpos, mappings, rdleft, rdright, thresh, ps);
			}
		}
	}

	private void analysePad(int cpos, Mapping[] mappings, int rdleft,
			int rdright, int thresh, PrintStream ps) {
		for (int rdid = rdleft; rdid <= rdright; rdid++) {
			int rpos = mappings[rdid].getReadOffset(cpos);

			if (rpos >= 0) {
				char base = mappings[rdid].getBase(rpos);
				int qual = mappings[rdid].getQuality(rpos);
				int seqid = mappings[rdid].getSequence().getID();
				
				byte[] quality = mappings[rdid].getSequence().getQuality();
				
				int[] qclip = calculateClipping(quality, thresh);

				int qleft = qclip[0];
				int qright = qclip[1];

				ps.println(cpos + " " + seqid + " " + rpos + " " + base + " "
						+ qual + " " + qleft + " " + qright
						+ (rpos <= qleft || rpos >= qright ? " *" : ""));
			}
		}

	}
	
	private int[] calculateClipping(byte[] quality, int thresh) {
		int[] q = new int[quality.length];

		int N = q.length;

		for (int i = 0; i < N; i++)
			q[i] = (int) quality[i] - thresh;

		int Left = 0;

		int[] cleft = new int[N];
		cleft[0] = q[0] > 0 ? q[0] : 0;

		int[] l = new int[N];
		l[0] = Left;

		for (int i = 1; i < N; i++) {
			cleft[i] = cleft[i - 1] + q[i];

			if (cleft[i] <= 0) {
				cleft[i] = 0;
				Left = i;
			}

			l[i] = Left;
		}

		int Right = N - 1;

		int[] cright = new int[N];
		cright[N - 1] = q[N - 1] > 0 ? q[N - 1] : 0;

		int[] r = new int[N];
		r[N - 1] = Right;

		for (int i = N - 2; i >= 0; i--) {
			cright[i] = cright[i + 1] + q[i];

			if (cright[i] <= 0) {
				cright[i] = 0;
				Right = i;
			}

			r[i] = Right;
		}

		int best = 0;
		int coord = 0;

		for (int i = 0; i < N; i++) {
			int s = cright[i] + cleft[i];

			if (best < s) {
				best = s;
				coord = i;
			}
		}

		int[] qclip = new int[2];

		qclip[0] = l[coord] + 1;
		qclip[1] = r[coord] + 1;

		return qclip;
	}

	public static void main(String[] args) {
		try {
			String instance = null;
			String organism = null;
			int contig_id = -1;
			int thresh = 20;

			for (int i = 0; i < args.length; i++) {
				if (args[i].equalsIgnoreCase("-instance"))
					instance = args[++i];

				if (args[i].equalsIgnoreCase("-organism"))
					organism = args[++i];

				if (args[i].equalsIgnoreCase("-contig"))
					contig_id = Integer.parseInt(args[++i]);

				if (args[i].equalsIgnoreCase("-thresh"))
					thresh = Integer.parseInt(args[++i]);
			}

			if (instance == null || organism == null || contig_id < 0) {
				showUsage(System.err);
				System.exit(1);
			}

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);
			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			ContigPadAnalyser cpa = new ContigPadAnalyser(adb);

			PrintStream ps = new PrintStream(new FileOutputStream(
					"/tmp/cpa.out"));

			cpa.analyseContig(contig_id, thresh, ps);

			ps.close();
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

		Runtime runtime = Runtime.getRuntime();

		long totalmem = runtime.totalMemory();
		long freemem = runtime.freeMemory();
		long usedmem = totalmem - freemem;

		System.err
				.println("Memory usage: " + (totalmem / 1024) + "kb total, "
						+ (freemem / 1024) + "kb free, " + (usedmem / 1024)
						+ "kb used");

		System.exit(0);
	}

	protected static void showUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-contig\t\tID of contig to be analysed");
	}

}
