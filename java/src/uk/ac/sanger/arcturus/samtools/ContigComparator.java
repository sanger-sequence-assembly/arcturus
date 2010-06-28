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
	
	public boolean equalsParentContig(Contig contig, Contig parent) throws ArcturusDatabaseException {
		if (parent.getID() <= 0)
			return false;
		
		SequenceToContigMapping[] mappings = contig.getSequenceToContigMappings();
		
		if (mappings == null)
			return false;

		Arrays.sort(mappings, mappingComparator);
	    
	    boolean equal = true;

		try {
			checkConnection();
			
  		    pstmtGetAlignmentData.setInt(1, parent.getID());		
		    ResultSet rs = pstmtGetAlignmentData.executeQuery();
		    
		    int n = 0;
		    
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
            adb.handleSQLException(e, "An error occurred when comparing parent and child contigs", conn, this);
		}

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
}
