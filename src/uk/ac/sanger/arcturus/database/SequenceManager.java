package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Clipping;
import uk.ac.sanger.arcturus.data.Tag;

import java.sql.*;
import java.util.*;
import java.util.zip.*;

/**
 * This class manages Sequence objects.
 * <P>
 * In the context of a SequenceManager, Sequence objects can be identified
 * either by their unique sequence ID number or by the read ID number of the
 * parent read.
 * <P>
 * Moreover, the SequenceManager can create Sequence objects in two forms, with
 * or without the DNA and base quality data.
 * <P>
 * Sequence objects which have been created without DNA and base quality data
 * can have this information added retrospectively by the SequenceManager.
 */

public class SequenceManager extends AbstractManager {
	private ArcturusDatabase adb;
	private Connection conn;
	private HashMap hashByReadID;
	private HashMap hashBySequenceID;
	private PreparedStatement pstmtByReadID;
	private PreparedStatement pstmtFullByReadID;
	private PreparedStatement pstmtBySequenceID;
	private PreparedStatement pstmtFullBySequenceID;
	private PreparedStatement pstmtDNAAndQualityBySequenceID;
	private PreparedStatement pstmtQualityClipping;
	private PreparedStatement pstmtSequenceVectorClipping;
	private PreparedStatement pstmtCloningVectorClipping;
	private PreparedStatement pstmtTags;
	private Inflater decompresser = new Inflater();

	/**
	 * Creates a new SequenceManager to provide sequence management services to
	 * an ArcturusDatabase object.
	 */

	public SequenceManager(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;

		conn = adb.getConnection();

		String query = "select SEQ2READ.seq_id,version,seqlen from SEQ2READ left join SEQUENCE using(seq_id)"
				+ "where read_id = ? order by version desc limit 1";
		pstmtByReadID = conn.prepareStatement(query);

		query = "select SEQ2READ.seq_id,version,seqlen,sequence,quality from SEQ2READ left join SEQUENCE using(seq_id)"
				+ " where read_id = ? order by version desc limit 1";
		pstmtFullByReadID = conn.prepareStatement(query);

		query = "select read_id,version,seqlen from SEQ2READ left join SEQUENCE using(seq_id) where seq_id = ?";
		pstmtBySequenceID = conn.prepareStatement(query);

		query = "select read_id,version,seqlen,sequence,quality from SEQ2READ left join SEQUENCE using(seq_id)"
				+ " where SEQ2READ.seq_id = ?";
		pstmtFullBySequenceID = conn.prepareStatement(query);

		query = "select seqlen,sequence,quality from SEQUENCE where seq_id = ?";
		pstmtDNAAndQualityBySequenceID = conn.prepareStatement(query);

		query = "select qleft,qright from QUALITYCLIP where seq_id = ?";
		pstmtQualityClipping = conn.prepareStatement(query);

		query = "select svleft,svright from SEQVEC where seq_id = ?";
		pstmtSequenceVectorClipping = conn.prepareStatement(query);

		query = "select cvleft,cvright from CLONEVEC where seq_id = ?";
		pstmtCloningVectorClipping = conn.prepareStatement(query);
		
		query = "select tagtype,pstart,pfinal,comment from READTAG where seq_id = ? and deprecated='N'";
		pstmtTags = conn.prepareStatement(query);

		hashByReadID = new HashMap();
		hashBySequenceID = new HashMap();
	}

	public void clearCache() {
		hashByReadID.clear();
		hashBySequenceID.clear();
	}

	/**
	 * Creates a Sequence object without DNA and base quality data, identified
	 * by the parent read ID.
	 * <P>
	 * The Sequence thus created will be the one with the highest version
	 * number, corresponding to the most recently edited version of the read.
	 * 
	 * @param readid
	 *            the ID of the parent read.
	 * 
	 * @return the Sequence object corresponding to the given read. If more than
	 *         one version exists for the given read ID, the sequence with the
	 *         highest version number will be returned.
	 */

	public Sequence getSequenceByReadID(int readid) throws SQLException {
		return getSequenceByReadID(readid, true);
	}

