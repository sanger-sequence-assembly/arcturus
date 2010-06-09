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
	
	protected PreparedStatement pstmtSelectCanonicalMappings = null;
	protected PreparedStatement pstmtSelectCanonicalMappingByID = null;
	protected PreparedStatement pstmtSelectCanonicalMappingByCigarString = null;
	
	protected PreparedStatement pstmtSelectSequenceToContigMappings = null;
	protected PreparedStatement pstmtSelectSegment = null;
	
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

		query = "insert into CANONICALMAPPING (cspan,rspan,checksum,cigarstring) values (?,?,?)";
		pstmtInsertInCanonicalMapping = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
		
//		query = "insert into CANONICALSEGMENT (mapping_id,cstart,rstart,length) values (?,?,?,?)";
//		pstmtInsertInCanonicalSegment = conn.prepareStatement(query); // REDUNDENT

// set up prepared statements for retrieving Canonical Mappings from the database

		query = "select mapping_id,cspan,rspan,checksum,cigarstring from CANONICALMAPPING";
		pstmtSelectCanonicalMappings = conn.prepareStatement(query);
		
		query = "select cspan,rspan,checksum,cigarstring from CANONICALMAPPING where mapping_id = ?";
		pstmtSelectCanonicalMappingByID = conn.prepareStatement(query);
		
//		query = "select mapping_id,cspan,rspan from CANONICALMAPPING where checksum = ?";
//		pstmtSelectCanonicalMappingByChecksum = conn.prepareStatement(query);
		query = "select mapping_id,cspan,rspan from CANONICALMAPPING where cigarstring = ?";
		pstmtSelectCanonicalMappingByCigarString= conn.prepareStatement(query);

// retrieval of Generic Mappings		
		
		query = "select seq_id,SEQ2CONTIG.mapping_id,coffset,roffset,direction,cspan,rspan,checksum"
			  + "  from SEQ2CONTIG join CANONICALMAPPING using (mapping_id)"
			  + " where contig_id = ? order by SEQ2CONTIG.mapping_id";
		pstmtSelectSequenceToContigMappings = conn.prepareStatement(query);
		
		query = "select cstart,rstart,length from SEGMENT where mapping_id = ?";
		pstmtSelectSegment = conn.prepareStatement(query); // only apply to regular mapping
	
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
        	    String cigar = rs.getString(4);
	    	    //FIXME CanonicalMapping mapping = new CanonicalMapping(mapping_id,refSpan,subSpan,cigar);
        	  //FIXME Checksum checksum = new Checksum(mapping.getCheckSum());
        	  //FIXME cacheByChecksum.put(checksum,mapping);
		    }
		    rs.close();
	    }
	    catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to build the canonical mapping cache", conn, adb);
	    }
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
		//FIXME String cigar = mapping.getExtendedCigarString();
		//FIXME if (cigar == null)
		//FIXME 	throw new IllegalArgumentException("Incomplete Canonical Mapping: missing cigar string");
        
		Checksum checksum = new Checksum(mapping.getCheckSum());
		if (cacheByChecksum.containsKey(checksum))
			return cacheByChecksum.get(checksum);
		
		try { // try the database for new data
			//FIXME 	pstmtSelectCanonicalMappingByCigarString.setString(1,cigar);
		    ResultSet rs = pstmtSelectCanonicalMappingByCigarString.executeQuery();
			
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
		try {
			pstmtInsertInCanonicalMapping.setInt(1,mapping.getReferenceSpan());
			pstmtInsertInCanonicalMapping.setInt(2,mapping.getSubjectSpan());
			//FIXME pstmtInsertInCanonicalMapping.setString(3,mapping.getExtendedCigarString());
// no transaction needed here			
			int rc = pstmtInsertInCanonicalMapping.executeUpdate();
			
			if (rc == 1) {
			    ResultSet rs = pstmtInsertInCanonicalMapping.getGeneratedKeys();
			    int inserted_ID = rs.next() ? rs.getInt(1) : 0;
			    rs.close();
			    mapping.setMappingID(inserted_ID);
			}
		}
		catch (SQLException e) {
            adb.handleSQLException(e,"Failed to insert new Canonical Mapping", conn, adb);
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
//		    beginTransaction(); // not needed here, single record insert
            pstmtInsertInSequenceToContig.setInt(1,mapping.getContig().getID());
            pstmtInsertInSequenceToContig.setInt(2,mapping.getSequence().getID());
            pstmtInsertInSequenceToContig.setInt(3,cm.getMappingID());		    
            pstmtInsertInSequenceToContig.setInt(4,mapping.getReferenceOffset());		    
            pstmtInsertInSequenceToContig.setInt(5,mapping.getSubjectOffset());		    
            pstmtInsertInSequenceToContig.setString(6,(mapping.isForward() ? "Forward" : "Reverse"));		    

            if (pstmtInsertInSequenceToContig.executeUpdate() == 1) {
 		        return true;
            }
            else {
                adb.handleSQLException(null,"Somehow failed to insert sequence-to-contig mapping", conn, adb);
            }
		}
		catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to insert new Sequence-Contig Mapping", conn, adb);			
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
 		    	String cigar = rs.getString(8);
 		    	//FIXME Checksum checksum = new Checksum(CanonicalMapping.getCheckSum(cigar));
 		    	//FIXME if (cacheByChecksum.containsKey(checksum))
 		    	//FIXME 	cmapping = cacheByChecksum.get(checksum);
 		    	//FIXME else {
 		    	//FIXME 	int mapping_id = rs.getInt(2);
 		    	//FIXME     int refSpan = rs.getInt(6);
 		    	//FIXME     int subSpan = rs.getInt(7);
            	//FIXME     cmapping = new CanonicalMapping(mapping_id,refSpan,subSpan,cigar);
 		    	//FIXME    cacheByChecksum.put(checksum,cmapping);
 		    	//FIXME }
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
	public void addSegmentsToGenericMapping(CanonicalMapping mapping) throws ArcturusDatabaseException {
		if (mapping == null || mapping.getMappingID() <= 0) 
		    throw new IllegalArgumentException("Missing canonical mapping or invalid mapping ID");
		try {
			pstmtSelectSegment.setInt(1, mapping.getMappingID());
			
			ResultSet rs = pstmtSelectSegment.executeQuery();
			
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

	public String getCacheStatistics() {
		return "ByChecksum: " + cacheByChecksum.size();
	}
}
