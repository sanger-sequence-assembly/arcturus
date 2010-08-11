package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.jdbc.ArcturusDatabaseClient;

import java.sql.*;
import java.util.HashSet;
import java.util.Set;
import java.util.zip.*;

public class ReadToProjectImporter extends ArcturusDatabaseClient {
	public enum Status {
		OK, READNAME_WAS_NULL, READ_ALREADY_IN_CONTIG,
		READ_NOT_FOUND, FAILED_TO_INSERT_CONTIG, FAILED_TO_INSERT_CANONICAL_MAPPING,
		FAILED_TO_INSERT_SEQUENCE_TO_CONTIG_LINK, FAILED_TO_INSERT_CONSENSUS, FAILED_TO_VALIDATE_CONTIG,
		NO_CONNECTION_TO_DATABASE, ZERO_LENGTH
	}
	
	private Connection conn;

	private PreparedStatement pstmtReadToContig;
	private PreparedStatement pstmtReadID;
	private PreparedStatement pstmtSequence;
	private PreparedStatement pstmtSeqVector;
	private PreparedStatement pstmtSeqVectorCount;
	private PreparedStatement pstmtQualityClip;
	private PreparedStatement pstmtNewContig;
	private PreparedStatement pstmtValidateContig;
	private PreparedStatement pstmtNewSequenceToContigLink;
	private PreparedStatement pstmtFindCanonicalMapping;
	private PreparedStatement pstmtNewCanonicalMapping;
	private PreparedStatement pstmtNewConsensus;

	private Inflater decompresser = new Inflater();
	private Deflater compresser = new Deflater(Deflater.BEST_COMPRESSION);

	public ReadToProjectImporter(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);
		