	public Sequence getSequenceByReadID(int readid, boolean autoload)
			throws SQLException {
		Object obj = hashByReadID.get(new Integer(readid));

		return (obj == null && autoload) ? loadSequenceByReadID(readid)
				: (Sequence) obj;
	}

	private Sequence loadSequenceByReadID(int readid) throws SQLException {
		pstmtByReadID.setInt(1, readid);
		ResultSet rs = pstmtByReadID.executeQuery();

		Sequence sequence = null;

		if (rs.next()) {
			Read read = adb.getReadByID(readid);
			int seqid = rs.getInt(1);
			int version = rs.getInt(2);
			sequence = createAndRegisterNewSequence(seqid, read, version, null,
					null);
		}

		rs.close();

		setClippings(sequence);
		loadTagsForSequence(sequence);

		return sequence;
	}

	/**
	 * Creates a Sequence object without DNA and base quality data, identified
	 * by the parent read.
	 * <P>
	 * The Sequence thus created will be the one with the highest version
	 * number, corresponding to the most recently edited version of the read.
	 * 
	 * @param read
	 *            the parent read.
	 * 
	 * @return the Sequence object corresponding to the given read. If more than
	 *         one version exists for the given read, the sequence with the
	 *         highest version number will be returned.
	 */

	public Sequence getSequenceByRead(Read read) throws SQLException {
		return getSequenceByRead(read, true);
	}

	public Sequence getSequenceByRead(Read read, boolean autoload)
			throws SQLException {
		int readid = read.getID();
		Object obj = hashByReadID.get(new Integer(readid));

		return (obj == null && autoload) ? loadSequenceByRead(read)
				: (Sequence) obj;
	}

	private Sequence loadSequenceByRead(Read read) throws SQLException {
		int readid = read.getID();
		pstmtByReadID.setInt(1, readid);
		ResultSet rs = pstmtByReadID.executeQuery();

		Sequence sequence = null;

		if (rs.next()) {
			int seqid = rs.getInt(1);
			int version = rs.getInt(2);
			int seqlen = rs.getInt(3);
			sequence = createAndRegisterNewSequence(seqid, read, version,
					seqlen);
		}

		rs.close();

		setClippings(sequence);
		loadTagsForSequence(sequence);

		return sequence;
	}

	/**
	 * Creates a Sequence object with DNA and base quality data, identified by
	 * the parent read ID.
	 * <P>
	 * The Sequence thus created will be the one with the highest version
	 * number, corresponding to the most recently edited version of the read.
	 * 
	 * @param readid
	 *            the ID of the parent read.
	 * 
	 * @return the Sequence object corresponding to the given read. If more than
	 *         one version exists for the given read ID, the sequence with the
	 *         highest version number will be returned.
	 */

	public Sequence getFullSequenceByReadID(int readid) throws SQLException {
		return getFullSequenceByReadID(readid, true);
	}

	public Sequence getFullSequenceByReadID(int readid, boolean autoload)
			throws SQLException {
		Object obj = hashByReadID.get(new Integer(readid));

		if (obj == null)
			return autoload ? loadFullSequenceByReadID(readid) : null;

		Sequence sequence = (Sequence) obj;

		if (sequence.getDNA() == null || sequence.getQuality() == null)
			getDNAAndQualityForSequence(sequence);

		return sequence;
	}

	private Sequence loadFullSequenceByReadID(int readid) throws SQLException {
		pstmtFullByReadID.setInt(1, readid);
		ResultSet rs = pstmtFullByReadID.executeQuery();

		Sequence sequence = null;

		if (rs.next()) {
			Read read = adb.getReadByID(readid);
			int seqid = rs.getInt(1);
			int version = rs.getInt(2);
			int seqlen = rs.getInt(3);
			byte[] dna = decodeCompressedData(rs.getBytes(4), seqlen);
			byte[] quality = decodeCompressedData(rs.getBytes(5), seqlen);
			sequence = createAndRegisterNewSequence(seqid, read, version, dna,
					quality);
		}

		rs.close();

		setClippings(sequence);
		loadTagsForSequence(sequence);

		return sequence;
	}

