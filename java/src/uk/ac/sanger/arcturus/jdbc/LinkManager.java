package uk.ac.sanger.arcturus.jdbc;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
//import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

public class LinkManager extends AbstractManager {
	private HashMap<Checksum, Integer> cacheByReadName;

	protected PreparedStatement pstmtSelectReadNamesForCurrentContigs = null;
	protected PreparedStatement pstmtSelectReadNamesForCurrentContigsAndProject = null;
	protected PreparedStatement pstmtSelectCurrentContigForReadName = null;

	
	public LinkManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		cacheByReadName = new HashMap<Checksum,Integer>();

		try {
			setConnection(adb.getDefaultConnection());
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the contig manager", conn, adb);
		}
	}

	public void clearCache() {
		cacheByReadName.clear();
	}

	protected void prepareConnection() throws SQLException {
		String query;
		
		String subQuery = "select contig_id from CURRENTCONTIGS";
		
		query = "select readname,flags,contig_id"
			  + "  from READNAME,SEQ2READ,SEQ2CONTIG"
              + " where READNAME.read_id = SEQ2READ.read_id"
              + "   and SEQ2READ.seq_id = SEQ2CONTIG.seq_id"
              + "   and contig_id in (" + subQuery + ")";
		pstmtSelectReadNamesForCurrentContigs = conn.prepareStatement(query);
		
		subQuery += " and project_id in ?";

		query = "select readname,flags,contig_id"
			  + "  from READNAME,SEQ2READ,SEQ2CONTIG"
            + " where READNAME.read_id = SEQ2READ.read_id"
            + "   and SEQ2READ.seq_id = SEQ2CONTIG.seq_id"
            + "   and contig_id in (" + subQuery + ")";
		pstmtSelectReadNamesForCurrentContigsAndProject = conn.prepareStatement(query);
		
        query = "select readname,flags,contig_id"	
        	  + "  from (READNAME join SEQ2READ using (read_id)) join SEQ2CONTIG"; // FIX
        pstmtSelectCurrentContigForReadName = conn.prepareStatement(query);
    }
	
	static final int FLAG_MASK= 128 + 64 + 1;

	public void preload() throws ArcturusDatabaseException {
	    preload(null);
	}
		
	public void preload(Project project) throws ArcturusDatabaseException {
		clearCache();
	    try {
	    	ResultSet rs;
	    	if (project == null) 
 	            rs = pstmtSelectReadNamesForCurrentContigs.executeQuery();
	    	else {
	    		pstmtSelectReadNamesForCurrentContigsAndProject.setInt(1,project.getID());
	    		rs = pstmtSelectReadNamesForCurrentContigsAndProject.executeQuery();
	    	}
		    
            while (rs.next()) {
        	    int flags = rs.getInt(2) & FLAG_MASK;
        	    Read read = new Read(rs.getString(1),flags);
 		   	    cacheByReadName.put(new Checksum(read.getUniqueName()),rs.getInt(3));
		    }
		    rs.close();
	    }
	    catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to build the read-contig cache", conn, adb);
	    }
	}
	
	public int getCurrentContigIDForReadName(String readName) throws ArcturusDatabaseException {
// returns contig_id for input read name      
		Checksum checksum = new Checksum(readName);
		if (cacheByReadName.containsKey(checksum))
			return cacheByReadName.get(checksum);
		else { // probe the database
			try {
		  	    pstmtSelectCurrentContigForReadName.setString(1,readName);
			    ResultSet rs = pstmtSelectCurrentContigForReadName.executeQuery();
			    
			    if (rs.next()) {
	        	    int flags = rs.getInt(2) & FLAG_MASK;
	        	    Read read = new Read(rs.getString(1),flags);
	        	    int contig_id = rs.getInt(3);
			   	    cacheByReadName.put(new Checksum(read.getUniqueName()),contig_id);
			   	    return contig_id;
			    }
			}
			catch (SQLException e) {
				adb.handleSQLException(e,"Failed to test readname in database", conn, adb);
			}
		}
// the read is not in a current contig
		return 0;
	}
	
	public String getCacheStatistics() {
		return "ByID: " + cacheByReadName.size();
	}
	
/**
* internal class provides hash key code for (long) readname-contig ID cache from read name
*/
		
	class Checksum {
		
		byte[] data;
		String name;
			
		Checksum(String readName) {
			// constructor stores both readname and a hash of up to 16 bytes; 
			this.name = readName;
			if (readName.length() >= 16)
			    this.data = Utility.calculateMD5Hash(readName);
			else
		        this.data = readName.getBytes();
	    }
			
		public int hashCode() {	
			if (data == null)
				return 0;
			int hashcode = 0;
			for (int i = 1 ; i <= 4 ; i++) {
				hashcode += data[i];
				hashcode = hashcode << 3;
			}
			return hashcode;
		}
			
		public boolean equals(Checksum that) {
			if (this.data == null || that == null)
				return false;
			else if (this.name == that.name)
				return true;
			else 
				return false;
		}
	}
}
