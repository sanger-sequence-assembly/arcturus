package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

/**
 * 
 * @author ejz
 *
 * This class handles the import and export of (Canonical)Mappings  
 */

public class MappingManager extends AbstractManager {
	private HashMap<Checksum,CanonicalMapping> cacheByChecksum;
	
	protected PreparedStatement pstmtInsertInSequenceToContig = null;
	protected PreparedStatement pstmtInsertInParentToContig = null;
	protected PreparedStatement pstmtInsertInCanonicalMapping = null;
	protected PreparedStatement pstmtInsertInCanonicalSegment = null; // REDUNDENT
	
	protected PreparedStatement pstmtSelectCanonicalMappings = null;
	protected PreparedStatement pstmtSelectCanonicalMappingByID = null;
	protected PreparedStatement pstmtSelectCanonicalMappingByChecksum = null;
	protected PreparedStatement pstmtSelectCanonicalSegment = null; // REDUNDENT
	
	protected PreparedStatement pstmtSelectSequenceToContigMappings = null;
//	protected PreparedStatement pstmtSelect;
//	protected PreparedStatement pstmtSelect;
	
	public MappingManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

        cacheByChecksum = new HashMap<Checksum,CanonicalMapping>();
		
		try {
			setConnection(adb.getDefaultConnection());
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the mapping manager", conn, adb);
		}
	}

	protected void prepareConnection() throws SQLException {
		String query;

// set up prepared statements for importing mappings into the database

		query = "insert into SEQ2CONTIG (contig_id,seq_id,mapping_id,coffset,roffset,direction) "
			  + "values (?,?,?,?,?)";
		pstmtInsertInSequenceToContig = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
		
		query = "insert into PARENT2CONTIG (contig_id,parent_id,mapping_id,coffset,roffset,direction,weight) "
			  + "values (?,?,?,?,?,?,?)";
		pstmtInsertInParentToContig   = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);

		query = "insert into CANONICALMAPPING (cspan,rspan,checksum) values (?,?,?)";
		pstmtInsertInCanonicalMapping = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
		
		query = "insert into CANONICALSEGMENT (mapping_id,cstart,rstart,length) values (?,?,?,?)";
		pstmtInsertInCanonicalSegment = conn.prepareStatement(query); // REDUNDENT

// set up prepared statements for retrieving Canonical Mappings from the database

		query = "select mapping_id,cspan,rspan,checksum from CANONICALMAPPING";
		pstmtSelectCanonicalMappings = conn.prepareStatement(query);
		
		query = "select cspan,rspan,checksum from CANONICALMAPPING where mapping_id = ?";
		pstmtSelectCanonicalMappingByID = conn.prepareStatement(query);
		
		query = "select mapping_id,cspan,rspan from CANONICALMAPPING where checksum = ?";
		pstmtSelectCanonicalMappingByChecksum = conn.prepareStatement(query);
			
		query = "select cstart,rstart,length from CANONICALSEGMENT where mapping_id = ?";
		pstmtSelectCanonicalSegment = conn.prepareStatement(query); // NOT REDUNDENT only apply to regular

// retrieval of Generic Mappings		
		
		query = "select seq_id,SEQ2CONTIG.mapping_id,coffset,roffset,direction,cspan,rspan,checksum"
			  + "  from SEQ2CONTIG join CANONICALMAPPING using (mapping_id)"
			  + " where contig_id = ? order by SEQ2CONTIG.mapping_id";

		pstmtSelectSequenceToContigMappings = conn.prepareStatement(query);
		
// retrieval of mappings old-style
		
		query = "select seq_id,mapping_id,cstart,cfinish,direction"
			  + "  from MAPPING"
			  + " where contig_id = ? order by mapping_id";
		
		query = "select cstart,rstart,length from SEGMENT where mapping_id=?";
	}

/**
 * preload cache with all occurring canonical mappings	`	
 */
	
    public void clearCache() {
    	cacheByChecksum.clear();
    }

    public void preload() throws ArcturusDatabaseException {
        clearCache();
	Utility.report("Building Canonical Mapping hash");
	    try {
	    	ResultSet rs = pstmtSelectCanonicalMappings.executeQuery();
		    
            while (rs.next()) {
            	int mapping_id = rs.getInt(1);
        	    int refSpan = rs.getInt(2);
        	    int subSpan = rs.getInt(3);
        	    byte[] checksumbytes = rs.getBytes(4);
	    	    CanonicalMapping mapping = new CanonicalMapping(mapping_id,refSpan,subSpan,checksumbytes);
	    	    Checksum checksum = new Checksum(mapping.getCheckSum());
		   	    cacheByChecksum.put(checksum,mapping);
		    }
		    rs.close();
	    }
	    catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to build the canonical mapping cache", conn, adb);
	    }
	    
// TO DO preload segments for the most common mapping IDs; requires new methods addSegmentsForCanonicalMappings()
	    // pass array of CMappings in cache; scan to screen against those with segments; add segments for remainder  
    }
    
