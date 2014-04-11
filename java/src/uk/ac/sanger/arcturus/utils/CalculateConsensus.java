// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.ManagerEvent;
import uk.ac.sanger.arcturus.jdbc.ManagerEventListener;
import uk.ac.sanger.arcturus.Arcturus;

import java.util.Vector;
import java.util.List;
import java.util.zip.*;
import java.io.*;
import java.sql.*;

public class CalculateConsensus {
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
	private boolean progress = false;
	private boolean allcontigs = false;
	private boolean nostore = false;

	private String projectname = null;

	private ConsensusAlgorithm algorithm = null;

	private PreparedStatement stmtStoreConsensus = null;

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
		
		List<Integer> contigList = null;

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

			if (args[i].equalsIgnoreCase("-progress"))
				progress = true;

			if (args[i].equalsIgnoreCase("-allcontigs"))
				allcontigs = true;
			
			if (args[i].equalsIgnoreCase("-nostore"))
				nostore = true;
			
			if (args[i].equalsIgnoreCase("-contigs"))
				contigList = parseContigIDs(args[++i]);

			if (args[i].equalsIgnoreCase("-project"))
				projectname = args[++i];

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

			adb.setCacheing(ArcturusDatabase.READ, false);
			adb.setCacheing(ArcturusDatabase.TEMPLATE, false);
			adb.setCacheing(ArcturusDatabase.SEQUENCE, false);

			conn = adb.getDefaultConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			Class algclass = Class.forName(algname);
			algorithm = (ConsensusAlgorithm) algclass.newInstance();

			int nContigs = 0;

			Statement stmt = conn.createStatement();

			String query = "insert into " + consensustable
				+ " (contig_id,length,sequence,quality)"
				+ " VALUES(?,?,?,?)"
				+ " ON DUPLICATE KEY UPDATE" 
				+ " sequence=VALUES(sequence), quality=VALUES(quality), length=VALUES(length)";
			
			stmtStoreConsensus = conn.prepareStatement(query);

			if (contigList == null) {
				query = allcontigs ? "select CONTIG.contig_id,length(sequence) from CONTIG left join "
						+ consensustable + " using(contig_id)"
						: "select CONTIG.contig_id from CONTIG left join "
							+ consensustable
							+ " using(contig_id) where sequence is null";

				if (project != null)
					query += (allcontigs ? " where" : " and") + " project_id = "
					+ project.getID();

				ResultSet rs = stmt.executeQuery(query);
				
				contigList = new Vector<Integer>();
				
				while (rs.next()) {
					int contig_id = rs.getInt(1);
					
					contigList.add(contig_id);
				}
				
				rs.close();
			}

			for (int contig_id : contigList) {
				calculateConsensusForContig(contig_id);
				nContigs++;
			}

