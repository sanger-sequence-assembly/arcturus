package uk.ac.sanger.arcturus.test;

import java.io.PrintStream;
import java.sql.*;
import java.util.zip.*;
import java.text.*;
import java.util.*;
import java.io.*;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

public class GenerateContigHashing {
	private String instance = null;
	private String organism = null;
	private Inflater decompresser = new Inflater();
	private boolean quiet = false;
	private boolean progress = false;
	private int hashsize = 10;
	protected int hashmask;
	protected int allDone = 0;

	protected DecimalFormat df = new DecimalFormat("########");

	private long lasttime;
	private Runtime runtime = Runtime.getRuntime();

	private ArcturusDatabase adb = null;
	private Connection conn = null;

	private HashEntry entries[];
	private HashMap consensus = new HashMap();

	public static void main(String[] args) {
		GenerateContigHashing gch = new GenerateContigHashing();
		gch.execute(args);
	}

	public void execute(String args[]) {
		System.err.println("GenerateContigHashing");
		System.err.println("=====================");
		System.err.println();

		int minlen = -1;
		boolean allContigs = false;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-quiet"))
				quiet = true;

			if (args[i].equalsIgnoreCase("-progress"))
				progress = true;

			if (args[i].equalsIgnoreCase("-hashsize"))
				hashsize = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-minlen"))
				minlen = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-allcontigs"))
				allContigs = true;
		}

