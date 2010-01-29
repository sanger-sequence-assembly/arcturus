package uk.ac.sanger.arcturus.test;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.smithwaterman.*;

public class IlluminaAligner {
	public static final int DEFAULT_HASHSIZE = 10;
	public static final int DEFAULT_MINLEN = 20;
	public static final int DEFAULT_DISTINCT_OFFSET = 10;

	public static final int FORWARD = 1;
	public static final int REVERSE = 2;

	private int hashsize = DEFAULT_HASHSIZE;
	private int minlen = DEFAULT_MINLEN;
	private int distinctOffset = DEFAULT_DISTINCT_OFFSET;

	private boolean bestMatchOnly = false;

	private int hashmask = 0;

	private char[] refseq;

	private HashEntry[] lookup;

	private BufferedReader queryFileReader;

	private int fwdHits = 0;
	private int revHits = 0;

	private int fwdMatches = 0;
	private int revMatches = 0;

	private ScoringMatrix smat = new ScoringMatrix();

	public IlluminaAligner(String refseqFilename, String queryFilename,
			int hashsize, int minlen, int distinctOffset, boolean bestMatchOnly)
			throws IOException {
		this.hashsize = hashsize;
		this.minlen = minlen;
		this.distinctOffset = distinctOffset;
		this.bestMatchOnly = bestMatchOnly;

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

	public void run(int stopAfter) throws IOException {
		makeHashTable();

		String line = null;

		int nseqs = 0;

		while ((line = queryFileReader.readLine()) != null) {
			nseqs++;

			if (stopAfter > 0 && nseqs > stopAfter)
				break;

			if (nseqs % 100000 == 0)
				System.err.println(nseqs);

			String[] words = line.split("\\s");

			String seqname = words[0];
			char[] queryseq = words[1].toCharArray();

			processQuerySequence(seqname, queryseq);
		}

		System.err.println("hash matches: forward " + fwdHits + ", reverse "
				+ revHits);

		System.err.println("SW matches: forward " + fwdMatches + ", reverse "
				+ revMatches);

		queryFileReader.close();
	}

	class Match {
		public int score;
		public int subjectOffset;
		public int queryOffset;
		public int sense;
		public EditEntry[] edits;
		
		public void reset() {
			score = 0;
			edits = null;
		}
	}

	private Match bestMatch = new Match();

	private void processQuerySequence(String name, char[] sequence) {
		bestMatch.reset();

		processQuerySequence(name, sequence, FORWARD);

		char[] revseq = reverseComplement(sequence);

		processQuerySequence(name, revseq, REVERSE);

		if (bestMatchOnly && bestMatch.score > 0) {
			System.out.print(name + "\t"
					+ (bestMatch.sense == FORWARD ? 'F' : 'R') + "\t"
					+ bestMatch.subjectOffset + "\t" + bestMatch.queryOffset
					+ "\t" + bestMatch.score + "\t");
			
			EditEntry[] edits = bestMatch.edits;
			
			for (int j = 0; j < edits.length; j++)
				System.out.print(((j > 0) ? "," : "") + edits[j]);
			
			System.out.println();
		}
	}

	private Vector<Integer> hits = new Vector<Integer>();

	private boolean isCloseTo(int a, int b) {
		int diff = a - b;

		if (diff < 0)
			diff = -diff;

		return diff < distinctOffset;
	}

	private void processQuerySequence(String name, char[] sequence, int sense) {
		hits.clear();

		for (int offset = 0; offset <= sequence.length - hashsize; offset += hashsize) {
			int myhash = 0;

			for (int i = 0; i < hashsize; i++) {
				myhash <<= 2;
				myhash |= baseToHashCode(sequence[offset + i]);
			}

			for (HashEntry entry = lookup[myhash]; entry != null; entry = entry
					.getNext()) {
				hits.add(entry.getOffset() - offset);
			}
		}

		Collections.sort(hits);

		for (int i = 0; i < hits.size(); i++) {
			int value = hits.elementAt(i);

			int j = i + 1;

			while (j < hits.size() && isCloseTo(hits.elementAt(j), value))
				hits.remove(j);
		}

		if (hits.size() > 0) {
			if (sense == FORWARD)
				fwdHits++;
			else
				revHits++;

			int matches = 0;

			for (int i = 0; i < hits.size(); i++) {
				int subjectOffset = Math.max(0, hits.elementAt(i) - 5);
				int subjectLength = Math.min(sequence.length + 10,
						refseq.length - subjectOffset);

				int queryOffset = 0;
				int queryLength = sequence.length;

				int bandwidth = 20;

				SmithWatermanArrayModel sw = SmithWaterman.calculateMatrix(
						refseq, subjectOffset, subjectLength, sequence,
						queryOffset, queryLength, smat, bandwidth);

				try {
					Alignment alignment = SmithWaterman.getAlignment(sw);

					EditEntry[] edits = alignment.getEdits();

					int score = calculateScore(edits);

					if (score >= minlen) {
						int row = alignment.getRow();
						int column = alignment.getColumn();

						if (score > bestMatch.score) {
							bestMatch.score = score;
							bestMatch.subjectOffset = subjectOffset + row;
							bestMatch.sense = sense;
							bestMatch.queryOffset = column;
							bestMatch.edits = edits;
						}

						if (!bestMatchOnly) {
							System.out.print(name + "\t"
									+ (sense == FORWARD ? 'F' : 'R') + "\t"
									+ (subjectOffset + row) + "\t" + column
									+ "\t" + score + "\t");
							for (int j = 0; j < edits.length; j++)
								System.out.print(((j > 0) ? "," : "")
										+ edits[j]);
							System.out.println();
						}

						matches++;
					}
				} catch (SmithWatermanException e) {
					e.printStackTrace();
				}
			}

			if (matches > 0) {
				if (sense == FORWARD)
					fwdMatches++;
				else
					revMatches++;
			}
		}
	}

	private int calculateScore(EditEntry[] edits) {
		if (edits == null || edits.length == 0)
			return 0;

		int score = 0;

		for (int i = 0; i < edits.length; i++) {
			switch (edits[i].getType()) {
				case EditEntry.MATCH:
				case EditEntry.SUBSTITUTION:
				case EditEntry.INSERTION:
					score += edits[i].getCount();
					break;
			}
		}

		return score;
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
			case 'A':
			case 'a':
				return 'T';

			case 'C':
			case 'c':
				return 'G';

			case 'G':
			case 'g':
				return 'C';

			case 'T':
			case 't':
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
			case 'A':
			case 'a':
			case 'C':
			case 'c':
			case 'G':
			case 'g':
			case 'T':
			case 't':
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
		int stopAfter = 0;

		String refseqFilename = null;
		String queryFilename = null;

		boolean bestMatchOnly = false;

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
			else if (args[i].equalsIgnoreCase("-stopafter"))
				stopAfter = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-bestmatchonly"))
				bestMatchOnly = true;
			else {
				System.err.println("Unknown option: \"" + args[i] + "\"");
				printUsage(System.err);
				System.exit(1);
			}
		}

		if (refseqFilename == null || queryFilename == null) {
			printUsage(System.err);
			System.exit(2);
		}

		try {
			IlluminaAligner aligner = new IlluminaAligner(refseqFilename,
					queryFilename, hashsize, minlen, distinctOffset,
					bestMatchOnly);

			aligner.run(stopAfter);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	private static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS");
		ps.println("\t-refseq\t\t\tName of reference sequence FASTA file");
		ps.println("\t-query\t\t\tName of query sequences file");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-hashsize\t\tSize of kmer hash [Default:"
				+ DEFAULT_HASHSIZE + "]");
		ps.println("\t-minlen\t\t\tMinimum match length in query [Default: "
				+ DEFAULT_MINLEN + "]");
		ps
				.println("\t-distinct_offset\tMinimum difference in offsets for distinct hash");
		ps
				.println("\t\t\t\tmatches [Default: " + DEFAULT_DISTINCT_OFFSET
						+ "]");
		ps.println("\t-stopafter\t\tStop after this many query sequences");
		ps
				.println("\t-bestmatchonly\t\tOnly display the best match for each query sequence");
	}
}