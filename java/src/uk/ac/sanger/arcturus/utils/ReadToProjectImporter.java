// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.HashSet;
import java.util.Set;
import java.util.zip.*;

public class ReadToProjectImporter {
	public static final int OK = 0;
	public static final int READNAME_WAS_NULL = 1;
	public static final int READ_ALREADY_IN_CONTIG = 2;
	public static final int READ_NOT_FOUND = 3;
	public static final int FAILED_TO_INSERT_CONTIG = 4;
	public static final int FAILED_TO_INSERT_MAPPING = 5;
	public static final int FAILED_TO_INSERT_SEGMENT = 6;
	public static final int FAILED_TO_INSERT_CONSENSUS = 7;
	public static final int FAILED_TO_VALIDATE_CONTIG = 8;
	public static final int NO_CONNECTION_TO_DATABASE = 9;
	public static final int ZERO_LENGTH = 10; 
	
	private Connection conn;

	private PreparedStatement pstmtReadToContig;
	private PreparedStatement pstmtReadID;
	private PreparedStatement pstmtSequence;
	private PreparedStatement pstmtSeqVector;
	private PreparedStatement pstmtSeqVectorCount;
	private PreparedStatement pstmtQualityClip;
	private PreparedStatement pstmtNewContig;
	private PreparedStatement pstmtValidateContig;
	private PreparedStatement pstmtNewMapping;
	private PreparedStatement pstmtNewSegment;
	private PreparedStatement pstmtNewConsensus;
	
	private Set<PreparedStatement> statements = new HashSet<PreparedStatement>();

	private Inflater decompresser = new Inflater();
	private Deflater compresser = new Deflater(Deflater.BEST_COMPRESSION);

	public ReadToProjectImporter(ArcturusDatabase adb) throws ArcturusDatabaseException {
		conn = adb.getPooledConnection(this);

		try {
			prepareStatements();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the read-to-project importer", conn, this);
		}
	}

	private void prepareStatements() throws SQLException {
		pstmtReadToContig = conn
				.prepareStatement("select CURRENTCONTIGS.contig_id"
						+ " from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS"
						+ " where READINFO.readname = ?"
						+ " and READINFO.read_id = SEQ2READ.read_id"
						+ " and SEQ2READ.seq_id = MAPPING.seq_id"
						+ " and MAPPING.contig_id = CURRENTCONTIGS.contig_id");
		
		statements.add(pstmtReadToContig);

		pstmtReadID = conn
				.prepareStatement("select read_id from READINFO where readname = ?");
		
		statements.add(pstmtReadID);

		pstmtSequence = conn
				.prepareStatement("select seq_id,seqlen,sequence,quality"
						+ " from SEQ2READ left join SEQUENCE using(seq_id)"
						+ " where read_id = ? order by seq_id asc limit 1");
		
		statements.add(pstmtSequence);

		pstmtSeqVector = conn.prepareStatement("select svleft,svright,name"
				+ " from SEQVEC left join SEQUENCEVECTOR using(svector_id)"
				+ " where seq_id = ?");
		
		statements.add(pstmtSeqVector);

		pstmtSeqVectorCount = conn.prepareStatement("select count(*)"
				+ " from SEQVEC left join SEQUENCEVECTOR using(svector_id)"
				+ " where seq_id = ?");
		
		statements.add(pstmtSeqVectorCount);

		pstmtQualityClip = conn
				.prepareStatement("select qleft,qright from QUALITYCLIP where seq_id = ?");
		
		statements.add(pstmtQualityClip);

		pstmtNewContig = conn.prepareStatement(
				"insert into CONTIG(gap4name,length,project_id,created)"
						+ " VALUES(?,?,?,NOW())",
				Statement.RETURN_GENERATED_KEYS);
		
		statements.add(pstmtNewContig);

		pstmtValidateContig = conn
				.prepareStatement("update CONTIG set nreads=1 where contig_id = ?");
		
		statements.add(pstmtValidateContig);

		pstmtNewMapping = conn.prepareStatement(
				"insert into MAPPING(contig_id,seq_id,cstart,cfinish,direction)"
						+ " VALUES(?,?,?,?,'Forward')",
				Statement.RETURN_GENERATED_KEYS);
		
		statements.add(pstmtNewMapping);

		pstmtNewSegment = conn
				.prepareStatement("insert into SEGMENT(mapping_id,cstart,rstart,length)"
						+ " VALUES(?,?,?,?)");
		
		statements.add(pstmtNewSegment);

		pstmtNewConsensus = conn
				.prepareStatement("insert into CONSENSUS(contig_id,sequence,quality,length)"
						+ " VALUES(?,?,?,?)");
		
		statements.add(pstmtNewConsensus);
	}