		try {
			setConnection(adb.getPooledConnection(this));
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the read-to-project importer", conn, this);
		}
	}

	protected void prepareConnection() throws SQLException {
		pstmtReadToContig = prepareStatement("select CURRENTCONTIGS.contig_id"
						+ " from READNAME,SEQ2READ,SEQ2READ,CURRENTCONTIGS"
						+ " where READNAME.readname = ?"
						+ " and READNAME.read_id = SEQ2READ.read_id"
						+ " and SEQ2READ.seq_id = SEQ2READ.seq_id"
						+ " and SEQ2READ.contig_id = CURRENTCONTIGS.contig_id");

		pstmtReadID = prepareStatement("select read_id from READNAME where readname = ?");

		pstmtSequence = prepareStatement("select seq_id,seqlen,sequence,quality"
						+ " from SEQ2READ left join SEQUENCE using(seq_id)"
						+ " where read_id = ? order by seq_id asc limit 1");

		pstmtSeqVector = prepareStatement("select svleft,svright,name"
				+ " from SEQVEC left join SEQUENCEVECTOR using(svector_id)"
				+ " where seq_id = ?");

		pstmtSeqVectorCount = prepareStatement("select count(*)"
				+ " from SEQVEC left join SEQUENCEVECTOR using(svector_id)"
				+ " where seq_id = ?");

		pstmtQualityClip = prepareStatement("select qleft,qright from QUALITYCLIP where seq_id = ?");

		pstmtNewContig = prepareStatement(
				"insert into CONTIG(gap4name,length,project_id,created)"
						+ " VALUES(?,?,?,NOW())",
				Statement.RETURN_GENERATED_KEYS);

		pstmtValidateContig = prepareStatement("update CONTIG set nreads=1 where contig_id = ?");

		pstmtNewSequenceToContigLink = prepareStatement(
				"insert into SEQ2CONTIG(mapping_id,contig_id,seq_id,coffset,roffset,direction)"
						+ " VALUES(?,?,?,1,?,'Forward')",
				Statement.RETURN_GENERATED_KEYS);
		
		pstmtFindCanonicalMapping = prepareStatement("select mapping_id from CANONICALMAPPING where cigar = ?");
		
		pstmtNewCanonicalMapping = prepareStatement("insert into CANONICALMAPPING(cspan,rspan,cigar)"
						+ " VALUES(?,?,?)", Statement.RETURN_GENERATED_KEYS);

		pstmtNewConsensus = prepareStatement("insert into CONSENSUS(contig_id,sequence,quality,length)"
						+ " VALUES(?,?,?,?)");
	}
	
	protected void finalize() {
		try {
			close();
		}
		catch (SQLException sqle) {}
	}

	public Status[] makeSingleReadContigs(String[] readnames, int projectid)
			throws SQLException {
		if (readnames == null)
			return null;

		Status[] status = new Status[readnames.length];

		for (int i = 0; i < readnames.length; i++)
			status[i] = makeSingleReadContig(readnames[i], projectid);

		return status;
	}

	public Status makeSingleReadContig(String readname, int projectid)
			throws SQLException {
		if (readname == null)
			return Status.READNAME_WAS_NULL;
		
		if (conn == null)
			return Status.NO_CONNECTION_TO_DATABASE;

		if (isReadAllocated(readname))
			return Status.READ_ALREADY_IN_CONTIG;

		int readid = findReadID(readname);

		if (readid < 0)
			return Status.READ_NOT_FOUND;

		beginTransaction();
		
		pstmtSequence.setInt(1, readid);

		ResultSet rs = pstmtSequence.executeQuery();

		rs.next();

		int seqid = rs.getInt(1);
		int seqlen = rs.getInt(2);
		byte[] dna = decodeCompressedData(rs.getBytes(3), seqlen);
		byte[] qual = decodeCompressedData(rs.getBytes(4), seqlen);

		int qclip[] = getQualityClip(seqid);

		int svclip[][] = getSeqVectorClip(seqid);

		int rleft = (qclip == null) ? 1 : qclip[0] + 1;

		int rright = (qclip == null) ? seqlen : qclip[1] - 1;

		if (svclip != null) {
			for (int i = 0; i < svclip.length; i++) {
				int svleft = svclip[i][0];
				int svright = svclip[i][1];

				if (svleft == 1 && svright > rleft)
					rleft = svright + 1;

				if (svleft > 1 && svleft < rright)
					rright = svleft;
			}
		}

		int offset = rleft - 1;
		int ctglen = rright - rleft + 1;
		
		if (ctglen <= 0) {
			rollbackTransaction();
			return Status.ZERO_LENGTH;
		}

		int contigid = insertNewContig(readname, ctglen, projectid);

		if (contigid < 0) {
			rollbackTransaction();
			return Status.FAILED_TO_INSERT_CONTIG;
		}
		
		String cigar = ctglen + "M";
		
		int mappingid = findOrCreateCanonicalMapping(cigar);

		if (mappingid < 0) {
			rollbackTransaction();
			return Status.FAILED_TO_INSERT_CANONICAL_MAPPING;
		}
		
		boolean success = insertSequenceToContigLink(mappingid, contigid, seqid, offset);
		
		if (!success) {
			rollbackTransaction();
			return Status.FAILED_TO_INSERT_SEQUENCE_TO_CONTIG_LINK;
		}
		
		dna = encodeCompressedData(dna, offset, ctglen);
		qual = encodeCompressedData(qual, offset, ctglen);

		if (!insertConsensus(contigid, dna, qual, ctglen)) {
			rollbackTransaction();
			return Status.FAILED_TO_INSERT_CONSENSUS;
		}

		if (!validateContig(contigid)) {
			rollbackTransaction();
			return Status.FAILED_TO_VALIDATE_CONTIG;
		}
		
		commitTransaction();
		
		return Status.OK;
	}

	private boolean isReadAllocated(String readname) throws SQLException {
		pstmtReadToContig.setString(1, readname);

		ResultSet rs = pstmtReadToContig.executeQuery();

		boolean isAllocated = rs.next() && rs.getInt(1) > 0;

		rs.close();

		return isAllocated;
	}

	private int findReadID(String readname) throws SQLException {
		pstmtReadID.setString(1, readname);

		ResultSet rs = pstmtReadID.executeQuery();

		int readid = rs.next() ? rs.getInt(1) : -1;

		rs.close();

		return readid;
	}

	private byte[] decodeCompressedData(byte[] compressed, int length) {
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

	private byte[] encodeCompressedData(byte[] raw, int offset, int length) {
		byte[] buffer = new byte[12 + (5 * length) / 4];

		compresser.reset();
		compresser.setInput(raw, offset, length);
		compresser.finish();

		int compressedSequenceLength = compresser.deflate(buffer);

		byte[] compressedSequence = new byte[compressedSequenceLength];

		for (int i = 0; i < compressedSequenceLength; i++)
			compressedSequence[i] = buffer[i];

		return compressedSequence;
	}

	private int[] getQualityClip(int seqid) throws SQLException {
		pstmtQualityClip.setInt(1, seqid);

		ResultSet rs = pstmtQualityClip.executeQuery();

		int[] qclip = null;

		if (rs.next()) {
			qclip = new int[2];
			qclip[0] = rs.getInt(1);
			qclip[1] = rs.getInt(2);
		}

		rs.close();

		return qclip;
	}

	private int[][] getSeqVectorClip(int seqid) throws SQLException {
		pstmtSeqVectorCount.setInt(1, seqid);

		ResultSet rs = pstmtSeqVectorCount.executeQuery();

		int svcount = rs.next() ? rs.getInt(1) : 0;

		rs.close();

		if (svcount == 0)
			return null;

		int[][] svclip = new int[svcount][2];

		pstmtSeqVector.setInt(1, seqid);

		rs = pstmtSeqVector.executeQuery();

		for (int i = 0; i < svcount; i++) {
			rs.next();
			svclip[i][0] = rs.getInt(1);
			svclip[i][1] = rs.getInt(2);
		}

		rs.close();

		return svclip;
	}

	private int insertNewContig(String readname, int ctglen, int projectid)
			throws SQLException {
		pstmtNewContig.setString(1, readname);
		pstmtNewContig.setInt(2, ctglen);
		pstmtNewContig.setInt(3, projectid);

		if (pstmtNewContig.executeUpdate() != 1)
			return -1;

		ResultSet rs = pstmtNewContig.getGeneratedKeys();

		int contigid = rs.next() ? rs.getInt(1) : -1;

		rs.close();

		return contigid;
	}

	private boolean insertSequenceToContigLink(int mappingid, int contigid,
			int seqid, int offset) throws SQLException {
		pstmtNewSequenceToContigLink.setInt(1, mappingid);
		pstmtNewSequenceToContigLink.setInt(2, contigid);
		pstmtNewSequenceToContigLink.setInt(3, seqid);
		pstmtNewSequenceToContigLink.setInt(4, offset);
		
		int rc = pstmtNewSequenceToContigLink.executeUpdate();
		
		return rc == 1;
	}

	private int findOrCreateCanonicalMapping(String cigar) throws SQLException {
		pstmtFindCanonicalMapping.setString(1, cigar);
		
		ResultSet rs = pstmtFindCanonicalMapping.executeQuery();
		
		int mappingid = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		if (mappingid > 0)
			return mappingid;
		
		int len = cigar.length();
		
		pstmtNewCanonicalMapping.setInt(1, len);
		pstmtNewCanonicalMapping.setInt(2, len);
		pstmtNewCanonicalMapping.setString(3, cigar);
		
		int rc = pstmtNewCanonicalMapping.executeUpdate();
		
		if (rc != 1)
			return -1;
		
		rs = pstmtNewCanonicalMapping.getGeneratedKeys();
		
		mappingid = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		return mappingid;
	}

	private boolean insertConsensus(int contigid, byte[] dna, byte[] qual,
			int ctglen) throws SQLException {
		pstmtNewConsensus.setInt(1, contigid);
		pstmtNewConsensus.setBytes(2, dna);
		pstmtNewConsensus.setBytes(3, qual);
		pstmtNewConsensus.setInt(4, ctglen);

		return pstmtNewConsensus.executeUpdate() == 1;
	}

	private boolean validateContig(int contigid) throws SQLException {
		pstmtValidateContig.setInt(1, contigid);

		return pstmtValidateContig.executeUpdate() == 1;
	}

	public String getErrorMessage(Status code) {
		switch (code) {
			case OK:
				return "OK";

			case READNAME_WAS_NULL:
				return "Readname was null";

			case READ_ALREADY_IN_CONTIG:
				return "The read is already in a contig";

			case READ_NOT_FOUND:
				return "The read was not found";

			case FAILED_TO_INSERT_CONTIG:
				return "Failed to insert contig into database";

			case FAILED_TO_INSERT_CANONICAL_MAPPING:
				return "Failed to insert canonical mapping into database";

			case FAILED_TO_INSERT_SEQUENCE_TO_CONTIG_LINK:
				return "Failed to insert sequence-to-contig link into database";

			case FAILED_TO_INSERT_CONSENSUS:
				return "Failed to insert consensus into database";

			case FAILED_TO_VALIDATE_CONTIG:
				return "Failed to validate contig";
				
			case NO_CONNECTION_TO_DATABASE:
				return "No connection to database";
				
			case ZERO_LENGTH:
				return "The read had zero length after clipping";

			default:
				return "Unknown error code [" + code + "]";
		}
	}
}
