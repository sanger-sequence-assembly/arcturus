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
	}

	private void prepareStatements() throws SQLException {
		String query = "select R.read_id,S.name from READINFO R left join STATUS S" +
			" on (R.status = S.status_id) where R.readname = ?";

		pstmtReadNameToID = conn.prepareStatement(query);
		
		query = "select R.read_id,S.name from READINFO R left join STATUS S" +
			" on (R.status = S.status_id) where R.readname like ?" +
			" order by readname asc";
		
		pstmtReadNameLikeToID = conn.prepareStatement(query);
		
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
	
	//public boolean isValid(int timeout) {
	//	try {
	//		return conn.isValid(timeout);
	//	}
	//	catch (SQLException e) {
	//		return false;
	//	}
	//}
	
	protected boolean containsWildcards(String str) {
		return str.indexOf("%") >= 0 || str.indexOf("_") >= 0;
	}
	
	public void findRead(String readname, boolean onlyFreeReads, ReadFinderEventListener listener)
		throws SQLException {
		if (conn == null) {
			conn = adb.getPooledConnection(this);
			prepareStatements();
		}

		if (listener != null) {
			event.setPattern(readname);
			event.setReadAndStatus(null, ReadFinderEvent.START);
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
			String status = rs.getString(2);
			
			boolean passed = status != null && status.equalsIgnoreCase("PASS");
			
			Read read = adb.getReadByID(readid);
			
			event.setReadAndStatus(read, ReadFinderEvent.READ_IS_FREE);
		
			pstmtReadToContig.setInt(1, readid);
			
			ResultSet rs2 = pstmtReadToContig.executeQuery();
			
			boolean readIsFree = true;
			
			while (rs2.next()) {
				readIsFree = false;
				
				if (onlyFreeReads)
					break;
				
				int contigid = rs2.getInt(1);
				int cstart = rs2.getInt(2);
				int cfinish = rs2.getInt(3);
				boolean forward = rs2.getString(4).equalsIgnoreCase("forward");
				
				try {
					Contig contig = adb.getContigByID(contigid, ArcturusDatabase.CONTIG_BASIC_DATA);	
					event.setContigAndMapping(read, contig, cstart, cfinish, forward);
					
					if (listener != null)
						listener.readFinderUpdate(event);
				} catch (DataFormatException dfe) {
					Arcturus.logWarning("Error fetching contig data", dfe);
				}
			}
			
			rs2.close();
			
			if (readIsFree && passed && listener != null)
				listener.readFinderUpdate(event);
		}
		
		rs.close();
		
		if (nreads == 0 && listener != null) {
			event.setStatus(ReadFinderEvent.READ_DOES_NOT_EXIST);
			listener.readFinderUpdate(event);
		}
	}
}