		if (minlen < 0)
			minlen = allContigs ? 100000 : 0;

		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
		}

		int entrysize = 1 << (2 * hashsize);

		entries = new HashEntry[entrysize];

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

			System.err.flush();

			adb = ai.findArcturusDatabase(organism);

			adb.setCacheing(ArcturusDatabase.SEQUENCE, false);

			conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			String queryCurrent = "select CONSENSUS.contig_id,length,sequence"
					+ " from CONSENSUS left join C2CMAPPING "
					+ " on CONSENSUS.contig_id = C2CMAPPING.parent_id"
					+ " where C2CMAPPING.parent_id is null and length >= "
					+ minlen;

			String queryAll = "select contig_id,length,sequence"
					+ " from CONSENSUS where length >= " + minlen;

			Statement stmt = conn.createStatement(
					java.sql.ResultSet.TYPE_FORWARD_ONLY,
					java.sql.ResultSet.CONCUR_READ_ONLY);

			ResultSet rs = stmt.executeQuery(allContigs ? queryAll
					: queryCurrent);

			lasttime = System.currentTimeMillis();

			if (!quiet)
				report("Starting", System.err);

			while (rs.next()) {
				int contig_id = rs.getInt(1);
				int contiglen = rs.getInt(2);
				byte[] sequence = rs.getBytes(3);
				if (!quiet)
					System.err.println("Processing contig " + contig_id + " ("
							+ contiglen + " bp)");
				processContig(contig_id, contiglen, sequence);
				if (!quiet)
					report("\nFinished", System.err);
			}

			report("Generated " + allDone + " hashes", System.err);

			String oligo;

			BufferedReader br = new BufferedReader(new InputStreamReader(
					System.in));

			while (true) {
				System.out.print("Enter your oligo sequence: ");

				try {
					oligo = br.readLine();

					if (oligo == null || oligo.length() == 0)
						break;

					int oligolen = oligo.length();

					if (oligolen < hashsize) {
						System.err
								.println("The oligo is shorter than the hash size");
						continue;
					}

					int oligohash = hash(oligo);

					System.out.println("Oligo hash is " + oligohash);

					for (HashEntry entry = entries[oligohash]; entry != null; entry = entry
							.next()) {
						int contigid = entry.getContigId();
						int contigoffset = entry.getOffset();
						String sequence = (String) consensus.get(new Integer(
								contigid));

						String subseq = sequence.substring(contigoffset,
								contigoffset + oligolen);

						if (oligo.equalsIgnoreCase(subseq))
							System.out.println("Match to contig " + contigid
									+ " offset " + contigoffset);
					}

				} catch (IOException ioe) {
					System.exit(1);
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	private int hash(String oligo) {
		int value = 0;

		for (int i = 0; i < hashsize; i++) {
			value <<= 2;
			value |= hashCode(oligo.charAt(i));
		}

		return value & hashmask;
	}

	private void processContig(int contig_id, int contiglen, byte[] sequence)
			throws SQLException, DataFormatException {
		sequence = inflate(sequence, contiglen);
		try {
			consensus.put(new Integer(contig_id), new String(sequence,
					"US-ASCII"));
		} catch (UnsupportedEncodingException uce) {
		}

		processLine(contig_id, sequence);
	}

	private byte[] inflate(byte[] cdata, int length) throws DataFormatException {
		if (cdata == null)
			return null;

		byte[] data = new byte[length];

		decompresser.setInput(cdata, 0, cdata.length);
		decompresser.inflate(data, 0, data.length);
		decompresser.reset();

		return data;
	}

	private void processLine(int contig_id, byte[] line) {
		int start_pos = 0;
		int end_pos = 0;
		int bases_in_hash = 0;
		int hash = 0;
		int linelen = line.length;

		while (true) {
			while (start_pos < linelen && !isValid((char) line[start_pos]))
				start_pos++;
			
			char c = (char) line[start_pos];

			while (bases_in_hash < hashsize) {
				if (end_pos >= linelen)
					return;

				c = (char) line[end_pos];

				end_pos++;

				if (isValid(c)) {
					hash = updateHash(hash, c);
					bases_in_hash++;
				}
			}

			if (bases_in_hash == hashsize) {
				allDone++;
				storeHash(contig_id, start_pos, hash);
			}
			
			start_pos++;
			bases_in_hash--;
		}
	}

	private void storeHash(int contig_id, int offset, int hash) {
		HashEntry root = entries[hash];

		entries[hash] = new HashEntry(contig_id, offset, root);
	}

	private boolean isValid(char c) {
		return c == 'A' || c == 'a' || c == 'C' || c == 'c' || c == 'G'
				|| c == 'g' || c == 'T' || c == 't';
	}

	private int hashCode(char c) {
		switch (c) {
			case 'A':
			case 'a':
				return 0;

			case 'C':
			case 'c':
				return 1;

			case 'G':
			case 'g':
				return 2;

			case 'T':
			case 't':
				return 3;

			default:
				return -1;
		}
	}

	private int updateHash(int hash, char c) {
		int value = hashCode(c);

		hash <<= 2;

		if (value > 0)
			hash |= value;

		return hash & hashmask;
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-hashsize\tSize of kmer for hashing [default: 10]");
		ps.println("\t-allcontigs\tProcess all contigs, not just current set");
		ps.println("\t-minlen\t\tMinimum contig legnth [default: 0 if current set, 100000 if all]");
		ps.println();
		ps.println("\t-quiet\t\tDo not display per-contig report");
		ps.println("\t-progress\tDisplay progress in each contig with a dot per 100bp");
	}

	private void report(String caption, PrintStream ps) {
		long timenow = System.currentTimeMillis();

		ps.println(caption);
		ps.println("\tTime: " + (timenow - lasttime));

		lasttime = timenow;

		long totalmem = runtime.totalMemory();
		long freemem = runtime.freeMemory();
		long usedmem = totalmem - freemem;

		totalmem /= 1024;
		freemem /= 1024;
		usedmem /= 1024;

		ps.println("\tMemory (kb): (used/free/total) " + usedmem + "/"
				+ freemem + "/" + totalmem);
	}

	class HashEntry {
		private int contigid;
		private int offset;
		private HashEntry nextEntry;

		public HashEntry(int contigid, int offset, HashEntry nextEntry) {
			this.contigid = contigid;
			this.offset = offset;
			this.nextEntry = nextEntry;
		}

		int getContigId() {
			return contigid;
		}

		int getOffset() {
			return offset;
		}

		HashEntry next() {
			return nextEntry;
		}
	}
}
