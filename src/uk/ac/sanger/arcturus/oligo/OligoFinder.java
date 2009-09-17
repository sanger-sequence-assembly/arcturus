package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.*;

import java.sql.*;
import java.util.*;
import java.util.zip.*;
import java.io.UnsupportedEncodingException;

import java.util.regex.Pattern;
import java.util.regex.Matcher;

public class OligoFinder {
	public static final int HASHSIZE = 10;

	private static final boolean useRegex = Arcturus.getBoolean("oligofinder.useRegex");

	private ArcturusDatabase adb;
	private Connection conn = null;

	private int hashsize = HASHSIZE;
	private int hashmask = 0;

	private OligoFinderEventListener listener;
	private OligoFinderEvent event;

	private Inflater decompresser = new Inflater();

	private final String strConsensus = "select length,sequence from CONSENSUS where contig_id = ?";
	private PreparedStatement pstmtConsensus;

	private final String strSequence = "select seqlen,sequence from"
			+ " SEQ2READ left join SEQUENCE using(seq_id) where read_id = ? order by seq_id limit 1";
	private PreparedStatement pstmtSequence;

	private Read[] cachedFreeReads = null;

	public OligoFinder(ArcturusDatabase adb, OligoFinderEventListener listener) {
		this.adb = adb;

		initHash(HASHSIZE);

		event = new OligoFinderEvent(this);

		this.listener = listener;

		try {
			conn = adb.getPooledConnection(this);
			prepareStatements();
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error when opening or preparing connection",
					sqle);
		}
	}

	private void prepareStatements() throws SQLException {
		pstmtConsensus = conn.prepareStatement(strConsensus);

		pstmtSequence = conn.prepareStatement(strSequence);
	}

	private void initHash(int hashsize) {
		this.hashsize = hashsize;

		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
		}
	}

	class Task extends Thread {
		private Connection conn;

		private final String strFreeReads = "select read_id,readname from FREEREADS";
		private PreparedStatement pstmtFreeReads;

		Read[] reads = null;

		public void run() {
			Vector<Read> v = new Vector<Read>();

			try {
				conn = adb.getPooledConnection(this);

				pstmtFreeReads = conn.prepareStatement(strFreeReads);

				if (pstmtFreeReads.execute()) {
					ResultSet rs = pstmtFreeReads.getResultSet();

					if (rs != null) {
						while (rs.next())
							v
									.add(new Read(rs.getString(2),
											rs.getInt(1), null));
					}

					reads = (Read[]) v.toArray(new Read[0]);

				}
			} catch (SQLException sqle) {
				Arcturus
						.logWarning("Error whilst enumerating free reads", sqle);
			} finally {
				try {
					conn.close();
				} catch (SQLException sqle) {
					Arcturus
							.logWarning("Error whilst closing connection", sqle);
				}
			}
		}

		public Read[] getReads() {
			return reads;
		}

		public int getReadCount() {
			return (reads == null) ? 0 : reads.length;
		}
	}

	public boolean hasCachedFreeReads() {
		return cachedFreeReads != null;
	}

	public synchronized int findMatches(Oligo[] oligos, Contig[] contigs,
			boolean searchFreeReads, boolean useCachedFreeReads)
			throws SQLException {
		System.err.println("Using " + (useRegex ? "regex" : "hashing") + " engine");
		
		int found = 0;
		Task task = null;

		if (searchFreeReads && (cachedFreeReads == null || !useCachedFreeReads)) {
			task = new Task();
			task.setName("OligoFinder:FreeReadSearch");
			task.start();
		}

		prepareOligos(oligos);

		if (contigs != null && contigs.length > 0) {
			int totlen = 0;

			for (int i = 0; i < contigs.length; i++)
				totlen += contigs[i].getLength();

			if (listener != null) {
				event.setEvent(OligoFinderEvent.START_CONTIGS, null, null,
						totlen, false);
				listener.oligoFinderUpdate(event);
			}

			for (int i = 0; i < contigs.length; i++)
				found += findMatches(oligos, contigs[i]);

			if (listener != null) {
				event.setEvent(OligoFinderEvent.FINISH_CONTIGS, null, null, -1,
						false);
				listener.oligoFinderUpdate(event);
			}
		}

		if (searchFreeReads) {
			if (task != null) {
				try {
					if (listener != null) {
						event.setEvent(OligoFinderEvent.ENUMERATING_FREE_READS,
								null, null, -1, false);
						listener.oligoFinderUpdate(event);
					}

					task.join();
				} catch (InterruptedException e) {
					Arcturus
							.logWarning(
									"Interrupted whilst waiting for free-read eumerator to complete",
									e);
				}

				cachedFreeReads = task.getReads();
			}

			int nreads = cachedFreeReads == null ? 0 : cachedFreeReads.length;

			if (nreads > 0) {
				if (listener != null) {
					event.setEvent(OligoFinderEvent.START_READS, null, null,
							nreads, false);
					listener.oligoFinderUpdate(event);
				}

				for (int i = 0; i < cachedFreeReads.length; i++)
					found += findMatches(oligos, cachedFreeReads[i]);

				if (listener != null) {
					event.setEvent(OligoFinderEvent.FINISH_READS, null, null,
							-1, false);
					listener.oligoFinderUpdate(event);
				}
			}
		}

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH, null, null, -1, false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}

	private int findMatches(Oligo[] oligos, DNASequence dnaSequence)
			throws SQLException {
		int found = 0;

		if (listener != null) {
			event.setEvent(OligoFinderEvent.START_SEQUENCE, null, dnaSequence,
					0, false);
			listener.oligoFinderUpdate(event);
		}

		String sequence = null;

		if (dnaSequence instanceof Contig) {
			Contig contig = (Contig) dnaSequence;
			sequence = getConsensus(contig.getID());
		} else if (dnaSequence instanceof Read) {
			Read read = (Read) dnaSequence;
			sequence = getReadSequence(read.getID());
		}

		if (sequence != null) {
			event.setDNASequence(dnaSequence);
			
			found += useRegex ? findMatchesByRegex(oligos, sequence) : findMatchesByHash(oligos, sequence);
		}

		int sequencelen = sequence == null ? 0 : sequence.length();

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH_SEQUENCE, null,
					sequencelen, false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}
	
	private int findMatchesByRegex(Oligo[] oligos, String sequence) {
		int hits = 0;
		
		for (Oligo oligo : oligos) {
			hits += findRegexMatch(oligo, true, sequence);
			
			if (!oligo.isPalindrome())
				hits += findRegexMatch(oligo, false, sequence);
		}
		
		return hits;
	}
	
	private int findRegexMatch(Oligo oligo, boolean forward, String sequence) {
		int hits = 0;
		
		Pattern pattern = forward ? oligo.getForwardPattern() : oligo.getReversePattern();
		
		Matcher matcher = pattern.matcher(sequence);
		
		while (matcher.find()) {
			int offset = matcher.start();
			reportMatch(oligo, offset, forward);
			hits++;
		}
		
		return hits;
	}

	private int findMatchesByHash(Oligo[] oligos, String sequence) {
		int hits = 0;
		
		int start_pos = 0;
		int end_pos = 0;
		int bases_in_hash = 0;
		int hash = 0;
		int sequencelen = sequence.length();

		for (start_pos = 0; start_pos < sequencelen - hashsize + 1; start_pos++) {
			char c = sequence.charAt(start_pos);

			if (isValid(c)) {
				while (end_pos < sequencelen && bases_in_hash < hashsize) {
					char e = sequence.charAt(end_pos);

					if (isValid(e)) {
						hash = updateHash(hash, e);
						bases_in_hash++;
					}

					end_pos++;
				}

				if (bases_in_hash == hashsize)
					hits += processHashMatch(oligos, sequence, start_pos, hash);

				bases_in_hash--;
			}

			if (bases_in_hash < 0)
				bases_in_hash = 0;

			if (end_pos < start_pos) {
				end_pos = start_pos;
				bases_in_hash = 0;
			}
		}

		return hits;
	}

	private int processHashMatch(Oligo[] oligos,
			String sequence, int start_pos, int hash) {
		int hits = 0;
		
		for (int i = 0; i < oligos.length; i++) {
			if (oligos[i] == null)
				continue;

			if (hash == oligos[i].getHash()) {
				if (listener != null) {
					event.setEvent(OligoFinderEvent.HASH_MATCH, oligos[i],
							start_pos, true);
					listener.oligoFinderUpdate(event);
				}

				if (testSequenceMatch(oligos[i], true, sequence,
						start_pos))
					hits++;
			}

			if (hash == oligos[i].getReverseHash()) {
				if (listener != null) {
					event.setEvent(OligoFinderEvent.HASH_MATCH, oligos[i],
							start_pos, false);
					listener.oligoFinderUpdate(event);
				}

				if (testSequenceMatch(oligos[i], false, sequence,
						start_pos))
					hits++;
			}
		}
		
		return hits;
	}

	private boolean testSequenceMatch(Oligo oligo, boolean forward,
			String sequence, int offset) {
		String oligoseq = forward ? oligo.getSequence() : oligo
				.getReverseSequence();
		
		boolean match = comparePaddedSequence(oligoseq, sequence, offset);

		if (match)
			reportMatch(oligo, offset, forward);
				
		return match;
	}
	
	private void reportMatch(Oligo oligo, int offset, boolean forward) {
		if (listener != null) {
			event.setEvent(OligoFinderEvent.FOUND_MATCH, oligo,
					offset, forward);
			listener.oligoFinderUpdate(event);
		}

	}

	private boolean comparePaddedSequence(String oligoseq, String sequence,
			int offset) {
		int seqlen = sequence.length();

		if (offset + oligoseq.length() > seqlen)
			return false;

		for (int i = 0; i < oligoseq.length(); i++) {
			char oc = Character.toUpperCase(oligoseq.charAt(i));

			while (offset < seqlen && !isValid(sequence.charAt(offset)))
				offset++;

			if (offset < seqlen) {
				char sc = Character.toUpperCase(sequence.charAt(offset));

				if (oc != sc)
					return false;

				offset++;
			} else
				return false;
		}

		return true;
	}

	public int findMatches(Oligo[] oligos, Project[] projects,
			boolean searchFreeReads, boolean useCachedFreeReads)
			throws SQLException {
		Contig[] contigs = getContigsForProjects(projects);

		return findMatches(oligos, contigs, searchFreeReads, useCachedFreeReads);
	}

	private Contig[] getContigsForProjects(Project[] projects)
			throws SQLException {
		Set<Contig> contigs = new HashSet<Contig>();

		for (int i = 0; i < projects.length; i++)
			contigs.addAll(projects[i].getContigs(true));

		return (Contig[]) contigs.toArray(new Contig[0]);
	}

	private void prepareOligos(Oligo[] oligos) {
		for (int i = 0; i < oligos.length; i++) {
			if (oligos[i] != null) {
				if (!useRegex) {
					oligos[i].setHash(hash(oligos[i].getSequence()));
					oligos[i].setReverseHash(hash(oligos[i]
							.getReverseSequence()));
				}
			}
		}
	}

	private boolean isValid(char c) {
		return c == 'A' || c == 'a' || c == 'C' || c == 'c' || c == 'G'
				|| c == 'g' || c == 'T' || c == 't';
	}

	private int updateHash(int hash, char c) {
		int value = hashCode(c);

		hash <<= 2;

		if (value > 0)
			hash |= value;

		return hash & hashmask;
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
				return 0;
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

	private String getConsensus(int contig_id) throws SQLException {
		return getDNASequence(pstmtConsensus, contig_id);
	}

	private String getReadSequence(int readid) throws SQLException {
		return getDNASequence(pstmtSequence, readid);
	}

	private String getDNASequence(PreparedStatement pstmt, int seqid)
			throws SQLException {
		pstmt.setInt(1, seqid);

		ResultSet rs = pstmt.executeQuery();

		byte[] buffer;

		if (rs.next()) {
			int seqlen = rs.getInt(1);
			buffer = inflate(rs.getBytes(2), seqlen);
		} else
			buffer = null;

		rs.close();

		if (buffer == null)
			return null;

		try {
			return new String(buffer, "US-ASCII");
		} catch (UnsupportedEncodingException uee) {
			return null;
		}
	}

	private byte[] inflate(byte[] cdata, int length) {
		if (cdata == null)
			return null;

		if (cdata.length == length)
			return cdata;

		byte[] data = new byte[length];

		decompresser.setInput(cdata, 0, cdata.length);
		try {
			decompresser.inflate(data, 0, data.length);
		} catch (DataFormatException dfe) {
			Arcturus.logWarning(
					"An error occurred whilst decompressing consensus data",
					dfe);
			data = null;
		}

		decompresser.reset();

		return data;
	}

	public void close() throws SQLException {
		closeConnection();
	}

	private void closeConnection() throws SQLException {
		if (conn != null) {
			conn.close();
			conn = null;
		}
	}
}
