package uk.ac.sanger.arcturus.jdbc;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.samtools.Utility;

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
	                                        +    "(SEQ2READ left join "
	                                        +       "(SEQ2CONTIG left join CURRENTCONTIGS using (contig_id))"
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

	public void preload() throws ArcturusDatabaseException {
		clearCache();
		int lastReadID = 0;

		while (lastReadID >= 0) {
System.out.println("loading block starting at " + lastReadID);
			try {
	            pstmtSelectReadNamesForCurrentContigs.setInt(1,lastReadID);

	            ResultSet rs = pstmtSelectReadNamesForCurrentContigs.executeQuery();

				lastReadID = -1; // preset end outer loop
	            while (rs.next()) {
	        	    String readName = rs.getString(1);
	    		    int maskedFlags = Utility.maskReadFlags(rs.getInt(2));
	        	    Read read = new Read(readName,maskedFlags);
	        	    lastReadID = rs.getInt(3); // activate one further pass through outer loop
	 		   	    cacheByReadName.put(read.getUniqueName(),rs.getInt(4));
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
	            	String readName = rs.getString(1);
	    		    int maskedFlags = Utility.maskReadFlags(rs.getInt(2));
	        	    Read read = new Read(readName,maskedFlags);
	        	    lastReadID = rs.getInt(3);
	 		   	    cacheByReadName.put(read.getUniqueName(),rs.getInt(4));
			    }
			    rs.close();				
			}
		    catch (SQLException e) {
		        adb.handleSQLException(e,"Failed to build the read-contig cache", conn, adb);    
		    }
		}
		 
	}
	
	public int getCurrentContigIDForReadName(String uniqueReadName) throws ArcturusDatabaseException {
// returns contig_id for input read name      
		if (cacheByReadName.containsKey(uniqueReadName))
			return cacheByReadName.get(uniqueReadName);

		else { // probe the database
			try {
		  	    pstmtSelectCurrentContigForReadName.setString(1,uniqueReadName);
			    ResultSet rs = pstmtSelectCurrentContigForReadName.executeQuery();
			    
			    if (rs.next()) {
	            	String readName = rs.getString(1);
	    		    int maskedFlags = Utility.maskReadFlags(rs.getInt(2));
	        	    Read read = new Read(readName,maskedFlags);
	        	    int contig_id = rs.getInt(3);
			   	    cacheByReadName.put(read.getUniqueName(),contig_id);
			   	    return contig_id;
			    }
			    rs.close();
			}
			catch (SQLException e) {
				adb.handleSQLException(e,"Failed to test readname in database", conn, adb);
			}
		}
// the read is not in a current contig
		return 0;
	}
	
	public int getCacheSize() {
		return cacheByReadName.size();
	}
	
//two methods for diagnostics during testing
	
	public String getCacheStatistics() {
		return "CurrentContigIDsByReadName: " + cacheByReadName.size();
	}

	public Set<String> getCacheKeys() {
		return cacheByReadName.keySet();
	}
}
