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

package uk.ac.sanger.arcturus.siblingreadfinder;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;

import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.siblingreadfinder.SiblingReadFinderEvent.Status;

public class SiblingReadFinder {
	protected ArcturusDatabase adb;
	protected Connection conn;
	
	private final int CONNECTION_VALIDATION_TIMEOUT = 10;
	
	private static final String SQL_LIST_TEMPLATES_FOR_PROJECT =
		"select distinct RI.template_id,RI.strand" +
    	" from ((CURRENTCONTIGS CC left join MAPPING M using(contig_id))" +
    	" left join SEQ2READ using (seq_id)) left join READINFO RI using (read_id)" +
    	" where CC.project_id = ? and RI.asped is not null and RI.strand is not null and RI.template_id > 0";
	
	private static final String SQL_LIST_READS_FOR_TEMPLATE =
		"select readname from READINFO where template_id = ? and strand = ?";
	
	private static final String SQL_LIST_TEMPLATES_FROM_BOTH_STRANDS_FOR_PROJECT =
		"select distinct RI.template_id,'both'" +
    	" from ((CURRENTCONTIGS CC left join MAPPING M using(contig_id))" +
    	" left join SEQ2READ using (seq_id)) left join READINFO RI using (read_id)" +
    	" where CC.project_id = ? and RI.asped is not null and RI.strand is not null and RI.template_id > 0";
	
	private static final String SQL_LIST_READS_FROM_BOTH_STRANDS_FOR_TEMPLATE =
		"select readname from READINFO where template_id = ?";
	
	private static final String SQL_CURRENT_CONTIG_FOR_READ =
		"select CC.contig_id from READINFO RI left join" +
		" (SEQ2READ SR, MAPPING M, CURRENTCONTIGS CC) using (read_id)" +
		" where RI.readname = ? and SR.seq_id=M.seq_id and M.contig_id=CC.contig_id";

	protected PreparedStatement pstmtListTemplatesForProject;
	protected PreparedStatement pstmtListReadsForTemplate;
	protected PreparedStatement pstmtListTemplatesFromBothStrandsForProject;
	protected PreparedStatement pstmtListReadsFromBothStrandsForTemplate;
	protected PreparedStatement pstmtCurrentContigForRead;
	
	protected SiblingReadFinderEventListener listener;
	protected SiblingReadFinderEvent event = new SiblingReadFinderEvent();
	
	public SiblingReadFinder(ArcturusDatabase adb) {
		this.adb = adb;
	}
	
	public void setListener(SiblingReadFinderEventListener listener) {
		this.listener = listener;
	}
	
	private void checkConnection() throws SQLException, ArcturusDatabaseException {
		if (conn != null && conn.isValid(CONNECTION_VALIDATION_TIMEOUT))
			return;
		
		if (conn != null) {
			Arcturus.logInfo("ReadFinder: connection was invalid, obtaining a new one");
			conn.close();
		}
		
		prepareConnection();
	}

	private void prepareConnection() throws SQLException, ArcturusDatabaseException {
		conn = adb.getPooledConnection(this);

		pstmtListTemplatesForProject = conn.prepareStatement(SQL_LIST_TEMPLATES_FOR_PROJECT);

		pstmtListReadsForTemplate = conn.prepareStatement(SQL_LIST_READS_FOR_TEMPLATE);
		
		pstmtListTemplatesFromBothStrandsForProject = conn.prepareStatement(SQL_LIST_TEMPLATES_FROM_BOTH_STRANDS_FOR_PROJECT);

		pstmtListReadsFromBothStrandsForTemplate = conn.prepareStatement(SQL_LIST_READS_FROM_BOTH_STRANDS_FOR_TEMPLATE);

		pstmtCurrentContigForRead = conn.prepareStatement(SQL_CURRENT_CONTIG_FOR_READ);
	}

	public void close() throws ArcturusDatabaseException {
		if (conn != null)
			try {
				conn.close();
			} catch (SQLException e) {
				throw new ArcturusDatabaseException(e,
						"An error occurred when trying to close the ReadFinder's database connection", conn, adb);
			}

		conn = null;
	}

	protected void finalize() {
		try {
			close();
		} catch (ArcturusDatabaseException e) {
			Arcturus.logWarning("An error occurred when finalizing the ReadFinder", e);
		}
	}
	
	class TemplateAndStrand {
		private int template_id;
		private String strand;
		
		public TemplateAndStrand(int template_id, String strand) {
			this.template_id = template_id;
			this.strand = strand;
		}
		
		public int getTemplateID() {
			return template_id;
		}
		
		public String getStrand() {
			return strand;
		}
	}

	public Set<String> getSiblingReadnames(Project project, Pattern omitNamesLike, boolean bothStrands)
		throws ArcturusDatabaseException {
		if (project == null)
			return null;
		
		Set<String> names = new HashSet<String>();
		
		try {
			checkConnection();
			
			if (listener != null) {
				event.setStatus(Status.STARTED);
				listener.siblingReadFinderUpdate(event);
			}
			
			Set<TemplateAndStrand> templates = new HashSet<TemplateAndStrand>();
			
			PreparedStatement pstmt = bothStrands ?
					pstmtListTemplatesFromBothStrandsForProject : pstmtListTemplatesForProject;
			
			pstmt.setInt(1, project.getID());
			
			ResultSet rs = pstmt.executeQuery();
			
			while (rs.next()) {
				TemplateAndStrand tands = new TemplateAndStrand(rs.getInt(1), rs.getString(2));
				templates.add(tands);
			}
			
			rs.close();
			
			if (listener != null) {
				event.setStatus(Status.COUNTED_SUBCLONES);
				event.setValue(templates.size());
				listener.siblingReadFinderUpdate(event);
			}
		
			Set<String> readnames = new HashSet<String>();
			
			event.setStatus(Status.IN_PROGRESS);
			
			int count = 0;
			
			pstmt = bothStrands ? pstmtListReadsFromBothStrandsForTemplate : pstmtListReadsForTemplate;
			
			for (TemplateAndStrand tands : templates) {
				readnames.clear();
				
				pstmt.setInt(1, tands.getTemplateID());
				
				if (!bothStrands)
					pstmt.setString(2, tands.getStrand());
				
				rs = pstmt.executeQuery();
				
				while (rs.next())
					readnames.add(rs.getString(1));
				
				rs.close();
				
				for (String readname : readnames) {
					if (isFree(readname)) {
						boolean matchesPattern =
							omitNamesLike != null && omitNamesLike.matcher(readname).find();
						
						if (!matchesPattern)
							names.add(readname);
					}
				}
				
				if (listener != null) {
					count++;
					event.setValue(count);
					listener.siblingReadFinderUpdate(event);
				}
			}
			
			if (listener != null) {
				event.setStatus(Status.FINISHED);
				event.setValue(names.size());
				listener.siblingReadFinderUpdate(event);
			}		
		}
		catch (SQLException e) {
			throw new ArcturusDatabaseException(e, conn);
		}
		
		return names;
	}

	private boolean isFree(String readname) throws SQLException {
		pstmtCurrentContigForRead.setString(1, readname);
		
		ResultSet rs = pstmtCurrentContigForRead.executeQuery();
		
		boolean inContig = rs.next();
		
		rs.close();
		
		return !inContig;
	}
}
