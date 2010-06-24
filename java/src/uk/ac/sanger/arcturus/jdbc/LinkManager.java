package uk.ac.sanger.arcturus.jdbc;

import java.sql.SQLException;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.samtools.Utility;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.util.*;

public class LinkManager extends AbstractManager {
	private Map<String, Contig> cacheByReadName;

	protected PreparedStatement pstmtSelectReadNamesForCurrentContigs = null;
	protected PreparedStatement pstmtSelectReadNamesForCurrentContigsAndProject = null;
	protected PreparedStatement pstmtSelectCurrentContigsForReadName = null;
	
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
	
	private static final String GET_READ_NAMES_FOR_ALL_CURRENT_CONTIGS =
		SELECT_ALL + " where " + RESTRICT_READ_ID;
	
	private static final String GET_READ_NAMES_FOR_CURRENT_CONTIGS_IN_PROJECT =
		SELECT_ALL + " where " + RESTRICT_PROJECT + " and " + RESTRICT_READ_ID;
	
	private static final String GET_CURRENT_CONTIG_FOR_READ_NAME =
		SELECT_ALL + " where readname = ?";
	
	public LinkManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		cacheByReadName = new HashMap<String, Contig>();

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
			conn.prepareStatement(GET_READ_NAMES_FOR_ALL_CURRENT_CONTIGS);
		
		pstmtSelectReadNamesForCurrentContigsAndProject = 
			conn.prepareStatement(GET_READ_NAMES_FOR_CURRENT_CONTIGS_IN_PROJECT);
		
        pstmtSelectCurrentContigsForReadName = 
        	conn.prepareStatement(GET_CURRENT_CONTIG_FOR_READ_NAME);
    }

	public void preload() throws ArcturusDatabaseException {
		preload(null);
	}
		
	public void preload(Project project) throws ArcturusDatabaseException {
		clearCache();
		
		PreparedStatement pstmt = project == null ? pstmtSelectReadNamesForCurrentContigs :
			pstmtSelectReadNamesForCurrentContigsAndProject;
		
		boolean done = false;
		int lastReadID = 0;
		
		while (!done) {
			try {
				if (project == null) {
					pstmt.setInt(1, lastReadID);
				} else {
					pstmt.setInt(1, project.getID());
	            	pstmt.setInt(2, lastReadID);
				}
			
	            ResultSet rs = pstmt.executeQuery();

	            int count = 0;

	            while (rs.next()) {
	            	String readName = rs.getString(1);
	    		    int maskedFlags = Utility.maskReadFlags(rs.getInt(2));
	        	    Read read = new Read(readName, maskedFlags);
	        	    lastReadID = rs.getInt(3);
	        	    Contig currentContig = adb.getContigByID(rs.getInt(4));
	 		   	    cacheByReadName.put(read.getUniqueName(), currentContig);
	 		   	    count++;
			    }
	            
			    rs.close();				
			    
			    done = count == 0;
			}
		    catch (SQLException e) {
		        adb.handleSQLException(e,"Failed to build the read-contig cache", conn, adb);    
		    }
		}		 
	}
	

	public int getCurrentContigIDForRead(Read read) throws ArcturusDatabaseException {
		Contig currentContig = getCurrentContigForRead(read);
		return (currentContig == null) ? 0 : currentContig.getID();
	}
		
		
	public Contig getCurrentContigForRead(Read read) throws ArcturusDatabaseException {
		String uniqueReadName = read.getUniqueName();

		if (cacheByReadName.containsKey(uniqueReadName))
			return cacheByReadName.get(uniqueReadName);
		else {		
			try {
		  	    pstmtSelectCurrentContigsForReadName.setString(1,read.getName());
//		  	    pstmtSelectCurrentContigForReadNameAndFlags.setInt(2,read.getFlags());
			    ResultSet rs = pstmtSelectCurrentContigsForReadName.executeQuery();
//  we pull out all flags, because the masked flags used in cache may not match the database value(s)
			    
                Contig contig = null;
                while (rs.next()) {
	            	String readName = rs.getString(1);
	    		    int maskedFlags = Utility.maskReadFlags(rs.getInt(2));
	        	    Read dbread = new Read(readName, maskedFlags);
	        	    String dbUniqueReadName = dbread.getUniqueName();
	        	    if (!cacheByReadName.containsKey(dbUniqueReadName)) {
	        	    	Contig currentContig = adb.getContigByID(rs.getInt(4));
	        	    	cacheByReadName.put(dbUniqueReadName, currentContig);
	        	    	if (dbUniqueReadName == uniqueReadName)
	        	    		contig = currentContig;
	        	    }
                   
                }
			    rs.close();
		   	    return contig;
			}
			catch (SQLException e) {
				e.printStackTrace();
				adb.handleSQLException(e,"Failed to test readname in database", conn, adb);
			}
		}
		return null;
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
