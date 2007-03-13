package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;

public class ReadFinder {	
	private Connection conn;
	private PreparedStatement pstmtReadToContig;

	public ReadFinder(ArcturusDatabase adb) throws SQLException {
		conn = adb.getPooledConnection();

		prepareStatements();
	}

	private void prepareStatements() throws SQLException {
		pstmtReadToContig = conn
				.prepareStatement("select CURRENTCONTIGS.contig_id,gap4name,PROJECT.name,"
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
	private String projectName;
	private int cstart;
	private int cfinish;
	private String direction;
	private boolean isDataValid = false;
	
	public boolean findRead(String readname) throws SQLException {
		pstmtReadToContig.setString(1, readname);
		
		ResultSet rs = pstmtReadToContig.executeQuery();
		
		if (rs.next()) {
			contigid = rs.getInt(1);
			gap4name = rs.getString(2);
			projectName = rs.getString(3);
			cstart = rs.getInt(4);
			cfinish = rs.getInt(5);
			direction = rs.getString(6);
			isDataValid = true;
		} else
			isDataValid = false;
		
		rs.close();
		
		return isDataValid;
	}
	
	public int getContigID() {
		return isDataValid ? contigid : -1;
	}
	
	public String getGap4Name() {
		return isDataValid ? gap4name : null;
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
