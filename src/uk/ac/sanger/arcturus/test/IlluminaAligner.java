package uk.ac.sanger.arcturus.test;

import java.io.*;

public class IlluminaAligner {
	public static final int DEFAULT_HASHSIZE = 10;
	public static final int DEFAULT_MINLEN = 20;
	public static final int DEFAULT_DISTINCT_OFFSET = 10;
	
	public static final int FORWARD = 1;
	public static final int REVERSE = 2;

	private int hashsize = DEFAULT_HASHSIZE;
	private int minlen = DEFAULT_MINLEN;
	private int distinctOffset = DEFAULT_DISTINCT_OFFSET;

	private int hashmask = 0;

	private char[] refseq;

	private HashEntry[] lookup;

	private BufferedReader queryFileReader;

	public IlluminaAligner(String refseqFilename, String queryFilename,
			int hashsize, int minlen, int distinctOffset) throws IOException {
		this.hashsize = hashsize;
		this.minlen = minlen;
		this.distinctOffset = distinctOffset;

		refseq = loadReferenceSequence(refseqFilename);

		queryFileReader = new BufferedReader(new FileReader(queryFilename));
	}

	private char[] loadReferenceSequence(String filename) throws IOException {
		File file = new File(filename);
		long filesize = file.length();

		StringBuffer sb = new StringBuffer((int) filesize);

		BufferedReader br = new BufferedReader(new FileReader(file));

		String line = null;

		while ((line = br.readLine()) != null) {
			if (line.charAt(0) != '>')
				sb.append(line);
		}

		br.close();

		char[] seq = new char[sb.length()];

		sb.getChars(0, sb.length(), seq, 0);

		return seq;
	}

	public void run() throws IOException {
		makeHashTable();

		String line = null;

		int nseqs = 0;

		while ((line = queryFileReader.readLine()) != null) {
			nseqs++;

			if (nseqs % 100000 == 0)
				System.err.println(nseqs);
			
			String[] words = line.split("\\s");
			
			String seqname = words[0];
			char[] queryseq = words[1].toCharArray();
			
			processQuerySequence(seqname, queryseq);
		}

		queryFileReader.close();
	}
	
	private void processQuerySequence(String name, char[] sequence) {
		processQuerySequence(name, sequence, FORWARD);
		
		char[] revseq = reverseComplement(sequence);
		
		processQuerySequence(name, revseq, REVERSE);
	}
	
	private void processQuerySequence(String name, char[] sequence, int direction) {
		
	}

	private char[] reverseComplement(char[] sequence) {
		int seqlen = sequence.length;

		char[] rcseq = new char[seqlen];

		for (int i = 0; i < seqlen; i++)
			rcseq[i] = complement(sequence[seqlen - 1 - i]);

		return rcseq;
	}

	private char complement(char c) {
		switch (c) {
			case 'A': case 'a':
				return 'T';
				
			case 'C': case 'c':
				return 'G';
				
			case 'G': case 'g':
				return 'C';
				
			case 'T': case 't':
				return 'A';
				
			default:
				return c;
		}
	}

	private void makeHashTable() {
		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
		}

		int lookupsize = 1 << (2 * hashsize);

		System.err.println("Lookup table size is " + lookupsize);

		lookup = new HashEntry[lookupsize];

		int start_pos = 0;
		int end_pos = 0;
		int bases_in_hash = 0;
		int hash = 0;
		int seqlen = refseq.length;

		for (start_pos = 0; start_pos < seqlen - hashsize + 1; start_pos++) {
			char c = refseq[start_pos];

			if (isValid(c)) {
				while (end_pos < seqlen && bases_in_hash < hashsize) {
					char e = refseq[end_pos];

					if (isValid(e)) {
						hash = updateHash(hash, e);
						bases_in_hash++;
					}

					end_pos++;
				}

				if (bases_in_hash == hashsize)
					processHashMatch(start_pos, hash);

				bases_in_hash--;
			}

			if (bases_in_hash < 0)
				bases_in_hash = 0;

			if (end_pos < start_pos) {
				end_pos = start_pos;
				bases_in_hash = 0;
			}
		}

		int occupied = 0;

		for (int i = 0; i < lookupsize; i++)
			if (lookup[i] != null)
				occupied++;

		System.err.println("Lookup table has " + occupied
				+ " occupied entries and " + (lookupsize - occupied)
				+ " free entries");
	}

	private int updateHash(int hash, char c) {
		int value = baseToHashCode(c);

		hash <<= 2;

		if (value > 0)
			hash |= value;

		return hash & hashmask;
	}

	private int baseToHashCode(char c) {
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
				return 0;
		}
	}

	private void processHashMatch(int offset, int hash) {
		HashEntry entry = new HashEntry(offset, lookup[hash]);

		lookup[hash] = entry;
	}

	public static boolean isValid(char c) {
		switch (c) {
			case 'A': case 'a':
			case 'C': case 'c':
			case 'G': case 'g':
			case 'T': case 't':
				return true;
				
			default:
				return false;
		}
	}

	class HashEntry {
		private int offset = 0;
		private HashEntry next = null;

		public HashEntry(int offset, HashEntry next) {
			this.offset = offset;
			this.next = next;
		}

		public int getOffset() {
			return offset;
		}

		public HashEntry getNext() {
			return next;
		}
	}

	public static void main(String[] args) {
		int hashsize = DEFAULT_HASHSIZE;
		int minlen = DEFAULT_MINLEN;
		int distinctOffset = DEFAULT_DISTINCT_OFFSET;

		String refseqFilename = null;
		String queryFilename = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-refseq"))
				refseqFilename = args[++i];
			else if (args[i].equalsIgnoreCase("-query"))
				queryFilename = args[++i];
			else if (args[i].equalsIgnoreCase("-hashsize"))
				hashsize = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-minlen"))
				minlen = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-distinct_offset"))
				distinctOffset = Integer.parseInt(args[++i]);
			else {
				System.err.println("Unknown option: \"" + args[i] + "\"");
				printUsage(System.err);
				System.exit(1);
			}
		}

		if (refseqFilename == null || queryFilename == null) {
			System.err
					.println("You must specify file names for the reference sequence and query asequences");
			printUsage(System.err);
			System.exit(2);
		}

		try {
			IlluminaAligner aligner = new IlluminaAligner(refseqFilename,
					queryFilename, hashsize, minlen, distinctOffset);

			aligner.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	private static void printUsage(PrintStream ps) {
	}
}