			System.err.println(nContigs + " contigs were processed");
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}

	private List<Integer> parseContigIDs(String string) {
		List<Integer> contigs = new Vector<Integer>();
		
		String[] words = string.split(",");
		
		for (String word: words) {
			try {
				contigs.add(new Integer(word));
			}
			catch (NumberFormatException nfe) {
				System.err.println("Not parsable as an integer: \"" + word + "\"");
			}
		}
		
		return contigs;
	}

	public void calculateConsensusForContig(int contig_id)
			throws ArcturusDatabaseException {
		long clockStart = System.currentTimeMillis();

		Contig contig = adb.getContigByID(contig_id, flags);

		PrintStream debugps = debug ? System.out : null;
		
		System.err.print("CONTIG " + contig_id + ": " + contig.getLength()
				+ " bp, " + contig.getReadCount() + " reads ");

		if (calculateConsensus(contig, algorithm, consensus, debugps)) {
			long usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / 1024;
			long clockStop = System.currentTimeMillis() - clockStart;
			System.err.print(clockStop + " ms, " + usedMemory + " kb");
			if (nostore) {
				System.err.println("    CALCULATED");
			} else {
				storeConsensus(contig_id, consensus);
				System.err.println("    STORED");
			}
		} else
			System.err.println("data missing, operation abandoned");

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
		ps.println("\t-contigs\tComma-separated list of contigs");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-allcontigs", "-nostore" };

		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);
	}

	public boolean calculateConsensus(Contig contig,
			ConsensusAlgorithm algorithm, Consensus consensus,
			PrintStream debugps) {
		if (contig == null || contig.getMappings() == null)
			return false;

		BasicSequenceToContigMapping[] mappings = contig.getMappings();
		int cpos, rdleft, rdright, oldrdleft, oldrdright;

		int cstart = mappings[0].getContigStartPosition();
		int cfinal = mappings[0].getContigEndPosition();

		Vector<BasicSequenceToContigMapping> normalReads = new Vector<BasicSequenceToContigMapping>();
		Vector<BasicSequenceToContigMapping> longReads = new Vector<BasicSequenceToContigMapping>();

		for (int i = 0; i < mappings.length; i++) {
			if (mappings[i].getSequence() == null
					|| mappings[i].getSequence().getDNA() == null
					|| mappings[i].getSequence().getQuality() == null
					|| mappings[i].getSegments() == null)
				return false;

			if (mappings[i].getContigStartPosition() < cstart)
				cstart = mappings[i].getContigStartPosition();

			if (mappings[i].getContigEndPosition() > cfinal)
				cfinal = mappings[i].getContigEndPosition();

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
		
		if (progress)
			System.err.println("\nNormal reads: " + normalReads.size() + ", long read: "
					+ longReads.size());

		mappings = normalReads.toArray(new BasicSequenceToContigMapping[0]);

		int truecontiglength = 1 + cfinal - cstart;

		byte[] sequence = new byte[truecontiglength];
		byte[] quality = new byte[truecontiglength];

		int maxdepth = -1;

		int nreads = mappings.length;
		
		long lasttime = 0L;
		
		if (progress) {
			lasttime = System.currentTimeMillis();
			System.err.println();
		}

		for (cpos = cstart, rdleft = 0, oldrdleft = 0, rdright = -1, oldrdright = -1; cpos <= cfinal; cpos++) {
			while ((rdleft < nreads)
					&& (mappings[rdleft].getContigEndPosition() < cpos))
				rdleft++;

			while ((rdright < nreads - 1)
					&& (mappings[rdright + 1].getContigStartPosition() <= cpos))
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
			for (BasicSequenceToContigMapping mapping : longReads)
				processMapping(mapping, cpos);

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
			
			if (progress && (cpos % 10000 == 0)) {
				long timenow = System.currentTimeMillis();
				System.err.println("" + cpos + "\t" + (timenow - lasttime));
				lasttime = timenow;
			}
		}
		
		consensus.setDNA(sequence);
		consensus.setQuality(quality);

		return true;
	}

	private void processMapping(BasicSequenceToContigMapping mapping, int cpos) {
		int rpos = -1;
		int qual = -1;
		
		try {
			rpos = mapping.getReadOffset(cpos);

			qual = (rpos >= 0) ? mapping.getQuality(rpos) : mapping
					.getPadQuality(cpos);
		} catch (ArrayIndexOutOfBoundsException e) {
			Sequence sequence = mapping.getSequence();
			String readname = sequence.getRead().getName();
			System.err.println("\n*** An inconsistent read-to-contig mapping was encountered when processing\n" 
							+ "*** the mapping to read "
							+ readname
							+ " (sequence ID "
							+ sequence.getID()
							+ ", length "
							+ sequence.getLength()
							+ "bp)\n*** at contig position " + cpos + "\n");
			return;
		}

		if (qual <= 0)
			return;

		Read read = mapping.getSequence().getRead();

		// In the Gap4 consensus algorithm, "strand" refers to the
		// read-to-contig
		// alignment direction, not the physical strand from which the
		// read has
		// been sequenced.
		int strand = mapping.isForward() ? CapillaryRead.FORWARD : CapillaryRead.REVERSE;

		int chemistry = (read == null || !(read instanceof CapillaryRead)) ?
				CapillaryRead.UNKNOWN : ((CapillaryRead)read).getChemistry();

		char base = (rpos >= 0) ? mapping.getBase(rpos) : '*';

		algorithm.addBase(base, qual, strand, chemistry);
	}

	public void storeConsensus(int contig_id, Consensus consensus) throws ArcturusDatabaseException {
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

		try {
			stmtStoreConsensus.setInt(1, contig_id);
			stmtStoreConsensus.setInt(2, seqlen);
			stmtStoreConsensus.setBytes(3, compressedSequence);
			stmtStoreConsensus.setBytes(4, compressedQuality);
			stmtStoreConsensus.executeUpdate();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to set consensus for contig ID=" + contig_id, conn, this);
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
