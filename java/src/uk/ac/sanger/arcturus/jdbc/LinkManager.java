// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.jdbc;

import java.sql.ResultSet;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.Arcturus;
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
	
	private static final String COLUMNS = "RN.readname,RN.flags,CC.contig_id";
	
	private static final String TABLES_BY_READ = "(READNAME RN join " 
	                                        +    "(SEQ2READ SR left join "
	                                        +       "(SEQ2CONTIG SC left join CURRENTCONTIGS CC using (contig_id))"
                                            +    " using (seq_id))"
                                            + " using (read_id))";
	
	private static final String TABLES_BY_PROJECT = 
		"(CURRENTCONTIGS CC left join SEQ2CONTIG SC using (contig_id)),SEQ2READ SR,READNAME RN" +
			" where CC.project_id = ? and SC.seq_id=SR.seq_id and SR.read_id=RN.read_id";
	
	private static final String GET_READ_NAMES_FOR_ALL_CURRENT_CONTIGS =
		"select " + COLUMNS + " from " + TABLES_BY_READ;
	
	private static final String GET_READ_NAMES_FOR_CURRENT_CONTIGS_IN_PROJECT =
		"select " + COLUMNS + " from " + TABLES_BY_PROJECT;
	
	private static final String READ_TO_CONTIG =
		" READNAME RN,SEQ2READ SR,SEQ2CONTIG SC,CURRENTCONTIGS CC"
		+ " where RN.readname = ?" 
		+ " and RN.read_id = SR.read_id"
		+ " and SR.seq_id = SC.seq_id"
		+ " and SC.contig_id = CC.contig_id";

	private static final String GET_CURRENT_CONTIG_FOR_READ_NAME =
		"select " + COLUMNS + " from " + READ_TO_CONTIG;
	
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
			prepareStatement(GET_READ_NAMES_FOR_ALL_CURRENT_CONTIGS, ResultSet.TYPE_FORWARD_ONLY,
		              ResultSet.CONCUR_READ_ONLY);
		
		pstmtSelectReadNamesForCurrentContigs.setFetchSize(Integer.MIN_VALUE);
		
		pstmtSelectReadNamesForCurrentContigsAndProject = 
			prepareStatement(GET_READ_NAMES_FOR_CURRENT_CONTIGS_IN_PROJECT);
		
        pstmtSelectCurrentContigsForReadName = 
        	prepareStatement(GET_CURRENT_CONTIG_FOR_READ_NAME);
    }

	public void preload() throws ArcturusDatabaseException {
		preload(null);
	}
		
	public void preload(Project project) throws ArcturusDatabaseException {
		clearCache();
		
		PreparedStatement pstmt = project == null ? pstmtSelectReadNamesForCurrentContigs :
			pstmtSelectReadNamesForCurrentContigsAndProject;
		
		int count = 0;
		
		try {
			if (project != null)
				pstmt.setInt(1, project.getID());

			ResultSet rs = pstmt.executeQuery();

			while (rs.next()) {
				String readName = rs.getString(1);
				int maskedFlags = Utility.maskReadFlags(rs.getInt(2));

				Read read = new Read(readName, maskedFlags);

				int contig_id = rs.getInt(3);

				Contig currentContig = rs.wasNull() ? null : adb
						.getContigByID(contig_id);

				cacheByReadName.put(read.getUniqueName(), currentContig);
				
				count++;
				if ((count%1000000) == 0)
					Arcturus.logFine("LinkManager.preload: loaded " + count + " read names into cache");
			}

			rs.close();

		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to build the read-contig cache",
					conn, adb);
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

		  	    ResultSet rs = pstmtSelectCurrentContigsForReadName.executeQuery();
			    
                Contig contig = null;
                while (rs.next()) {
	            	String readName = rs.getString(1);
	    		    int maskedFlags = Utility.maskReadFlags(rs.getInt(2));
	    		    
	        	    Read dbread = new Read(readName, maskedFlags);
	        	    
	        	    String dbUniqueReadName = dbread.getUniqueName();
	        	    
	        	    if (!cacheByReadName.containsKey(dbUniqueReadName)) {
	        	    	int contig_id = rs.getInt(3);
	        	    	
	        	    	Contig currentContig = adb.getContigByID(contig_id);
	        	    	
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
