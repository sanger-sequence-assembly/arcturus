package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.text.*;

public class ReadFinder {
	public static final int READ_DOES_NOT_EXIST = 1;
	public static final int READ_IS_FREE = 2;
	public static final int READ_IS_IN_CONTIG = 3;
	
	private Connection conn;
	private PreparedStatement pstmtReadToContig;
	private PreparedStatement pstmtReadInfo;
	
	private final DateFormat formatter = new SimpleDateFormat(
	"yyyy MMM dd HH:mm");
	
	public ReadFinder(ArcturusDatabase adb) throws SQLException {
		conn = adb.getPooledConnection();

		prepareStatements();
	}

	private void prepareStatements() throws SQLException {
		pstmtReadInfo = conn.prepareStatement("select read_id from READINFO where readname = ?");
		
		pstmtReadToContig = conn
				.prepareStatement("select CURRENTCONTIGS.contig_id,gap4name,nreads,length,"
						+ "CURRENTCONTIGS.updated,"
						+ "PROJECT.name,"
						+ "cstart,cfinish,direction"
						+ " from READINFO,SEQ2READ,MAPPING,CURRENTCONTIGS,PROJECT"
						+ " where READINFO.readname = ?"
						+ " and READINFO.read_id = SEQ2READ.read_id"
						+ " and SEQ2READ.seq_id = MAPPING.seq_id"
						+ " and MAPPING.contig_id = CURRENTCONTIGS.contig_id"
						+ " and CURRENTCONTIGS.project_id = PROJECT.project_id");
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

	private int contigid;
	private String gap4name;
	private int nreads;
	private int ctglen;
	private String updated;
	private String projectName;
	private int cstart;
	private int cfinish;
	private String direction;
	private boolean isDataValid = false;
	
	public int findRead(String readname) throws SQLException {
		int status = READ_DOES_NOT_EXIST;
		
		pstmtReadInfo.setString(1, readname);
		
		ResultSet rs = pstmtReadInfo.executeQuery();
		
		if (rs.next())
			status = READ_IS_FREE;
		
		rs.close();
		
		if (status == READ_DOES_NOT_EXIST)
			return status;
		
		pstmtReadToContig.setString(1, readname);
		
		rs = pstmtReadToContig.executeQuery();
		
		if (rs.next()) {
			status = READ_IS_IN_CONTIG;
			contigid = rs.getInt(1);
			gap4name = rs.getString(2);
			nreads = rs.getInt(3);
			ctglen = rs.getInt(4);
			updated = formatter.format(rs.getTimestamp(5));
			projectName = rs.getString(6);
			cstart = rs.getInt(7);
			cfinish = rs.getInt(8);
			direction = rs.getString(9);
			isDataValid = true;
		} else
			isDataValid = false;
		
		rs.close();
		
		return status;
	}
	
	public int getContigID() {
		return isDataValid ? contigid : -1;
	}
	
	public String getGap4Name() {
		return isDataValid ? gap4name : null;
	}
	
	public int getReadCount() {
		return isDataValid ? nreads : -1;
	}
	
	public int getContigLength() {
		return isDataValid ? ctglen : -1;
	}
	
	public String getContigUpdated() {
		return isDataValid ? updated : null;
	}
	
	public String getProjectName() {
		return isDataValid ? projectName : null;
	}
	
	public int getContigStart() {
		return isDataValid ? cstart : -1;
	}
	
	public int getContigFinish() {
		return isDataValid ? cfinish : -1;
	}
	
	public String getDirection() {
		return isDataValid ? direction : null;
	}
}