	/**
	 * Creates a Sequence object without DNA and base quality data, identified
	 * by the given sequence ID.
	 * 
	 * @param seqid
	 *            the sequence ID.
	 * 
	 * @return the Sequence object corresponding to the given ID.
	 */

	public Sequence getSequenceBySequenceID(int seqid) throws SQLException {
		return getSequenceBySequenceID(seqid, true);
	}

	public Sequence getSequenceBySequenceID(int seqid, boolean autoload)
			throws SQLException {
		Object obj = hashBySequenceID.get(new Integer(seqid));

		return (obj == null && autoload) ? loadSequenceBySequenceID(seqid)
				: (Sequence) obj;
	}

	private Sequence loadSequenceBySequenceID(int seqid) throws SQLException {
		pstmtBySequenceID.setInt(1, seqid);
		ResultSet rs = pstmtBySequenceID.executeQuery();

		Sequence sequence = null;

		if (rs.next()) {
			int readid = rs.getInt(1);
			Read read = adb.getReadByID(readid);
			int version = rs.getInt(2);
			int seqlen = rs.getInt(3);
			sequence = createAndRegisterNewSequence(seqid, read, version,
					seqlen);
		}

		rs.close();

		setClippings(sequence);
		loadTagsForSequence(sequence);

		return sequence;
	}

	/**
	 * Creates a Sequence object with DNA and base quality data, identified by
	 * the given sequence ID.
	 * 
	 * @param seqid
	 *            the sequence ID.
	 * 
	 * @return the Sequence object corresponding to the given ID.
	 */

	public Sequence getFullSequenceBySequenceID(int seqid) throws SQLException {
		return getFullSequenceBySequenceID(seqid, true);
	}

	public Sequence getFullSequenceBySequenceID(int seqid, boolean autoload)
			throws SQLException {
		Object obj = hashBySequenceID.get(new Integer(seqid));

		if (obj == null)
			return autoload ? loadFullSequenceBySequenceID(seqid) : null;

		Sequence sequence = (Sequence) obj;

		if (sequence.getDNA() == null || sequence.getQuality() == null)
			getDNAAndQualityForSequence(sequence);

		return sequence;
	}

	private Sequence loadFullSequenceBySequenceID(int seqid)
			throws SQLException {
		pstmtFullBySequenceID.setInt(1, seqid);
		ResultSet rs = pstmtFullBySequenceID.executeQuery();

		Sequence sequence = null;

		if (rs.next()) {
			int readid = rs.getInt(1);
			Read read = adb.getReadByID(readid);
			int version = rs.getInt(2);
			int seqlen = rs.getInt(3);
			byte[] dna = decodeCompressedData(rs.getBytes(4), seqlen);
			byte[] quality = decodeCompressedData(rs.getBytes(5), seqlen);
			sequence = createAndRegisterNewSequence(seqid, read, version, dna,
					quality);
		}

		rs.close();

		setClippings(sequence);
		loadTagsForSequence(sequence);

		return sequence;
	}

	/**
	 * Retrieves the DNA and base quality data for the given Sequence object and
	 * sets the corresponding fields of the object.
	 * 
	 * @param sequence
	 *            the Sequence object whose DNA and base quality data are to be
	 *            retrieved and set.
	 */

	public void getDNAAndQualityForSequence(Sequence sequence)
			throws SQLException {
		int seqid = sequence.getID();
		pstmtDNAAndQualityBySequenceID.setInt(1, seqid);
		ResultSet rs = pstmtDNAAndQualityBySequenceID.executeQuery();

		if (rs.next()) {
			int seqlen = rs.getInt(1);
			byte[] dna = decodeCompressedData(rs.getBytes(2), seqlen);
			byte[] quality = decodeCompressedData(rs.getBytes(3), seqlen);
			sequence.setDNA(dna);
			sequence.setQuality(quality);
		}

		rs.close();
	}

	byte[] decodeCompressedData(byte[] compressed, int length) {
		byte[] buffer = new byte[length];

		try {
			decompresser.setInput(compressed, 0, compressed.length);
			decompresser.inflate(buffer, 0, buffer.length);
			decompresser.reset();
		} catch (DataFormatException dfe) {
			buffer = null;
			dfe.printStackTrace();
		}

		return buffer;
	}

