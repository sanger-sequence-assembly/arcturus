package uk.ac.sanger.arcturus.samtools;

import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Set;
import java.util.zip.DataFormatException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.SequenceToContigMapping;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.samtools.SAMContigExporterEvent.Type;

public class SAMContigExporter {
	private ArcturusDatabase adb;
	private Connection conn = null;
	private boolean useGap4Name;
	
	private final int CONNECTION_VALIDATION_TIMEOUT = 10;
	
	private final int FASTQ_QUALITY_OFFSET = 33;
	
	private final int DEFAULT_MAPPING_QUALITY = 255;
	
	private final char TAB = '\t';
	
	private static final String GET_ALIGNMENT_DATA =
		" select RN.readname,RN.flags,SC.coffset,SC.direction,CM.cigar,S.seq_id,S.seqlen,S.sequence,S.quality" +
		" from SEQ2CONTIG SC left join (CANONICALMAPPING CM,SEQUENCE S,SEQ2READ SR,READNAME RN) using (mapping_id) " +
		" where SC.contig_id=? and SC.seq_id=S.seq_id and SC.seq_id=SR.seq_id and SR.read_id=RN.read_id" +
		" order by SC.coffset asc";
	
	private PreparedStatement pstmtGetAlignmentData;
	
	private SAMContigExporterEvent event = new SAMContigExporterEvent(this);
	
	private SAMContigExporterEventListener listener = null;

	public SAMContigExporter(ArcturusDatabase adb, boolean useGap4Name) {
		this.adb = adb;
		this.useGap4Name = useGap4Name;
	}
	
	public void exportContigsForProject(Project project, PrintWriter pw) throws ArcturusDatabaseException {
		if (project == null)
			throw new ArcturusDatabaseException("Cannot export a null project");
		
		Set<Contig> contigSet = adb.getContigsByProject(project.getID(), ArcturusDatabase.CONTIG_BASIC_DATA);
		
		exportContigSet(contigSet, pw);
	}
	
	private String getNameForContig(Contig contig) {
		return useGap4Name ? contig.getName() : "Contig" + contig.getID();
	}
	
	public void exportContigSet(Set<Contig> contigSet, PrintWriter pw) throws ArcturusDatabaseException {
		notifyEvent(Type.START_CONTIG_SET, 0);
		
		pw.println("@PG\tID:" + getClass().getName());
		
		for (Contig contig : contigSet)
			pw.println("@SQ\tSN:" + getNameForContig(contig) + "\tLN:" + contig.getLength());
		
		int count = 0;
		
		for (Contig contig : contigSet) {
			count++;
			
			notifyEvent(Type.START_CONTIG, contig.getID());
			
			exportContig(contig, pw);

			notifyEvent(Type.FINISH_CONTIG, contig.getID());
		}
		
		notifyEvent(Type.FINISH_CONTIG_SET, 0);
	}
	
	public void exportContig(Contig contig, PrintWriter pw) throws ArcturusDatabaseException {
		if (contig == null)
			throw new ArcturusDatabaseException("Cannot export a null contig");
		
		if (contig.getID() <= 0)
			throw new ArcturusDatabaseException("Cannot export a contig without a valid ID");
			
		String contigName = getNameForContig(contig);
		
		try {
			checkConnection();
			
			pstmtGetAlignmentData.setInt(1, contig.getID());
			
			ResultSet rs = pstmtGetAlignmentData.executeQuery();
			
			int count = 0;
			
			notifyEvent(Type.READ_COUNT_UPDATE, count);
			
			while (rs.next()) {
				writeAlignment(rs, contigName, pw);
			
				count++;
				
				if ((count % 10000) == 0)
					notifyEvent(Type.READ_COUNT_UPDATE, count);
			}
			
			rs.close();

			notifyEvent(Type.READ_COUNT_UPDATE, count);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An error occurred when exporting a contig", conn, this);
		}
	}
	  
	protected void reportProgress(String message) {
	    	System.out.println(message);
	    	Arcturus.logInfo(message);
		}
	  
	private int byteArrayToInt(byte [] b) {
        return (b[0] << 24)
                + ((b[1] & 0xFF) << 16)
                + ((b[2] & 0xFF) << 8)
                + (b[3] & 0xFF);
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
				Arcturus.logSevere("writeAlignment: Failed to decompress DNA for sequence ID=" + seq_id, e);
			}
		} else
			throw new ArcturusDatabaseException("writeAlignment: Missing DNA data for sequence ID=" + seq_id);
		
		 if (quality != null) {	 
             try {	 
                     quality = Utility.decodeCompressedData(quality, seqlen);	 
             } catch (DataFormatException e) {	 
                     Arcturus.logSevere("writeAlignment: Failed to decompress quality data for sequence ID=" + seq_id, e);	 
             }	 
		 } else	 
             throw new ArcturusDatabaseException("writeAlignment: Missing quality data for sequence ID=" + seq_id);	 


		boolean forward = direction.equalsIgnoreCase("Forward");
		
		if (!forward) {
			reportProgress("\t\twriteAlignment: reversing sequence and quality");
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
			qualityString = new String(sequence, "US-ASCII");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}
		
		// construct mappingQuality to replace DEFAULT_MAPPING_QUALITY
		
		Sequence thisSequence = adb.getSequenceBySequenceID(seq_id);
		if (thisSequence == null) 
			throw new ArcturusDatabaseException("writeAlignment: Cannot find sequence for sequence ID=" + seq_id);
		
		byte[] byte_mapping_quality = thisSequence.getQuality();
		if (byte_mapping_quality == null) 
			throw new ArcturusDatabaseException("writeAlignment: Cannot get mapping quality for sequence ID=" + seq_id);
		
		int mapping_quality = byteArrayToInt(byte_mapping_quality);
		
		if (mapping_quality > 0) {
			reportProgress("\t\twriteAlignment: got quality of " + mapping_quality + " from database\n");
		} else
			throw new ArcturusDatabaseException("writeAlignment: Missing mapping quality data for sequence ID=" + seq_id);
		
		reportProgress("writeAlignment: Writing line:\n" + readname + TAB + flags + TAB + contigName + TAB + contigOffset +
				TAB + mapping_quality +
				TAB + cigar + TAB + "*\t0\t0\t" + DNA + TAB + qualityString);
		
		pw.println(readname + TAB + flags + TAB + contigName + TAB + contigOffset +
				TAB + mapping_quality +
				TAB + cigar + TAB + "*\t0\t0\t" + DNA + TAB + qualityString);
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
	
	public void setSAMContigExporterEventListener(SAMContigExporterEventListener listener) {
		this.listener = listener;
	}
	
	private void notifyEvent(Type type, int value) {
		if (listener == null)
			return;
		
		event.setTypeAndValue(type, value);
		
		listener.contigExporterUpdate(event);
	}
}
