package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;

import java.sql.*;
import java.util.*;
import java.util.zip.*;

/**
 * This class manages Sequence objects.
 * <P>
 * In the context of a SequenceManager, Sequence objects can be identified either by their
 * unique sequence ID number or by the read ID number of the parent read.
 * <P>
 * Moreover, the SequenceManager can create Sequence objects in two forms, with or without
 * the DNA and base quality data.
 * <P>
 * Sequence objects which have been created without DNA and base quality data can have this
 * information added retrospectively by the SequenceManager.
 */

public class SequenceManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByReadID;
    private HashMap hashBySequenceID;
    private PreparedStatement pstmtByReadID;
    private PreparedStatement pstmtFullByReadID;
    private PreparedStatement pstmtBySequenceID;
    private PreparedStatement pstmtFullBySequenceID;
    private PreparedStatement pstmtDNAAndQualityBySequenceID;
    private Inflater decompresser = new Inflater();

    /**
     * Creates a new SequenceManager to provide sequence management
     * services to an ArcturusDatabase object.
     */

    public SequenceManager(ArcturusDatabase adb) throws SQLException {
	this.adb = adb;

	conn = adb.getConnection();

	String query = "select seq_id,version from SEQ2READ where read_id = ? order by version desc limit 1";
	pstmtByReadID = conn.prepareStatement(query);

	query = "select SEQ2READ.seq_id,version,seqlen,sequence,quality from SEQ2READ left join SEQUENCE using(seq_id)" +
	    " where read_id = ? order by version desc limit 1";
	pstmtFullByReadID = conn.prepareStatement(query);

	query = "select read_id,version from SEQ2READ where seq_id = ?";
	pstmtBySequenceID = conn.prepareStatement(query);

	query = "select read_id,version,seqlen,sequence,quality from SEQ2READ left join SEQUENCE using(seq_id)" +
	    " where SEQ2READ.seq_id = ?";
	pstmtFullBySequenceID = conn.prepareStatement(query);

	query = "select seqlen,sequence,quality from SEQUENCE where seq_id = ?";
	pstmtDNAAndQualityBySequenceID = conn.prepareStatement(query);

	hashByReadID = new HashMap();
	hashBySequenceID = new HashMap();
    }

    /**
     * Creates a Sequence object without DNA and base quality data, identified by the parent
     * read ID.
     * <P>
     * The Sequence thus created will be the one with the highest version number, corresponding
     * to the most recently edited version of the read.
     *
     * @param readid the ID of the parent read.
     *
     * @return the Sequence object corresponding to the given read. If more than one version
     * exists for the given read ID, the sequence with the highest version number will be
     * returned.
     */

    public Sequence getSequenceByReadID(int readid) throws SQLException {
	Object obj = hashByReadID.get(new Integer(readid));

	return (obj == null) ? loadSequenceByReadID(readid) : (Sequence)obj;
    }

    private Sequence loadSequenceByReadID(int readid) throws SQLException {
	pstmtByReadID.setInt(1, readid);
	ResultSet rs = pstmtByReadID.executeQuery();

	Sequence sequence = null;

	if (rs.next()) {
	    Read read = adb.getReadManager().getReadByID(readid);
	    int seqid = rs.getInt(1);
	    int version = rs.getInt(2);
	    sequence = registerNewSequence(read, seqid, version, null, null);
	}

	rs.close();

	return sequence;
    }

    /**
     * Creates a Sequence object with DNA and base quality data, identified by the parent
     * read ID.
     * <P>
     * The Sequence thus created will be the one with the highest version number, corresponding
     * to the most recently edited version of the read.
     *
     * @param readid the ID of the parent read.
     *
     * @return the Sequence object corresponding to the given read. If more than one version
     * exists for the given read ID, the sequence with the highest version number will be
     * returned.
     */

    public Sequence getFullSequenceByReadID(int readid) throws SQLException {
	Object obj = hashByReadID.get(new Integer(readid));

	if (obj == null)
	    return loadFullSequenceByReadID(readid);

	Sequence sequence = (Sequence)obj;

	if (sequence.getDNA() == null || sequence.getQuality() == null)
	    getDNAAndQualityForSequence(sequence);

	return sequence;
    }

    private Sequence loadFullSequenceByReadID(int readid) throws SQLException {
	pstmtFullByReadID.setInt(1, readid);
	ResultSet rs = pstmtFullByReadID.executeQuery();

	Sequence sequence = null;

	if (rs.next()) {
	    Read read = adb.getReadManager().getReadByID(readid);
	    int seqid = rs.getInt(1);
	    int version = rs.getInt(2);
	    int seqlen = rs.getInt(3);
	    byte[] dna = decodeCompressedData(rs.getBytes(4), seqlen);
	    byte[] quality = decodeCompressedData(rs.getBytes(5), seqlen);
	    sequence = registerNewSequence(read, seqid, version, dna, quality);
	}

	rs.close();

	return sequence;
    }

    /**
     * Creates a Sequence object without DNA and base quality data, identified by the given
     * sequence ID.
     *
     * @param seqid the sequence ID.
     *
     * @return the Sequence object corresponding to the given ID.
     */

    public Sequence getSequenceBySequenceID(int seqid) throws SQLException {
	Object obj = hashBySequenceID.get(new Integer(seqid));

	return (obj == null) ? loadSequenceBySequenceID(seqid) : (Sequence)obj;
    }

    private Sequence loadSequenceBySequenceID(int seqid) throws SQLException {
	pstmtBySequenceID.setInt(1, seqid);
	ResultSet rs = pstmtBySequenceID.executeQuery();

	Sequence sequence = null;

	if (rs.next()) {
	    int readid = rs.getInt(1);
	    Read read = adb.getReadManager().getReadByID(readid);
	    int version = rs.getInt(2);
	    sequence = registerNewSequence(read, seqid, version, null, null);
	}

	rs.close();

	return sequence;
    }

    /**
     * Creates a Sequence object with DNA and base quality data, identified by the given
     * sequence ID.
     *
     * @param seqid the sequence ID.
     *
     * @return the Sequence object corresponding to the given ID.
     */

    public Sequence getFullSequenceBySequenceID(int seqid) throws SQLException {
	Object obj = hashBySequenceID.get(new Integer(seqid));

	if (obj == null)
	    return loadFullSequenceBySequenceID(seqid);

	Sequence sequence = (Sequence)obj;

	if (sequence.getDNA() == null || sequence.getQuality() == null)
	    getDNAAndQualityForSequence(sequence);

	return sequence;
    }

    private Sequence loadFullSequenceBySequenceID(int seqid) throws SQLException {
	pstmtFullBySequenceID.setInt(1, seqid);
	ResultSet rs = pstmtFullBySequenceID.executeQuery();

	Sequence sequence = null;

	if (rs.next()) {
	    int readid = rs.getInt(1);
	    Read read = adb.getReadManager().getReadByID(readid);
	    int version = rs.getInt(2);
	    int seqlen = rs.getInt(3);
	    byte[] dna = decodeCompressedData(rs.getBytes(4), seqlen);
	    byte[] quality = decodeCompressedData(rs.getBytes(5), seqlen);
	    sequence = registerNewSequence(read, seqid, version, dna, quality);
	}

	rs.close();

	return sequence;
    }

    /**
     * Retrieves the DNA and base quality data for the given Sequence object and sets
     * the corresponding fields of the object.
     *
     * @param sequence the Sequence object whose DNA and base quality data are to be
     * retrieved and set.
     */

    public void getDNAAndQualityForSequence(Sequence sequence) throws SQLException {
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

    private byte[] decodeCompressedData(byte[] compressed, int length) {
	byte[] buffer = new byte[length];

	try {
	    decompresser.setInput(compressed, 0, compressed.length);
	    int truelen = decompresser.inflate(buffer, 0, buffer.length);
	    decompresser.reset();
	}
	catch (DataFormatException dfe) {
	    buffer = null;
	    dfe.printStackTrace();
	}

	return buffer;
    }

    private Sequence registerNewSequence(Read read, int seqid, int version, byte[] dna, byte[] quality) {
	Sequence sequence = new Sequence(read, dna, quality, version);
	sequence.setID(seqid);
	hashByReadID.put(new Integer(read.getID()), sequence);
	hashBySequenceID.put(new Integer(seqid), sequence);
	return sequence;
    }
}
