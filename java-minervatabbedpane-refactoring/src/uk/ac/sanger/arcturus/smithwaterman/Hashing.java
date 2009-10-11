package uk.ac.sanger.arcturus.smithwaterman;

import java.io.*;
import java.util.*;
import java.text.*;

public class Hashing {
	protected int hashsize = 0;
	protected int hashmask = 0;
	protected boolean silent = false;
	protected Vector<HashEntry> hashes;
	protected DecimalFormat format = new DecimalFormat("##,###,###");

	public static void main(String[] args) {
		int hashsize = 0;
		boolean silent = false;
		int endsize = 0;

		for (int j = 0; j < args.length; j++) {
			if (args[j].equalsIgnoreCase("-hashsize"))
				hashsize = Integer.parseInt(args[++j]);

			if (args[j].equalsIgnoreCase("-endsize"))
				endsize = Integer.parseInt(args[++j]);

			if (args[j].equalsIgnoreCase("-silent"))
				silent = true;
		}

		if (hashsize < 1) {
			System.err.println("You didn't specify a hashsize");
			System.exit(1);
		}

		if (hashsize > 15) {
			System.err.println("Hash size must be less than 16");
			System.exit(1);
		}

		if (endsize < 0) {
			System.err
					.println("End size must be greater than or equal to zero");
			System.exit(1);
		}

		Hashing hashing = new Hashing(hashsize, silent);

		BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

		hashing.run(br, endsize);
	}

	public Hashing(int hashsize, boolean silent) {
		this.hashsize = hashsize;
		this.silent = silent;

		for (int j = 0; j < hashsize; j++) {
			hashmask <<= 2;
			hashmask |= 3;
		}
	}

	public void run(BufferedReader br, int endsize) {
		hashes = new Vector<HashEntry>();

		int seq_id = 0;

		while (true) {
			String seqname = null;
			String dna = null;

			try {
				seqname = br.readLine();

				if (seqname == null)
					break;

				dna = getNextSequence(br);

				if (dna == null)
					break;
			} catch (IOException ioe) {
				ioe.printStackTrace();
				System.exit(1);
			}

			seq_id++;

			if (!silent)
				System.out.println(seqname);

			int seqlen = dna.length();

			if (endsize > 0 && seqlen > 2 * endsize) {
				calculateHashes(dna.substring(0, endsize), 0, seq_id);
				calculateHashes(dna.substring(seqlen - endsize, seqlen), seqlen
						- endsize, seq_id);
			} else
				calculateHashes(dna, 0, seq_id);
		}

		System.out
				.println("Hash vector contains " + hashes.size() + " entries");

		reportMemory(System.out);

		HashEntryComparator comp = new HashEntryComparator(
				HashEntryComparator.BY_HASH_SEQID_POS);

		System.out.println("Casting to array ...");

		HashEntry[] array = new HashEntry[hashes.size()];
		hashes.toArray(array);

		reportMemory(System.out);

		System.out.println("Setting vector to null ...");

		hashes = null;

		reportMemory(System.out);

		System.out.println("Sorting by hash, seqid, pos ...");

		Arrays.sort(array, comp);

		reportMemory(System.out);

		if (!silent) {
			for (int i = 0; i < array.length; i++)
				System.out.println(Integer.toHexString(array[i].getHash())
						+ " " + array[i].getSeqId() + " " + array[i].getPos());
		}
	}

	private void reportMemory(PrintStream ps) {
		Runtime runtime = Runtime.getRuntime();
		long total = runtime.totalMemory() / 1024L;
		long free = runtime.freeMemory() / 1024L;
		long used = total - free;
		ps.println("MEMORY: Total/free/used=" + format.format(total) + "/"
				+ format.format(free) + "/" + format.format(used));
	}

	private void calculateHashes(String dna, int offset, int seq_id) {
		int hash = 0;
		int bad = hashsize;
		int val = 0;

		int maxpos = dna.length() - hashsize;

		for (int pos = 1 - hashsize; pos <= maxpos; pos++) {
			bad--;
			hash <<= 2;

			char c = dna.charAt(pos + hashsize - 1);

			val = hashcode(c);

			if (val >= 0) {
				hash |= val;
				hash &= hashmask;
			} else
				bad = hashsize;

			if (pos > 0 && bad <= 0)
				hashes.add(new HashEntry(seq_id, pos, hash));
		}
	}

	public static int hashcode(char c) {
		switch (c) {
		case 'a':
		case 'A':
			return 0;
		case 'c':
		case 'C':
			return 1;
		case 'g':
		case 'G':
			return 2;
		case 't':
		case 'T':
			return 3;
		default:
			return -1;
		}
	}

	public String getNextSequence(BufferedReader br) throws IOException {
		StringBuffer sb = new StringBuffer();
		String line = null;

		while (true) {
			br.mark(1000);

			line = br.readLine();

			if (line == null)
				break;

			if (line.startsWith(">")) {
				br.reset();
				break;
			} else
				sb.append(line);
		}

		if (sb.length() == 0)
			return null;
		else
			return sb.toString();
	}

	class HashEntry {
		protected int seq_id;
		protected int pos;
		protected int hash;

		public HashEntry(int seq_id, int pos, int hash) {
			this.seq_id = seq_id;
			this.pos = pos;
			this.hash = hash;
		}

		public int getSeqId() {
			return seq_id;
		}

		public int getPos() {
			return pos;
		}

		public int getHash() {
			return hash;
		}
	}

	class HashEntryComparator implements Comparator<HashEntry> {
		public static final int BY_HASH_SEQID_POS = 1;
		public static final int BY_SEQID_POS = 2;

		protected int mode = BY_HASH_SEQID_POS;

		public HashEntryComparator(int mode) {
			this.mode = mode;
		}

		public void setMode(int newmode) {
			this.mode = newmode;
		}

		public int getMode() {
			return mode;
		}

		public int compare(HashEntry entry1, HashEntry entry2) {
			if (mode == BY_HASH_SEQID_POS)
				return compareByHashSeqidPos(entry1, entry2);
			else
				return compareBySeqidPos(entry1, entry2);
		}

		private int compareByHashSeqidPos(HashEntry entry1, HashEntry entry2) {
			int diff = entry2.getHash() - entry1.getHash();

			if (diff != 0)
				return diff;

			diff = entry2.getSeqId() - entry1.getSeqId();

			if (diff != 0)
				return diff;

			return entry2.getPos() - entry1.getPos();
		}

		private int compareBySeqidPos(HashEntry entry1, HashEntry entry2) {
			int diff = entry2.getSeqId() - entry1.getSeqId();

			if (diff != 0)
				return diff;

			return entry2.getPos() - entry1.getPos();
		}

		public boolean equals(Object obj) {
			if (obj instanceof HashEntryComparator) {
				HashEntryComparator that = (HashEntryComparator) obj;
				return this == that;
			} else
				return false;
		}
	}
}