/**
 * @param CanonicalMapping instance
 * 
 * probe the cache or the database for presence of canonical mapping using the checksum
 *
 * if the mapping is in the cache, return the cache version (includes mapping ID)
 * if not, test the database for new data; if found add ID and add mapping to cache; return
 * add a new Canonical mapping to database and cache
 *  
 * @return a CanonicalMapping instance
 * @throws ArcturusDatabaseException, IllegalArgumentException
 */
	
	public CanonicalMapping findOrStoreCanonicalMapping(CanonicalMapping mapping) throws ArcturusDatabaseException {
		if (mapping == null) 
			throw new IllegalArgumentException("A CanonicalMapping is required as argument");
        byte[] checksumbytes = mapping.getCheckSum();
        if (checksumbytes == null)
			throw new IllegalArgumentException("Incomplete Canonical Mapping: missing checksum, segments");
        
		Checksum checksum = new Checksum(checksumbytes);
		if (cacheByChecksum.containsKey(checksum))
			return cacheByChecksum.get(checksum); // update segments ?
		
		try { // try the database for new data
			pstmtSelectCanonicalMappingByChecksum.setBytes(1,checksumbytes);
			
			ResultSet rs = pstmtSelectCanonicalMappingByChecksum.executeQuery();
			
			if (rs.next()) {
            	mapping.setMappingID(rs.getInt(1));
               	mapping.setReferenceSpan(rs.getInt(2));
               	mapping.setSubjectSpan(rs.getInt(3));
//              mapping.verify();
   		    	rs.close();
   		    	cacheByChecksum.put(checksum,mapping);
   		    	return mapping;
   		    }
			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,"Failed to access database", conn, adb);
		}
// this mapping is not yet in the database; add it; signal failure with return null
		if (mapping.getSegments() == null) // incomplete mapping: no segments
			throw new IllegalArgumentException("Incomplete Canonical Mapping: missing segments");
		boolean success = false;
		try {
			beginTransaction();
			
			pstmtInsertInCanonicalMapping.setInt(1,mapping.getReferenceSpan());
			pstmtInsertInCanonicalMapping.setInt(2,mapping.getSubjectSpan());
			pstmtInsertInCanonicalMapping.setBytes(3,mapping.getCheckSum());
			
			int rc = pstmtInsertInCanonicalMapping.executeUpdate();
			
			if (rc == 1) {
			    ResultSet rs = pstmtInsertInCanonicalMapping.getGeneratedKeys();
			    int inserted_ID = rs.next() ? rs.getInt(1) : 0;
			    rs.close();
			    
			    if (inserted_ID > 0) {
			    	BasicSegment[] segments = mapping.getSegments();
					success = true;
			    	for (int i = 0 ; i < segments.length && success ; i++) {
			    		pstmtInsertInCanonicalSegment.setInt(1,inserted_ID);
			    		pstmtInsertInCanonicalSegment.setInt(2,segments[i].getReferenceStart());
			    		pstmtInsertInCanonicalSegment.setInt(3,segments[i].getSubjectStart());
			    		pstmtInsertInCanonicalSegment.setInt(4,segments[i].getLength());
						
						if (pstmtInsertInCanonicalMapping.executeUpdate() != 1)
							success = false;
			    	}
			    	if (success) { // complete the input mapping
			    		mapping.setMappingID(inserted_ID);
						commitTransaction();
						cacheByChecksum.put(checksum,mapping);
						return mapping;
			    	}
			    }
			}
// something went seriously wrong; throw exception
		    rollbackTransaction();		    
		    adb.handleSQLException(null,"Somehow failed to insert canonical mapping or segment(s)", conn, adb);
		}
		catch (SQLException e) {
            adb.handleSQLException(e,"Failed to insert new Canonical Mapping", conn, adb);
            try {
            	rollbackTransaction();
            }
            catch (Exception f) {
    		    adb.handleSQLException(null,"Somehow failed to insert canonical mapping or segment(s)", conn, adb);
            }
		}
		return null;
    }
	
	public boolean storeSequenceToContigMapping(SequenceToContigMapping mapping) throws ArcturusDatabaseException {

		CanonicalMapping cm = mapping.getCanonicalMapping();
		if (cm == null || cm.getMappingID() < 1)
			throw new IllegalArgumentException("Mapping has no canonical mapping or invalid mapping ID");
		if (mapping.getSequence() == null || mapping.getContig() == null)
			throw new IllegalArgumentException("Mapping has no Sequence or Contig reference");
		
		try {
		    beginTransaction();
            pstmtInsertInSequenceToContig.setInt(1,mapping.getContig().getID());
            pstmtInsertInSequenceToContig.setInt(2,mapping.getSequence().getID());
            pstmtInsertInSequenceToContig.setInt(3,cm.getMappingID());		    
            pstmtInsertInSequenceToContig.setInt(4,mapping.getReferenceOffset());		    
            pstmtInsertInSequenceToContig.setInt(5,mapping.getSubjectOffset());		    
            pstmtInsertInSequenceToContig.setString(6,(mapping.isForward() ? "Forward" : "Reverse"));		    

            if (pstmtInsertInSequenceToContig.executeUpdate() == 1) {
 		        commitTransaction();
 		        return true;
            }
            else {
            	rollbackTransaction();
                adb.handleSQLException(null,"Somehow failed to insert sequence-to-contig mapping", conn, adb);
            }
		}
		catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to insert new Sequence-Contig Mapping", conn, adb);			
	        try {
	            rollbackTransaction();
	        }
	        catch (Exception f) {
	            adb.handleSQLException(null,"Somehow failed to insert sequence-to-contig mapping", conn, adb);
	        }
		}
		return false;
	}
