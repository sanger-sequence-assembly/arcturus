package uk.ac.sanger.arcturus.readfinder;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.*;

import java.sql.*;
import java.util.zip.DataFormatException;

public class ReadFinder {
	public static final int READ_DOES_NOT_EXIST = 1;
	public static final int READ_IS_FREE = 2;
	public static final int READ_IS_IN_CONTIG = 3;
	
	protected ArcturusDatabase adb;
	private Connection conn;
	
	private PreparedStatement pstmtReadToContig;
	private PreparedStatement pstmtReadNameToID;
	private PreparedStatement pstmtReadNameLikeToID;

	protected ReadFinderEvent event = new ReadFinderEvent();
	
	public ReadFinder(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;
		
		conn = adb.getPooledConnection();

		prepareStatements();
	}

	private void prepareStatements() throws SQLException {
		pstmtReadNameToID = conn.prepareStatement("select read_id from READINFO where readname = ?");
		
		pstmtReadNameLikeToID = conn.prepareStatement(
				"select read_id from READINFO where readname like ? order by readname asc");
		
		pstmtReadToContig = conn
				.prepareStatement("select CURRENTCONTIGS.contig_id,cstart,cfinish,direction"
						+ " from SEQ2READ,MAPPING,CURRENTCONTIGS"
						+ " where SEQ2READ.read_id = ?"
						+ " and SEQ2READ.seq_id = MAPPING.seq_id"
						+ " and MAPPING.contig_id = CURRENTCONTIGS.contig_id");
	}
	
	public void close() throws SQLException {
		if (conn != null)
			conn.close();
		
		conn = null;
	}
	
	protected void finalize() {
		try {
			close();
		}
		catch (SQLException sqle) {}
	}
	
	protected boolean containsWildcards(String str) {
		return str.indexOf("%") >= 0 || str.indexOf("_") >= 0;
	}
	
	public void findRead(String readname, ReadFinderEventListener listener) throws SQLException {
		if (listener != null) {
			event.setPattern(readname);
			event.setStatus(ReadFinderEvent.START);
			listener.readFinderUpdate(event);
		}
		
		if (readname.indexOf('*') >= 0)
			readname = readname.replace('*', '%');
		
		PreparedStatement pstmt = containsWildcards(readname) ? pstmtReadNameLikeToID : pstmtReadNameToID;
	
		pstmt.setString(1, readname);
		
		ResultSet rs = pstmt.executeQuery();
		
		int nreads = 0;
		
		while (rs.next()) {
			nreads++;
			
			int readid = rs.getInt(1);
			
			Read read = adb.getReadByID(readid);
			
			event.setReadAndStatus(read, ReadFinderEvent.READ_IS_FREE);
		
			pstmtReadToContig.setInt(1, readid);
			
			ResultSet rs2 = pstmtReadToContig.executeQuery();
			
			if (rs2.next()) {
				int contigid = rs2.getInt(1);
				int cstart = rs2.getInt(2);
				int cfinish = rs2.getInt(3);
				boolean forward = rs2.getString(4).equalsIgnoreCase("forward");
				
				Contig contig;
				try {
					contig = adb.getContigByID(contigid, ArcturusDatabase.CONTIG_BASIC_DATA);	
					event.setContigAndMapping(read, contig, cstart, cfinish, forward);
				} catch (DataFormatException dfe) {
					Arcturus.logWarning("Error fetching contig data", dfe);
				}
			}
			
			rs2.close();
			
			if (listener != null)
				listener.readFinderUpdate(event);
		}
		
		rs.close();
		
		if (nreads == 0 && listener != null) {
			event.setStatus(ReadFinderEvent.READ_DOES_NOT_EXIST);
			listener.readFinderUpdate(event);
			
			event.setPattern(readname);
			event.setStatus(ReadFinderEvent.START);
			listener.readFinderUpdate(event);
		}
	}
}
