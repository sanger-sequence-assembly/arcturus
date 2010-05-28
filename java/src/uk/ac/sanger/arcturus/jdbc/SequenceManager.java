package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Clipping;
import uk.ac.sanger.arcturus.data.Tag;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

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
	private HashMap<Integer, Sequence> hashByReadID;
	private HashMap<Integer, Sequence> hashBySequenceID;
	
	private DictionaryTableManager dictSequenceVector;
	private DictionaryTableManager dictCloningVector;
	
	private static final String GET_BASIC_SEQUENCE_DATA_BY_READ_ID=
		"select SEQ2READ.seq_id,version,seqlen from SEQ2READ left join SEQUENCE using(seq_id)"
		+ "where read_id = ? order by version desc limit 1";
	
	private static final String GET_FULL_SEQUENCE_DATA_BY_READ_ID =
		"select SEQ2READ.seq_id,version,seqlen,sequence,quality from SEQ2READ left join SEQUENCE using(seq_id)"
		+ " where read_id = ? order by version desc limit 1";
	
	private static final String GET_BASIC_SEQUENCE_DATA_BY_SEQUENCE_ID =
		"select read_id,version,seqlen from SEQ2READ left join SEQUENCE using(seq_id) where seq_id = ?";
	
	private static final String GET_FULL_SEQUENCE_DATA_BY_SEQUENCE_ID =
		"select read_id,version,seqlen,sequence,quality from SEQ2READ left join SEQUENCE using(seq_id)"
		+ " where SEQ2READ.seq_id = ?";
	
	private static final String GET_DNA_AND_QUALITY_BY_SEQUENCE_ID =
		"select seqlen,sequence,quality from SEQUENCE where seq_id = ?";
	
	private static final String GET_QUALITY_CLIPPING =
		"select qleft,qright from QUALITYCLIP where seq_id = ?";
	
	private static final String GET_SEQUENCE_VECTOR_CLIPPING =
		"select svleft,svright from SEQVEC where seq_id = ?";
	
	private static final String GET_CLONING_VECTOR_CLIPPING =
		"select cvleft,cvright from CLONEVEC where seq_id = ?";
	
	private static final String GET_TAGS =
		"select tagtype,pstart,pfinal,comment from READTAG where seq_id = ? and deprecated='N'";
	
	private static final String GET_SEQUENCE_ID_BY_READ_ID_AND_HASH =
		"select S.seq_id from SEQ2READ SR left join SEQUENCE S using (seq_id) where SR.read_id = ?" +
		" and S.seq_hash = ? and S.qual_hash = ?";
	
	private static final String PUT_SEQUENCE =
		"insert into SEQUENCE (seqlen,seq_hash,qual_hash,sequence,quality) VALUES (?,?,?,?,?)";
	
	private static final String GET_MAXIMUM_VERSION =
		"select max(version) from SEQ2READ where read_id = ?";
	
	private static final String PUT_SEQUENCE_TO_READ =
		"insert into SEQ2READ (seq_id, read_id, version) VALUES (?,?,?)";
	
	private static final String PUT_QUALITY_CLIPPING =
		"insert into QUALITYCLIP (seq_id,qleft,qright) VALUES (?,?,?)";
	
	private static final String PUT_SEQUENCE_VECTOR_CLIPPING =
		"insert into SEQVEC (seq_id,svector_id,svleft,svright) VALUES (?,?,?,?)";
		
	private static final String PUT_CLONING_VECTOR_CLIPPING =
		"insert into CLONEVEC (seq_id,cvector_id,cvleft,cvright) VALUES (?,?,?,?)";
	
	private PreparedStatement pstmtGetBasicSequenceDataByReadID;
	private PreparedStatement pstmtGetFullSequenceDataByReadID;
	
	private PreparedStatement pstmtGetBasicSequenceDataBySequenceID;
	private PreparedStatement pstmtGetFullSequenceDataBySequenceID;
	
	private PreparedStatement pstmtGetDNAAndQualityBySequenceID;
	private PreparedStatement pstmtGetQualityClipping;
	private PreparedStatement pstmtGetSequenceVectorClipping;
	private PreparedStatement pstmtGetCloningVectorClipping;
	private PreparedStatement pstmtGetTags;
	
	private PreparedStatement pstmtGetSequenceIDByReadIDAndHash;
	
	private PreparedStatement pstmtPutSequence;
	
	private PreparedStatement pstmtGetMaximumVersion;
	private PreparedStatement pstmtPutSequenceToRead;
	
	private PreparedStatement pstmtPutQualityClipping;
	private PreparedStatement pstmtPutSequenceVectorClipping;
	private PreparedStatement pstmtPutCloningVectorClipping;
	
	private Inflater decompresser = new Inflater();
	private Deflater compresser = new Deflater(Deflater.BEST_COMPRESSION);

	/**
	 * Creates a new SequenceManager to provide sequence management services to
	 * an ArcturusDatabase object.
	 */

	public SequenceManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		hashByReadID = new HashMap<Integer, Sequence>();
		hashBySequenceID = new HashMap<Integer, Sequence>();
		
		dictSequenceVector = new DictionaryTableManager(adb, "SEQUENCEVECTOR", "svector_id", "name");
		
		dictCloningVector = new DictionaryTableManager(adb, "CLONINGVECTOR", "cvector_id", "name");
		
		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the sequence manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		pstmtGetBasicSequenceDataByReadID = prepareStatement(GET_BASIC_SEQUENCE_DATA_BY_READ_ID);
		pstmtGetFullSequenceDataByReadID = prepareStatement(GET_FULL_SEQUENCE_DATA_BY_READ_ID);

		pstmtGetBasicSequenceDataBySequenceID = prepareStatement(GET_BASIC_SEQUENCE_DATA_BY_SEQUENCE_ID);
		pstmtGetFullSequenceDataBySequenceID = prepareStatement(GET_FULL_SEQUENCE_DATA_BY_SEQUENCE_ID);

		pstmtGetDNAAndQualityBySequenceID = prepareStatement(GET_DNA_AND_QUALITY_BY_SEQUENCE_ID);

		pstmtGetQualityClipping = prepareStatement(GET_QUALITY_CLIPPING);
		pstmtGetSequenceVectorClipping = prepareStatement(GET_SEQUENCE_VECTOR_CLIPPING);
		pstmtGetCloningVectorClipping = prepareStatement(GET_CLONING_VECTOR_CLIPPING);
		
		pstmtGetTags = prepareStatement(GET_TAGS);
		
		pstmtGetSequenceIDByReadIDAndHash = prepareStatement(GET_SEQUENCE_ID_BY_READ_ID_AND_HASH);
		
		pstmtPutSequence = prepareStatement(PUT_SEQUENCE, Statement.RETURN_GENERATED_KEYS);
		
		pstmtGetMaximumVersion = prepareStatement(GET_MAXIMUM_VERSION);
		pstmtPutSequenceToRead = prepareStatement(PUT_SEQUENCE_TO_READ);
		
		pstmtPutQualityClipping = prepareStatement(PUT_QUALITY_CLIPPING);
		pstmtPutSequenceVectorClipping = prepareStatement(PUT_SEQUENCE_VECTOR_CLIPPING);
		pstmtPutCloningVectorClipping = prepareStatement(PUT_CLONING_VECTOR_CLIPPING);
	}

	public void clearCache() {
		hashByReadID.clear();
		hashBySequenceID.clear();
	}
	
	public void preload() throws ArcturusDatabaseException {
		// This method does nothing, as we never want to pre-load all sequences.
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

	public Sequence getSequenceByReadID(int readid) throws ArcturusDatabaseException {
		return getSequenceByReadID(readid, true);
	}

	public Sequence getSequenceByReadID(int readid, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByReadID.get(new Integer(readid));

		return (obj == null && autoload) ? loadSequenceByReadID(readid)
				: (Sequence) obj;
	}

	private Sequence loadSequenceByReadID(int readid) throws ArcturusDatabaseException {
		Sequence sequence = null;

		try {
			pstmtGetBasicSequenceDataByReadID.setInt(1, readid);
			ResultSet rs = pstmtGetBasicSequenceDataByReadID.executeQuery();

			if (rs.next()) {
				Read read = adb.getReadByID(readid);
				int seqid = rs.getInt(1);
				int version = rs.getInt(2);
				sequence = createAndRegisterNewSequence(seqid, read, version,
						null, null);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load sequence by read ID=" + readid, conn, this);
		}

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

	public Sequence getSequenceByRead(Read read) throws ArcturusDatabaseException {
		return getSequenceByRead(read, true);
	}

	public Sequence getSequenceByRead(Read read, boolean autoload)
			throws ArcturusDatabaseException {
		int readid = read.getID();
		Object obj = hashByReadID.get(new Integer(readid));

		return (obj == null && autoload) ? loadSequenceByRead(read)
				: (Sequence) obj;
	}

	private Sequence loadSequenceByRead(Read read) throws ArcturusDatabaseException {
		Sequence sequence = null;

		int readid = read.getID();
		
		try {
			pstmtGetBasicSequenceDataByReadID.setInt(1, readid);
			ResultSet rs = pstmtGetBasicSequenceDataByReadID.executeQuery();

			if (rs.next()) {
				int seqid = rs.getInt(1);
				int version = rs.getInt(2);
				int seqlen = rs.getInt(3);
				sequence = createAndRegisterNewSequence(seqid, read, version,
						seqlen);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load sequence by read ID=" + readid, conn, this);
		}

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

	public Sequence getFullSequenceByReadID(int readid) throws ArcturusDatabaseException {
		return getFullSequenceByReadID(readid, true);
	}

	public Sequence getFullSequenceByReadID(int readid, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByReadID.get(new Integer(readid));

		if (obj == null)
			return autoload ? loadFullSequenceByReadID(readid) : null;

		Sequence sequence = (Sequence) obj;

		if (sequence.getDNA() == null || sequence.getQuality() == null)
			getDNAAndQualityForSequence(sequence);

		return sequence;
	}

	private Sequence loadFullSequenceByReadID(int readid) throws ArcturusDatabaseException {
		Sequence sequence = null;

		try {
			pstmtGetFullSequenceDataByReadID.setInt(1, readid);
			ResultSet rs = pstmtGetFullSequenceDataByReadID.executeQuery();

			if (rs.next()) {
				Read read = adb.getReadByID(readid);
				int seqid = rs.getInt(1);
				int version = rs.getInt(2);
				int seqlen = rs.getInt(3);
				byte[] dna = decodeCompressedData(rs.getBytes(4), seqlen);
				byte[] quality = decodeCompressedData(rs.getBytes(5), seqlen);
				sequence = createAndRegisterNewSequence(seqid, read, version,
						dna, quality);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load full sequence by read ID=" + readid, conn, this);
		}
		catch (DataFormatException e) {
			throw new ArcturusDatabaseException(e, "Failed to decompress DNA and quality for sequence by read ID=" + readid, conn, adb);
		}

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

	public Sequence getSequenceBySequenceID(int seqid) throws ArcturusDatabaseException {
		return getSequenceBySequenceID(seqid, true);
	}

	public Sequence getSequenceBySequenceID(int seqid, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashBySequenceID.get(new Integer(seqid));

		return (obj == null && autoload) ? loadSequenceBySequenceID(seqid)
				: (Sequence) obj;
	}

	private Sequence loadSequenceBySequenceID(int seqid) throws ArcturusDatabaseException {
		Sequence sequence = null;

		try {
			pstmtGetBasicSequenceDataBySequenceID.setInt(1, seqid);
			ResultSet rs = pstmtGetBasicSequenceDataBySequenceID.executeQuery();

			if (rs.next()) {
				int readid = rs.getInt(1);
				Read read = adb.getReadByID(readid);
				int version = rs.getInt(2);
				int seqlen = rs.getInt(3);
				sequence = createAndRegisterNewSequence(seqid, read, version,
						seqlen);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to full sequence by ID=" + seqid, conn, this);
		}

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

	public Sequence getFullSequenceBySequenceID(int seqid) throws ArcturusDatabaseException {
		return getFullSequenceBySequenceID(seqid, true);
	}

	public Sequence getFullSequenceBySequenceID(int seqid, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashBySequenceID.get(new Integer(seqid));

		if (obj == null)
			return autoload ? loadFullSequenceBySequenceID(seqid) : null;

		Sequence sequence = (Sequence) obj;

		if (sequence.getDNA() == null || sequence.getQuality() == null)
			getDNAAndQualityForSequence(sequence);

		return sequence;
	}

	private Sequence loadFullSequenceBySequenceID(int seqid)
			throws ArcturusDatabaseException {
		Sequence sequence = null;

		try {
			pstmtGetFullSequenceDataBySequenceID.setInt(1, seqid);
			ResultSet rs = pstmtGetFullSequenceDataBySequenceID.executeQuery();

			if (rs.next()) {
				int readid = rs.getInt(1);
				Read read = adb.getReadByID(readid);
				int version = rs.getInt(2);
				int seqlen = rs.getInt(3);
				byte[] dna = decodeCompressedData(rs.getBytes(4), seqlen);
				byte[] quality = decodeCompressedData(rs.getBytes(5), seqlen);
				sequence = createAndRegisterNewSequence(seqid, read, version,
						dna, quality);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load full sequence by ID=" + seqid, conn, this);
		}
		catch (DataFormatException e) {
			throw new ArcturusDatabaseException(e, "Failed to decompress DNA and quality for sequence ID=" + seqid, conn, adb);
		}

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
			throws ArcturusDatabaseException {
		int seqid = sequence.getID();
		
		try {
			pstmtGetDNAAndQualityBySequenceID.setInt(1, seqid);
			ResultSet rs = pstmtGetDNAAndQualityBySequenceID.executeQuery();

			if (rs.next()) {
				int seqlen = rs.getInt(1);
				byte[] dna = decodeCompressedData(rs.getBytes(2), seqlen);
				byte[] quality = decodeCompressedData(rs.getBytes(3), seqlen);
				sequence.setDNA(dna);
				sequence.setQuality(quality);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get DNA and quality for sequence ID=" + seqid, conn, this);
		}
		catch (DataFormatException e) {
			throw new ArcturusDatabaseException(e, "Failed to decompress DNA and quality for sequence ID=" + seqid, conn, adb);
		}
	}

	byte[] decodeCompressedData(byte[] compressed, int length) throws DataFormatException {
		byte[] buffer = new byte[length];

		decompresser.setInput(compressed, 0, compressed.length);
		decompresser.inflate(buffer, 0, buffer.length);
		decompresser.reset();

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

	private void setClippings(Sequence sequence) throws ArcturusDatabaseException {
		int seqid = sequence.getID();

		try {
			pstmtGetQualityClipping.setInt(1, seqid);

			ResultSet rs = pstmtGetQualityClipping.executeQuery();

			if (rs.next()) {
				int qleft = rs.getInt(1);
				int qright = rs.getInt(2);
				sequence.setQualityClipping(new Clipping(Clipping.QUAL, qleft,
						qright));
			}

			rs.close();

			pstmtGetCloningVectorClipping.setInt(1, seqid);

			rs = pstmtGetCloningVectorClipping.executeQuery();

			if (rs.next()) {
				int cvleft = rs.getInt(1);
				int cvright = rs.getInt(2);
				sequence.setCloningVectorClipping(new Clipping(Clipping.CVEC,
						cvleft, cvright));
			}

			rs.close();

			pstmtGetSequenceVectorClipping.setInt(1, seqid);

			rs = pstmtGetSequenceVectorClipping.executeQuery();

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
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to set clipping data for sequence ID=" + seqid,
					conn, this);
		}
	}

	public Sequence findOrCreateSequence(Sequence sequence) throws ArcturusDatabaseException {
		if (sequence == null)
			throw new ArcturusDatabaseException("Cannot find/create a null sequence");
		
		if (sequence.getRead() == null)
			throw new ArcturusDatabaseException("Cannot find/create a sequence with a null read");
		
		int read_id = sequence.getRead().getID();
		
		if (read_id <= 0)
			throw new ArcturusDatabaseException("Cannot find/create a sequence with a read whose ID is zero");
		
		Sequence cachedSequence = hashBySequenceID.get(sequence.getID());
		
		if (cachedSequence != null)
			return cachedSequence;
		
		if (sequence.getDNA() == null)
			throw new ArcturusDatabaseException("Cannot find/create a sequence with no DNA");
		
		if (sequence.getQuality() == null)
			throw new ArcturusDatabaseException("Cannot find/create a sequence with no quality");
		
		int seq_id = getSequenceIDByReadIDAndHash(read_id, sequence.getDNAHash(), sequence.getQualityHash());
		
		if (seq_id <= 0)
			seq_id = putSequence(sequence);
		
		sequence.setID(seq_id);
		registerNewSequence(sequence);
		
		return sequence;
	}

	private void loadTagsForSequence(Sequence sequence) throws ArcturusDatabaseException {
		int seqid = sequence.getID();

		Vector<Tag> tags = sequence.getTags();
		
		if (tags != null)
			tags.clear();

		try {
			pstmtGetTags.setInt(1, seqid);
			ResultSet rs = pstmtGetTags.executeQuery();

			while (rs.next()) {
				String type = rs.getString(1);
				int pstart = rs.getInt(2);
				int pfinal = rs.getInt(3);
				String comment = rs.getString(4);

				Tag tag = new Tag(type, pstart, pfinal, comment);

				sequence.addTag(tag);
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to set load tags for sequence ID=" + seqid,
					conn, this);
		}
	}
	
	public int getSequenceIDByReadIDAndHash(int read_id, byte[] sequenceHash, byte[] qualityHash)
		throws ArcturusDatabaseException {
		try {
			pstmtGetSequenceIDByReadIDAndHash.setInt(1, read_id);
			pstmtGetSequenceIDByReadIDAndHash.setBytes(2, sequenceHash);
			pstmtGetSequenceIDByReadIDAndHash.setBytes(3, qualityHash);
			
			ResultSet rs = pstmtGetSequenceIDByReadIDAndHash.executeQuery();
			
			int seq_id = rs.next() ? rs.getInt(1) : -1;
			
			rs.close();
			
			return seq_id;
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find sequence ID for ID=" + read_id + " and hashes",
					conn, this);
		}
		
		return -1;
	}
	
	private byte[] compressData(byte[] data) {
		byte[] buffer = new byte[12 + (5 * data.length) / 4];
		
		compresser.reset();
		compresser.setInput(data);
		compresser.finish();
		
		int compressedDataLength = compresser.deflate(buffer);
		
		byte[] compressedData = new byte[compressedDataLength];
		
		for (int i = 0; i < compressedDataLength; i++)
			compressedData[i] = buffer[i];
		
		return compressedData;
	}
	
	public int putSequence(Sequence sequence) throws ArcturusDatabaseException {
		if (sequence == null)
			throw new IllegalArgumentException("Cannot store a null sequence");
		
		Read read = sequence.getRead();
		
		if (read == null)
			throw new ArcturusDatabaseException("The sequence has no associated read");
		
		if (read.getID() == 0)
			read = adb.findOrCreateRead(read);
		
		int read_id = read.getID();
		
		int seq_id = -1;
		
		byte[] dna = sequence.getDNA();
			
		if (dna != null)
			dna = compressData(dna);
			
		byte[] quality = sequence.getQuality();
			
		if (quality != null)
			quality = compressData(quality);
			
		byte[] dnaHash = sequence.getDNAHash();
		byte[] qualityHash = sequence.getQualityHash();
			
		int seqlen = sequence.getLength();
			
		try {
			beginTransaction();
			
			pstmtPutSequence.setInt(1, seqlen);
			pstmtPutSequence.setBytes(2, dnaHash);
			pstmtPutSequence.setBytes(3, qualityHash);
			pstmtPutSequence.setBytes(4, dna);
			pstmtPutSequence.setBytes(5, quality);
			
			int rc = pstmtPutSequence.executeUpdate();
			
			if (rc != 1) {
				rollbackTransaction();
				return -1;
			}
			
			ResultSet rs = pstmtPutSequence.getGeneratedKeys();
			
			seq_id = rs.next() ? rs.getInt(1) : -1;
			
			rs.close();
			
			if (seq_id < 0) {
				rollbackTransaction();
				return -1;
			}
			
			Clipping clip = sequence.getQualityClipping();
			
			if (clip != null) {
				pstmtPutQualityClipping.setInt(1, seq_id);
				pstmtPutQualityClipping.setInt(2, clip.getLeft());
				pstmtPutQualityClipping.setInt(3, clip.getRight());
				
				pstmtPutQualityClipping.executeUpdate();
			}
			
			clip = sequence.getSequenceVectorClippingLeft();
			
			if (clip != null) {
				int svector_id = dictSequenceVector.getID(clip.getName());
				
				pstmtPutSequenceVectorClipping.setInt(1, seq_id);
				pstmtPutSequenceVectorClipping.setInt(2, svector_id);
				pstmtPutSequenceVectorClipping.setInt(3, clip.getLeft());
				pstmtPutSequenceVectorClipping.setInt(4, clip.getRight());
				
				pstmtPutSequenceVectorClipping.executeUpdate();
			}		
			
			clip = sequence.getSequenceVectorClippingRight();
			
			if (clip != null) {
				int svector_id = dictSequenceVector.getID(clip.getName());
				
				pstmtPutSequenceVectorClipping.setInt(1, seq_id);
				pstmtPutSequenceVectorClipping.setInt(2, svector_id);
				pstmtPutSequenceVectorClipping.setInt(3, clip.getLeft());
				pstmtPutSequenceVectorClipping.setInt(4, clip.getRight());
				
				pstmtPutSequenceVectorClipping.executeUpdate();
			}
			
			clip = sequence.getCloningVectorClipping();
			
			if (clip != null) {
				int cvector_id = dictCloningVector.getID(clip.getName());
				
				pstmtPutCloningVectorClipping.setInt(1, seq_id);
				pstmtPutCloningVectorClipping.setInt(2, cvector_id);
				pstmtPutCloningVectorClipping.setInt(3, clip.getLeft());
				pstmtPutCloningVectorClipping.setInt(4, clip.getRight());
				
				pstmtPutCloningVectorClipping.executeUpdate();
			}
			
			pstmtGetMaximumVersion.setInt(1, read_id);
			
			rs = pstmtGetMaximumVersion.executeQuery();
			
			int version = 0;
			
			if (rs.next()) {
				version = rs.getInt(1) + 1;
				
				if (rs.wasNull())
					version = 0;
			}
			
			rs.close();
			
			pstmtPutSequenceToRead.setInt(1, seq_id);
			pstmtPutSequenceToRead.setInt(2, read_id);
			pstmtPutSequenceToRead.setInt(3, version);
			
			pstmtPutSequenceToRead.executeUpdate();
			
			commitTransaction();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to store a sequence",
					conn, this);
			
			try {
				rollbackTransaction();
			} catch (SQLException e1) {
				adb.handleSQLException(e, "Failed to roll back a transaction when storing a sequence",
						conn, this);
			}
		}
		
		return seq_id;
	}
}