/**
* retrieval of sequence to contig mappings with Canonical Mappings in minimal form
*/
	
	public void addSequenceToContigMappingsToContig(Contig contig) throws ArcturusDatabaseException {
		SequenceToContigMapping[] mappings = null;
		if (contig == null || contig.getID() <= 0) 
		    throw new IllegalArgumentException("Missing contig or invalid contig ID");
		
		try {
 		    pstmtSelectSequenceToContigMappings.setInt(1, contig.getID());
 		    
 		    ResultSet rs = pstmtSelectSequenceToContigMappings.executeQuery();
 		    
 		    int size = rs.getFetchSize();
 		    
 		    mappings = new SequenceToContigMapping[size];
 		    
            int nextmapping = 0;

            while (rs.next()) {
 		    	// identify the canonical mapping;
 		    	CanonicalMapping cmapping = null;
 		    	byte[] checksumbytes = rs.getBytes(8);
    			Checksum checksum = new Checksum(checksumbytes);
    			if (cacheByChecksum.containsKey(checksum))
    				cmapping = cacheByChecksum.get(checksum);
    			else {
    				int mapping_id = rs.getInt(2);
    	       	    int refSpan = rs.getInt(6);
            	    int subSpan = rs.getInt(7);
 		    		cmapping = new CanonicalMapping(mapping_id,refSpan,subSpan,checksumbytes);
 				    cacheByChecksum.put(checksum,cmapping);
 		    	}
   			    // build a minimal Sequence instance and complete the sequence-to-contig mapping
    			Sequence sequence = new Sequence(rs.getInt(1));
    			Direction direction = (rs.getString(5) == "Forward") ? Direction.FORWARD 
    					                                             : Direction.REVERSE;
    			int refOffset = rs.getInt(3);
    			int subOffset = rs.getInt(4);
                mappings[nextmapping++] = new SequenceToContigMapping(sequence,contig,cmapping,
                		                                           refOffset,subOffset,direction);
 		    }
            rs.close();	
		}
		catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to retrieve Sequence-Contig Mappings", conn, adb);			
		}
		
// TO DO here add segments to the mappings if so specified
		
//		contig.setMappings(mappings);  change BasicSequenceToContigMapping?
	}
	
// REDUNDENT Canonical Mappings have cigar string as checksum	pstmtSelectCanonicalSegment 
	
	public void addCanonicalSegmentsToCanonicalMapping(CanonicalMapping mapping)  throws ArcturusDatabaseException {
		if (mapping == null || mapping.getMappingID() <= 0) 
		    throw new IllegalArgumentException("Missing canonical mapping or invalid mapping ID");
		try {
			pstmtSelectCanonicalSegment.setInt(1, mapping.getMappingID());
			
			ResultSet rs = pstmtSelectCanonicalSegment.executeQuery();
			
			int size = rs.getFetchSize();
			
			BasicSegment[] segment = new BasicSegment[size];
			
			int ns = 0;
	        while (rs.next()) {
	        	int referenceStart = rs.getInt(1);
	        	int subjectStart  = rs.getInt(2);
	        	int segmentLength = rs.getInt(3);
	        	segment[ns++] = new BasicSegment(referenceStart,subjectStart,segmentLength);
	        }
	        mapping.setSegments(segment);
	    }
		catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to retrieve CanonicalMapping segment(s)", conn, adb);			
		}
	}
	
	public void addMappingsToContig(Contig contig) {
		// read mappings from MAPPING table (OLD REPRESENTATION)
		// build SequenceToContigMappings from that (NEEDS a temporary mapping_id field?) + SEGMENTS
		// but using the Canonical Representation internally.
    }
	
	public void addSegmentsToMapping(GenericMapping mappings) { // SEE perl code
	    // 
	}
	
/**
* internal class provides hash key code for canonical mapping cache from checksum
*/
	
	class Checksum {
		byte[] data;
		
		Checksum(byte[] data) {
			this.data = data;
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
			if (this.data == null || that == null || that.data == null || this.data.length != that.data.length)
				return false;
			for (int i = 0 ; i < data.length ; i++) {
				if (this.data[i] != that.data[i]) 
					return false;
			}
			return true;
		}
	}
}
