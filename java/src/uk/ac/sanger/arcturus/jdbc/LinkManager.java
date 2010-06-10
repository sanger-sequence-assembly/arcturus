package uk.ac.sanger.arcturus.jdbc;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.util.*;

public class LinkManager extends AbstractManager {
	private Map<String, Integer> cacheByReadName;

	protected PreparedStatement pstmtSelectReadNamesForCurrentContigs = null;
	protected PreparedStatement pstmtSelectReadNamesForCurrentContigsAndProject = null;
	protected PreparedStatement pstmtSelectCurrentContigForReadName = null;
	
    private static final int BLOCK_LIMIT = 100000;
	
	private static final String LINK_COLUMNS = "readname,flags,read_id,SEQ2CONTIG.contig_id";
	private static final String LINK_TABLES = "(READNAME join " 
	                                        +    "(SEQ2READ join "
	                                        +       "(SEQ2CONTIG join CURRENTCONTIGS using (contig_id))"
                                            +    " using (seq_id))"
                                            + " using (read_id))";
	private static final String SELECT_ALL = "select " + LINK_COLUMNS + " from " + LINK_TABLES;
	private static final String RESTRICT_PROJECT = "project_id = ?";
	private static final String RESTRICT_READ_ID = "read_id > ? order by read_id limit " + BLOCK_LIMIT;
	
	public LinkManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		cacheByReadName = new HashMap<String,Integer>();

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
		pstmtSelectReadNamesForCurrentContigs = 
			conn.prepareStatement(SELECT_ALL + " where " + RESTRICT_READ_ID);
		pstmtSelectReadNamesForCurrentContigsAndProject = 
			conn.prepareStatement(SELECT_ALL + " where " + RESTRICT_PROJECT + " and " + RESTRICT_READ_ID);
        pstmtSelectCurrentContigForReadName = 
        	conn.prepareStatement(SELECT_ALL + " where readname = ?");
    }
	
	static final int FLAG_MASK= 128 + 64 + 1;

	public void preload() throws ArcturusDatabaseException {
		clearCache();
		int lastReadID = 0;

		while (lastReadID >= 0) {
//System.out.println("loading block starting at " + lastReadID);
			try {
	            pstmtSelectReadNamesForCurrentContigs.setInt(1,lastReadID);

	            ResultSet rs = pstmtSelectReadNamesForCurrentContigs.executeQuery();

				lastReadID = -1; // preset end loop
	            while (rs.next()) {
	        	    Read read = new Read(rs.getString(1),rs.getInt(2));
	        	    lastReadID = rs.getInt(3); // activate one further pass through loop
	        	    String readName = read.getUniqueName();
	 		   	    cacheByReadName.put(readName,rs.getInt(4));
			    }
			    rs.close();				
			}
		    catch (SQLException e) {
		        adb.handleSQLException(e,"Failed to build the read-contig cache", conn, adb);
		        
		    }
		}
	}
		
	public void preload(Project project) throws ArcturusDatabaseException {
		clearCache();
		int lastReadID = 0;
		while (lastReadID >= 0) {
			try {
	    		pstmtSelectReadNamesForCurrentContigsAndProject.setInt(1,project.getID());
	            pstmtSelectReadNamesForCurrentContigsAndProject.setInt(2,lastReadID);

	            ResultSet rs = pstmtSelectReadNamesForCurrentContigsAndProject.executeQuery();

				lastReadID = -1; // preset end loop
	            while (rs.next()) {
	        	    Read read = new Read(rs.getString(1),rs.getInt(2));
	        	    lastReadID = rs.getInt(3);
	        	    String readName = read.getUniqueName();
	 		   	    cacheByReadName.put(readName,rs.getInt(4));
			    }
			    rs.close();				
			}
		    catch (SQLException e) {
		        adb.handleSQLException(e,"Failed to build the read-contig cache", conn, adb);
		        
		    }
		}
	}
	
	public int getCurrentContigIDForReadName(String readName) throws ArcturusDatabaseException {
// returns contig_id for input read name      
		if (cacheByReadName.containsKey(readName))
			return cacheByReadName.get(readName);

		else { // probe the database
			try {
		  	    pstmtSelectCurrentContigForReadName.setString(1,readName);
			    ResultSet rs = pstmtSelectCurrentContigForReadName.executeQuery();
			    
			    if (rs.next()) {
	        	    Read read = new Read(rs.getString(1),rs.getInt(2));
	        	    int contig_id = rs.getInt(3);
	           	    String newReadName = read.getUniqueName();
			   	    cacheByReadName.put(newReadName,contig_id);
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
		return "CurrentContigIDsByReadName: " + cacheByReadName.size();
	}

	public Set<String> getCacheKeys() {
		return cacheByReadName.keySet();
	}
}