	public void close() throws SQLException {
		if (conn != null) {
			for (PreparedStatement p : statements)
				p.close();
			
			conn.close();
		}
		
		conn = null;
	}
	
	protected void finalize() {
		try {
			close();
		}
		catch (SQLException sqle) {}
	}

	public int[] makeSingleReadContigs(String[] readnames, int projectid)
			throws SQLException {
		if (readnames == null)
			return null;

		int[] status = new int[readnames.length];

		for (int i = 0; i < readnames.length; i++)
			status[i] = makeSingleReadContig(readnames[i], projectid);

		return status;
	}

	public int makeSingleReadContig(String readname, int projectid)
			throws SQLException {
		if (readname == null)
			return READNAME_WAS_NULL;
		
		if (conn == null)
			return NO_CONNECTION_TO_DATABASE;

		if (isReadAllocated(readname))
			return READ_ALREADY_IN_CONTIG;

		int readid = findReadID(readname);

		if (readid < 0)
			return READ_NOT_FOUND;

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
		
		if (ctglen <= 0)
			return ZERO_LENGTH;

		int contigid = insertNewContig(readname, ctglen, projectid);

		if (contigid < 0)
			return FAILED_TO_INSERT_CONTIG;

		int mappingid = insertNewMapping(contigid, seqid, ctglen);

		if (mappingid < 0)
			return FAILED_TO_INSERT_MAPPING;

		if (!insertSegment(mappingid, rleft, ctglen))
			return FAILED_TO_INSERT_SEGMENT;

		dna = encodeCompressedData(dna, offset, ctglen);
		qual = encodeCompressedData(qual, offset, ctglen);

		if (!insertConsensus(contigid, dna, qual, ctglen))
			return FAILED_TO_INSERT_CONSENSUS;

		if (!validateContig(contigid))
			return FAILED_TO_VALIDATE_CONTIG;

		return OK;
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

	private int insertNewMapping(int contigid, int seqid, int ctglen)
			throws SQLException {
		pstmtNewMapping.setInt(1, contigid);
		pstmtNewMapping.setInt(2, seqid);
		pstmtNewMapping.setInt(3, 1);
		pstmtNewMapping.setInt(4, ctglen);

		if (pstmtNewMapping.executeUpdate() != 1)
			return -1;

		ResultSet rs = pstmtNewMapping.getGeneratedKeys();

		int mappingid = rs.next() ? rs.getInt(1) : -1;

		rs.close();

		return mappingid;
	}

	private boolean insertSegment(int mappingid, int rleft, int ctglen)
			throws SQLException {
		pstmtNewSegment.setInt(1, mappingid);
		pstmtNewSegment.setInt(2, 1);
		pstmtNewSegment.setInt(3, rleft);
		pstmtNewSegment.setInt(4, ctglen);

		return pstmtNewSegment.executeUpdate() == 1;
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

	public String getErrorMessage(int code) {
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

			case FAILED_TO_INSERT_MAPPING:
				return "Failed to insert mapping into database";

			case FAILED_TO_INSERT_SEGMENT:
				return "Failed to insert segment into database";

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
