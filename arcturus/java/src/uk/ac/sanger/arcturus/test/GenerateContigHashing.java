package uk.ac.sanger.arcturus.test;

import java.io.PrintStream;
import java.sql.*;
import java.util.zip.*;
import java.text.*;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

public class GenerateContigHashing {
	private String instance = null;
	private String organism = null;
	private Inflater decompresser = new Inflater();
	private PreparedStatement pstmtInsertHash = null;
	private boolean quiet = false;
	private boolean progress = false;
	private int hashsize = 10;
	protected int hashmask;
	protected boolean noStore = false;
	protected boolean tiled = false;
	
	protected DecimalFormat df = new DecimalFormat("########");

	private long lasttime;
	private Runtime runtime = Runtime.getRuntime();

	private ArcturusDatabase adb = null;
	private Connection conn1 = null;
	private Connection conn2 = null;
	
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
		boolean oneRowMode = false;

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
			
			if (args[i].equalsIgnoreCase("-onerowmode"))
				oneRowMode = true;
			
			if (args[i].equalsIgnoreCase("-nostore"))
				noStore = true;
			
			if (args[i].equalsIgnoreCase("-tiled"))
				tiled = true;
		}
		
		if (minlen < 0)
			minlen = allContigs ? 100000: 0;

		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
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

			System.err.flush();

			adb = ai.findArcturusDatabase(organism);

			adb.getSequenceManager().setCacheing(false);

			conn1 = adb.getConnection();

			if (conn1 == null) {
				System.err.println("Connection 1 is undefined");
				printUsage(System.err);
				System.exit(1);
			}
			
			conn2 = (oneRowMode && !noStore) ? adb.getUniqueConnection() : conn1;
			
			if (conn2 == null) {
				System.err.println("Connection 2 is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			String query = "insert into HASHING(contig_id,offset,hash,hashsize) " +
				"VALUES(?,?,?,?)";
			
			if (!noStore)
				pstmtInsertHash = conn2.prepareStatement(query);
			
			String queryCurrent = "select CONSENSUS.contig_id,length,sequence" +
					" from CONSENSUS left join C2CMAPPING " +
					" on CONSENSUS.contig_id = C2CMAPPING.parent_id" +
					" where C2CMAPPING.parent_id is null and length >= " + minlen;
			
			String queryAll = "select contig_id,length,sequence" +
				" from CONSENSUS where length >= " + minlen;
			
			Statement stmt = conn1.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY,
		              java.sql.ResultSet.CONCUR_READ_ONLY);
			
			if (oneRowMode)
				stmt.setFetchSize(Integer.MIN_VALUE);
			
			ResultSet rs = stmt.executeQuery(allContigs ? queryAll : queryCurrent);

			lasttime = System.currentTimeMillis();

			if (!quiet)
				report("Starting", System.err);
			
			while (rs.next()) {
				int contig_id = rs.getInt(1);
				int contiglen = rs.getInt(2);
				byte[] sequence = rs.getBytes(3);
				if (!quiet)
					System.err.println("Processing contig " + contig_id + " (" + contiglen + " bp)");
				processContig(contig_id, contiglen, sequence);
				if (!quiet)
					report("\nFinished", System.err);
			}
		}
		catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
	
	private void processContig(int contig_id, int contiglen, byte[] sequence)
		throws SQLException, DataFormatException {
		sequence = inflate(sequence, contiglen);
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
	
	private void processLine(int contig_id, byte[] line) throws SQLException {
		int start_pos = 0;
		int end_pos = 0;
		int bases_in_hash = 0;
		int hash = 0;
		int linelen = line.length;
		int done = 0;

		while (true) {
			if (start_pos >= line.length)
				return;
			
			char c = (char)line[start_pos];

			if (isValid(c)) {
				while (bases_in_hash < hashsize) {
					if (end_pos >= linelen) {						
						if (progress)
							System.err.print('\n');
						return;
					}
					c = (char)line[end_pos];

					end_pos++;

					if (isValid(c)) {
						hash = updateHash(hash, c);
						bases_in_hash++;
					}
				}

				storeHash(contig_id, start_pos, hash, hashsize);
				
				done++;
				
				if (progress && ((done % 100) == 0))
					System.err.print('.');
				
				if (progress && ((done % 8000) == 0))
					System.err.print('\n');
				
				if (tiled) {
					start_pos = end_pos;
					bases_in_hash = 0;
				}
			}
			
			start_pos++;
			bases_in_hash--;
		}
	}
	
	private void storeHash(int contig_id, int offset, int hash, int hashsize)
		throws SQLException {
		if (noStore) {
			System.out.print(df.format(contig_id));
			System.out.print("  ");
			System.out.print(df.format(offset));
			System.out.print("  ");
			System.out.println(df.format(hash));
			return;
		}
		
		pstmtInsertHash.setInt(1, contig_id);
		pstmtInsertHash.setInt(2, offset);
		pstmtInsertHash.setInt(3, hash);
		pstmtInsertHash.setInt(4, hashsize);

		int rows = pstmtInsertHash.executeUpdate();
		
		if (rows != 1)
			System.err.println("storeHash(" + contig_id + ", " + offset + ", " + hash + ", " +
					hashsize + ") failed");
	}

	private boolean isValid(char c) {
		return c == 'A' || c == 'a' || c == 'C' || c == 'c' || c == 'G'
				|| c == 'g' || c == 'T' || c == 't';
	}

	private int updateHash(int hash, char c) {
		int value = -1;

		switch (c) {
			case 'A':
			case 'a':
				value = 0;
				break;
			case 'C':
			case 'c':
				value = 1;
				break;
			case 'G':
			case 'g':
				value = 2;
				break;
			case 'T':
			case 't':
				value = 3;
				break;
		}
		
		hash <<= 2;
		
		if (value >= 0)
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

		ps.println("\tMemory (kb): (free/total) " + runtime.freeMemory()
				/ 1024 + "/" + runtime.totalMemory() / 1024);
	}

}
