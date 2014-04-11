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

package uk.ac.sanger.arcturus.samtools;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;

import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.SequenceToContigMapping;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;
import uk.ac.sanger.arcturus.data.Tag;

public class ContigComparator {
	private ArcturusDatabase adb;
	private Connection conn = null;

	protected MappingComparatorBySequenceID mappingComparator = new MappingComparatorBySequenceID();
	
	private final int CONNECTION_VALIDATION_TIMEOUT = 10;
	
	private static final String GET_ALIGNMENT_DATA = 
		"select seq_id, mapping_id, coffset, roffset, direction from SEQ2CONTIG"
	  + " where contig_id = ?"
	  + " order by seq_id asc";
	
	private PreparedStatement pstmtGetAlignmentData;

	public ContigComparator(ArcturusDatabase adb) {
		this.adb = adb;
	}
	
	private void prepareConnection() throws SQLException,ArcturusDatabaseException {
		conn = adb.getPooledConnection(this);
		prepareStatement();
	}
	
	private void checkConnection() throws SQLException, ArcturusDatabaseException {
		if (conn != null && conn.isValid(CONNECTION_VALIDATION_TIMEOUT))
			return;
		
		if (conn != null) {
			Arcturus.logInfo(getClass().getName() + ": connection was invalid, obtaining a new one");
			conn.close();
		}
		
		prepareConnection();
	}

	private void prepareStatement() throws SQLException {
		pstmtGetAlignmentData = conn.prepareStatement(GET_ALIGNMENT_DATA, ResultSet.TYPE_FORWARD_ONLY,
				ResultSet.CONCUR_READ_ONLY);
		
	    pstmtGetAlignmentData.setFetchSize(Integer.MIN_VALUE);
	}
	
	String printTagSet(Vector<Tag> tagSet) {
		
		String text = "";
		
		if (tagSet != null) {
			Iterator<Tag> iterator = tagSet.iterator();
			
			Tag tag = null;
			
			while (iterator.hasNext()) {
				tag = iterator.next();
				text = text + tag.toSAMString();
			}
		}
		else {
			text = "no tags found for this tag set.";
		}
		return text;
	}
	
	public boolean equalsParentContigTags(Contig contig, Contig parent) throws ArcturusDatabaseException {
		
		boolean equal = true;
		
		reportProgress("ContigComparator: checking if the tags stored in the database match the tags being imported...");
		try {
			checkConnection();
			
			equal = true;
			
			Vector<Tag> newTags= contig.getTags();
			reportProgress("Contig " + contig + " has tags: " + printTagSet(newTags));
			Vector<Tag> oldTags =  parent.getTags();
			reportProgress("Contig " + parent + " has tags: " + printTagSet(oldTags));
			
			if ((newTags == null) && (oldTags ==null)) 
				equal = true;
			else if ((newTags == null) && (oldTags != null))
				equal = false;
			else if ((newTags != null) && (oldTags == null))
				equal = false;
			else
				equal = newTags.equals(oldTags);
			
			reportProgress("ContigComparator: contigs " + contig + " and " + parent + " have " + (equal ? " IDENTICAL" : " DIFFERENT") + " tag sets.");
			
		}
		catch (SQLException e) {
            adb.handleSQLException(e, "ContigComparator: an error occurred when comparing the tags for parent contig and child contigs", conn, this);
		}
		
		return equal;
	}
	
	public boolean equalsParentContig(Contig contig, Contig parent) throws ArcturusDatabaseException {
		reportProgress("ContigComparator: comparing " + contig + " to " + parent);
		
		if (parent.getID() <= 0)
			return false;
		
		SequenceToContigMapping[] mappings = contig.getSequenceToContigMappings();
		
		if (mappings == null) {
			reportProgress("ContigComparator: no mappings for child " + contig + ", bailing out");
			return false;
		}

		Arrays.sort(mappings, mappingComparator);
	    
	    boolean equal = true;
	    
	    int n = 0;

		try {
			checkConnection();
			
  		    pstmtGetAlignmentData.setInt(1, parent.getID());		
		    ResultSet rs = pstmtGetAlignmentData.executeQuery();
		    
		    while (equal && rs.next()) {
		    	SequenceToContigMapping mapping = mappings[n++];
		    	
		    	int parentSequenceID = rs.getInt(1);
		    	int parentMappingID = rs.getInt(2);
		    	int parentReferenceOffset = rs.getInt(3);
		    	int parentSubjectOffset = rs.getInt(4);
		    	Direction parentDirection = rs.getString(5).equalsIgnoreCase("Forward") ?
		    			Direction.FORWARD : Direction.REVERSE;
		    	
		    	if (mapping.getSequence().getID() != parentSequenceID
		    		|| mapping.getCanonicalMapping().getMappingID() != parentMappingID
		    		|| mapping.getReferenceOffset() != parentReferenceOffset
		    		|| mapping.getSubjectOffset() != parentSubjectOffset
		    		|| mapping.getDirection() != parentDirection)
		    		equal = false;
		    }

		    rs.close();	
		}
		catch (SQLException e) {
            adb.handleSQLException(e, "ContigComparator: an error occurred when comparing parent and child contigs", conn, this);
		}
		
		reportProgress("ContigComparator: contigs " + contig + " and " + parent + (equal ? " ARE IDENTICAL" : " DIFFER") + " after " + n + " mappings");

		return equal;
	}

	class MappingComparatorBySequenceID implements Comparator<SequenceToContigMapping> {
		public int compare(SequenceToContigMapping s1, SequenceToContigMapping s2) {
			return s1.getSequence().getID() - s2.getSequence().getID();
		}

		public boolean equals(Object obj) {
			if (obj instanceof MappingComparatorBySequenceID) {
				MappingComparatorBySequenceID that = (MappingComparatorBySequenceID) obj;
				return this == that;
			} else
				return false;
		}
	}
	
	protected void reportProgress(String message) {
		
		boolean testing = false;
		
		if (testing) {
		System.out.println(message);
		}
		Arcturus.logFine(message);
	}
	
}
