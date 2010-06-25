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
	
	private static final String GET_ALIGNMENT_DATA = 
		"select seq_id, mapping_id, coffset, roffset, direction" 
	  + "  from SEQ2CONTIG"
	  + " where contig_id = ?"
	  + " order by seq_id";
	private PreparedStatement pstmtGetAlignmentData;

	public ContigComparator(ArcturusDatabase adb) {
		this.adb = adb;
	}
	
	private void prepareConnection() throws SQLException,ArcturusDatabaseException {
		conn = adb.getPooledConnection(this);
		prepareStatement();
	}
	
	private void prepareStatement() throws SQLException {
		pstmtGetAlignmentData = conn.prepareStatement(GET_ALIGNMENT_DATA, ResultSet.TYPE_FORWARD_ONLY,
				ResultSet.CONCUR_READ_ONLY);
	    pstmtGetAlignmentData.setFetchSize(Integer.MIN_VALUE);
	}
	
	public boolean equalsParentContig(Contig contig, Contig parent) throws ArcturusDatabaseException { // better name ?
		boolean equals = false;
		
		if (parent.getID() <= 0)
			return false;
		
		SequenceToContigMapping[] mappings = contig.getSequenceToContigMappings();
		if (mappings == null)
			return false;
	
		// sort mappings according to seq_id

		Arrays.sort(mappings, mappingComparator);
		
		// draw the records from the database one at the time

		try {
			prepareConnection();
			
  		    pstmtGetAlignmentData.setInt(1, parent.getID());		
		    ResultSet rs = pstmtGetAlignmentData.executeQuery();
		    
		    int n = 0;
		    boolean equal = true;
		    while (rs.next()) {
		    	SequenceToContigMapping mapping = mappings[n++];
		    	if (mapping.getSequence().getID() != rs.getInt(1))
		    		equal = false;
		    	if (mapping.getCanonicalMapping().getMappingID() != rs.getInt(2))
		    		equal = false;
		    	if (mapping.getReferenceOffset() != rs.getInt(3))
		    		equal = false;
		    	if (mapping.getSubjectOffset() != rs.getInt(4))
		    		equal = false;
		    	Direction direction = rs.getString(5) == "Forward" ? Direction.FORWARD : Direction.REVERSE;
		    	if (mapping.getDirection() != direction)
		    		equal = false;
		    	if (equal == false)
		    		return false; 
		    }

		    rs.close();
		
		}
		catch (Exception e) {
            return false;
		}
		
	    equals = true;
 	    return equals;
	}

	class MappingComparatorBySequenceID implements Comparator<SequenceToContigMapping> {
		public int compare(SequenceToContigMapping s1, SequenceToContigMapping s2) {
			int diff = s1.getSequence().getID() - s2.getSequence().getID();
			return diff;
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
