package uk.ac.sanger.arcturus.samtools;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashSet;
import java.util.Set;
import java.util.zip.DataFormatException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class SAMContigExporter {
	private ArcturusDatabase adb;
	private Connection conn = null;
	
	private final int CONNECTION_VALIDATION_TIMEOUT = 10;
	
	private final int FASTQ_QUALITY_OFFSET = 33;
	
	private static final String GET_ALIGNMENT_DATA =
		" select RN.readname,RN.flags,SC.coffset,SC.direction,CM.cigar,S.seq_id,S.seqlen,S.sequence,S.quality" +
		" from SEQ2CONTIG SC left join (CANONICALMAPPING CM,SEQUENCE S,SEQ2READ SR,READNAME RN) using (mapping_id) " +
		" where SC.contig_id=? and SC.seq_id=S.seq_id and SC.seq_id=SR.seq_id and SR.read_id=RN.read_id";
	
	private PreparedStatement pstmtGetAlignmentData;

	public SAMContigExporter(ArcturusDatabase adb) {
		this.adb = adb;
	}
	
	public void exportContigSet(Set<Contig> contigSet, PrintWriter pw) throws ArcturusDatabaseException {
		pw.println("@PG\tID:" + getClass().getName());
		
		for (Contig contig : contigSet)
			pw.println("@SQ\tSN:Contig" + contig.getID() + "\tLN:" + contig.getLength());
		
		for (Contig contig : contigSet)
			exportContig(contig, pw);
	}
	
	public void exportContig(Contig contig, PrintWriter pw) throws ArcturusDatabaseException {
		if (contig == null)
			throw new ArcturusDatabaseException("Cannot export a null contig");
		
		if (contig.getID() <= 0)
			throw new ArcturusDatabaseException("Canot export a contig without a valid ID");
		
		String contigName = "Contig" + contig.getID();
		
		try {
			checkConnection();
			
			pstmtGetAlignmentData.setInt(1, contig.getID());
			
			ResultSet rs = pstmtGetAlignmentData.executeQuery();
			
			int count = 0;
			
			while (rs.next()) {
				count++;
				writeAlignment(rs, contigName, pw);
			}
			
			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An error occurred when exporting a contig", conn, this);
		}
	}
	
	private void writeAlignment(ResultSet rs, String contigName, PrintWriter pw) throws SQLException, ArcturusDatabaseException {
		int column = 1;
		
		String readname = rs.getString(column++);
		int flags = rs.getInt(column++);
		int contigOffset = rs.getInt(column++);
		String direction = rs.getString(column++);
		String cigar = rs.getString(column++);
		int seq_id = rs.getInt(column++);
		int seqlen = rs.getInt(column++);
		byte[] sequence = rs.getBytes(column++);
		byte[] quality = rs.getBytes(column++);
		
		if (sequence != null) {
			try {
				sequence = Utility.decodeCompressedData(sequence, seqlen);
			} catch (DataFormatException e) {
				Arcturus.logSevere("Failed to decompress DNA for sequence ID=" + seq_id, e);
			}
		} else
			throw new ArcturusDatabaseException("Missing DNA data for sequence ID=" + seq_id);
		
		if (quality != null) {
			try {
				quality = Utility.decodeCompressedData(quality, seqlen);
			} catch (DataFormatException e) {
				Arcturus.logSevere("Failed to decompress quality data for sequence ID=" + seq_id, e);
			}
		} else
			throw new ArcturusDatabaseException("Missing quality data for sequence ID=" + seq_id);
		
		boolean forward = direction.equalsIgnoreCase("Forward");
		
		if (!forward) {
			sequence = Utility.reverseComplement(sequence);
			quality = Utility.reverseQuality(quality);
		}
		
		for (int i = 0; i < quality.length; i++)
			quality[i] += FASTQ_QUALITY_OFFSET;
		
		flags = Utility.maskReadFlags(flags);
		
		if (!forward)
			flags |= 0x0010;
		
		String DNA = null;
		
		try {
			DNA = new String(sequence, "US-ASCII");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}
		
		String qualityString = null;
		
		try {
			qualityString = new String(quality, "US-ASCII");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}
		
		pw.println(readname + " " + flags + " " + contigName + " " + contigOffset + " * " +
				cigar + " * * * " + DNA + " " + qualityString);
	}
	
	private void checkConnection() throws SQLException, ArcturusDatabaseException {
		if (conn != null && conn.isValid(CONNECTION_VALIDATION_TIMEOUT))
			return;
		
		if (conn != null) {
			Arcturus.logInfo("SAMContigExporter: connection was invalid, obtaining a new one");
			conn.close();
		}
		
		prepareConnection();
	}
	
	private void prepareConnection() throws SQLException, ArcturusDatabaseException {
		conn = adb.getPooledConnection(this);
			
		prepareStatements();
	}

	private void prepareStatements() throws SQLException {
		pstmtGetAlignmentData = conn.prepareStatement(GET_ALIGNMENT_DATA, ResultSet.TYPE_FORWARD_ONLY,
	              ResultSet.CONCUR_READ_ONLY);
		
		pstmtGetAlignmentData.setFetchSize(Integer.MIN_VALUE);
	}
	
	public static void main(String[] args) {
		if (args.length < 2) {
			System.err.println("You must supply one or more comma-separated contig numbers and an output file name");
			System.exit(1);
		}
		
		String contigIDs = args[0];
		
		File file = new File(args[1]);
		
		try {
			ArcturusDatabase adb = uk.ac.sanger.arcturus.utils.Utility.getTestDatabase();
			
			String[] words = contigIDs.split(",");
			
			Set<Contig> contigSet = new HashSet<Contig>();
			
			for (String word : words) {
				int contig_id = Integer.parseInt(word);
				
				Contig contig = adb.getContigByID(contig_id);
			
				if (contig != null) {
					System.err.println("Contig " + contig_id + " has " + contig.getReadCount() + " reads");
					contigSet.add(contig);
				} else {
					System.err.println("Contig " + contig_id + " does not exist in the database");
				}			
			}
			
			PrintWriter pw = new PrintWriter(file);
			
			SAMContigExporter exporter = new SAMContigExporter(adb);
			
			exporter.exportContigSet(contigSet, pw);
			
			pw.close();
		}
		catch (IOException ioe) {
			ioe.printStackTrace();
			System.exit(2);
		}
		catch (ArcturusDatabaseException e) {
			e.printStackTrace();
			System.exit(3);
		}
		
		System.exit(0);
	}
	
}
