package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

import java.sql.*;
import java.util.*;
import java.util.zip.*;
import java.io.UnsupportedEncodingException;

public class OligoFinder {
	public static final int HASHSIZE = 10;

	private ArcturusDatabase adb;
	private Connection conn = null;

	private int hashsize = HASHSIZE;
	private int hashmask = 0;

	private OligoFinderEventListener listener;
	private OligoFinderEvent event;

	private Inflater decompresser = new Inflater();

	private final String strConsensus = "select length,sequence from CONSENSUS where contig_id = ?";
	private PreparedStatement pstmtConsensus;

	public OligoFinder(ArcturusDatabase adb, OligoFinderEventListener listener) {
		this.adb = adb;
		initHash(HASHSIZE);
		event = new OligoFinderEvent(this);
		this.listener = listener;
	}

	private void initHash(int hashsize) {
		this.hashsize = hashsize;

		hashmask = 0;

		for (int i = 0; i < hashsize; i++) {
			hashmask |= 3 << (2 * i);
		}
	}

	public int findMatches(Oligo[] oligos, Contig[] contigs)
			throws SQLException {
		int found = 0;

		prepareOligos(oligos);

		if (conn == null)
			conn = adb.getPooledConnection();

		pstmtConsensus = conn.prepareStatement(strConsensus);

		int totlen = 0;
		for (int i = 0; i < contigs.length; i++)
			totlen += contigs[i].getLength();

		if (listener != null) {
			event.setEvent(OligoFinderEvent.START, null, null, totlen, false);
			listener.oligoFinderUpdate(event);
		}

		for (int i = 0; i < contigs.length; i++)
			found += findMatches(oligos, contigs[i]);

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH, null, null, -1, false);
			listener.oligoFinderUpdate(event);
		}
		
		conn.close();

		return found;
	}

	private int findMatches(Oligo[] oligos, Contig contig) throws SQLException {
		int found = 0;

		if (listener != null) {
			event.setEvent(OligoFinderEvent.START_CONTIG, null, contig, 0,
					false);
			listener.oligoFinderUpdate(event);
		}

		String sequence = getConsensus(contig.getID());

		if (sequence == null)
			return 0;

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
					processHashMatch(oligos, contig, sequence, start_pos, hash);

				bases_in_hash--;
			}

			if (bases_in_hash < 0)
				bases_in_hash = 0;

			if (end_pos < start_pos) {
				end_pos = start_pos;
				bases_in_hash = 0;
			}
		}

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH_CONTIG, null, contig, contig
					.getLength(), false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}

	private void processHashMatch(Oligo[] oligos, Contig contig,
			String sequence, int start_pos, int hash) {
		for (int i = 0; i < oligos.length; i++) {
			if (oligos[i] == null)
				continue;

			if (hash == oligos[i].getHash()) {
				if (listener != null) {
					event.setEvent(OligoFinderEvent.HASH_MATCH, oligos[i],
							contig, start_pos, true);
					listener.oligoFinderUpdate(event);
				}

				int end_pos = start_pos + oligos[i].getLength();

				if (end_pos <= sequence.length()) {
					String subseq = sequence.substring(start_pos, end_pos);

					if (subseq.equalsIgnoreCase(oligos[i].getSequence())
							&& listener != null) {
						event.setEvent(OligoFinderEvent.FOUND_MATCH, oligos[i],
								contig, start_pos, true);
						listener.oligoFinderUpdate(event);
					}
				}
			}

			if (hash == oligos[i].getReverseHash()) {
				if (listener != null) {
					event.setEvent(OligoFinderEvent.HASH_MATCH, oligos[i],
							contig, start_pos, false);
					listener.oligoFinderUpdate(event);
				}

				int end_pos = start_pos + oligos[i].getLength();

				if (end_pos <= sequence.length()) {
					String subseq = sequence.substring(start_pos, end_pos);

					if (subseq.equalsIgnoreCase(oligos[i].getReverseSequence())
							&& listener != null) {
						event.setEvent(OligoFinderEvent.FOUND_MATCH, oligos[i],
								contig, start_pos, false);
						listener.oligoFinderUpdate(event);
					}
				}
			}
		}
	}

	public int findMatches(Oligo[] oligos, Project[] projects)
			throws SQLException {
		Contig[] contigs = getContigsForProjects(projects);

		return findMatches(oligos, contigs);
	}

	private Contig[] getContigsForProjects(Project[] projects)
			throws SQLException {
		Set contigs = new HashSet();

		for (int i = 0; i < projects.length; i++)
			contigs.addAll(projects[i].getContigs(true));

		return (Contig[]) contigs.toArray(new Contig[0]);
	}

	private void prepareOligos(Oligo[] oligos) {
		for (int i = 0; i < oligos.length; i++) {
			if (oligos[i] != null) {
				oligos[i].setHash(hash(oligos[i].getSequence()));
				oligos[i].setReverseHash(hash(oligos[i].getReverseSequence()));
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
		pstmtConsensus.setInt(1, contig_id);

		ResultSet rs = pstmtConsensus.executeQuery();

		byte[] buffer;

		if (rs.next()) {
			int ctglen = rs.getInt(1);
			buffer = inflate(rs.getBytes(2), ctglen);
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
		if (conn != null) {
			conn.close();
			conn = null;
		}
	}
}