	/**
	 * Creates and registers a new Sequence object from the given parameters.
	 * 
	 * @param seqid
	 *            the sequence ID of the new sequence.
	 * @param read
	 *            the Read object to which the new sequence belongs.
	 * @param version
	 *            the version number of the new sequence.
	 * @param dna
	 *            the sequence array of the new new sequence.
	 * @param quality
	 *            the base-quality array of the new sequence.
	 */

	private Sequence createAndRegisterNewSequence(int seqid, Read read,
			int version, byte[] dna, byte[] quality) {
		Sequence sequence = new Sequence(seqid, read, dna, quality, version);
		registerNewSequence(sequence);
		return sequence;
	}

	/**
	 * Creates and registers a new Sequence object from the given parameters.
	 * 
	 * @param seqid
	 *            the sequence ID of the new sequence.
	 * @param read
	 *            the Read object to which the new sequence belongs.
	 * @param version
	 *            the version number of the new sequence.
	 * @param length
	 *            the length of the sequence.
	 */

	private Sequence createAndRegisterNewSequence(int seqid, Read read,
			int version, int length) {
		Sequence sequence = new Sequence(seqid, read, length, version);
		registerNewSequence(sequence);
		return sequence;
	}

	/**
	 * Registers a newly-created Sequence object by adding it to hash maps which
	 * are indexed by read ID and sequence ID.
	 */

	void registerNewSequence(Sequence sequence) {
		if (cacheing) {
			hashBySequenceID.put(new Integer(sequence.getID()), sequence);

			Read read = sequence.getRead();

			if (read != null)
				hashByReadID.put(new Integer(read.getID()), sequence);
		}
	}

	/**
	 * Retrieves quality, sequence vector and cloning vector clipping
	 * information from the database and sets the relevant Clipping properties
	 * of the sequence.
	 */

	private void setClippings(Sequence sequence) throws SQLException {
		int seqid = sequence.getID();

		pstmtQualityClipping.setInt(1, seqid);

		ResultSet rs = pstmtQualityClipping.executeQuery();

		if (rs.next()) {
			int qleft = rs.getInt(1);
			int qright = rs.getInt(2);
			sequence.setQualityClipping(new Clipping(Clipping.QUAL, qleft,
					qright));
		}

		rs.close();

		pstmtCloningVectorClipping.setInt(1, seqid);

		rs = pstmtCloningVectorClipping.executeQuery();

		if (rs.next()) {
			int cvleft = rs.getInt(1);
			int cvright = rs.getInt(2);
			sequence.setCloningVectorClipping(new Clipping(Clipping.CVEC,
					cvleft, cvright));
		}

		rs.close();

		pstmtSequenceVectorClipping.setInt(1, seqid);

		rs = pstmtSequenceVectorClipping.executeQuery();

		while (rs.next()) {
			int svleft = rs.getInt(1);
			int svright = rs.getInt(2);

			Clipping clipping = new Clipping(Clipping.SVEC, svleft, svright);

			if (svleft == 1)
				sequence.setSequenceVectorClippingLeft(clipping);
			else
				sequence.setSequenceVectorClippingRight(clipping);
		}

		rs.close();
	}

	public Sequence findOrCreateSequence(int seq_id, int length) {
		Sequence sequence = (Sequence) hashBySequenceID
				.get(new Integer(seq_id));

		if (sequence == null) {
			sequence = new Sequence(seq_id, null, length);

			registerNewSequence(sequence);
		}

		return sequence;
	}

	private void loadTagsForSequence(Sequence sequence) throws SQLException {
		int seq_id = sequence.getID();

		Vector<Tag> tags = sequence.getTags();
		
		if (tags != null)
			tags.clear();

		pstmtTags.setInt(1, seq_id);
		ResultSet rs = pstmtTags.executeQuery();

		while (rs.next()) {
			String type = rs.getString(1);
			int pstart = rs.getInt(2);
			int pfinal = rs.getInt(3);
			String comment = rs.getString(4);
			
			Tag tag = new Tag(type, pstart, pfinal, comment);

			sequence.addTag(tag);
		}

		rs.close();
	}
}
