package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.Arcturus;
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
	private Map<String,CanonicalMapping> cacheByChecksum;
	
	protected PreparedStatement pstmtInsertInSequenceToContig = null;
	protected PreparedStatement pstmtInsertInParentToContig = null;
	protected PreparedStatement pstmtInsertCanonicalMapping = null;
	
	protected PreparedStatement pstmtSelectAllCanonicalMappings = null;
	protected PreparedStatement pstmtSelectCanonicalMappingByID = null;
	protected PreparedStatement pstmtSelectCanonicalMappingByCigarString = null;
	
	protected PreparedStatement pstmtSelectSequenceToContigMappings = null;
	protected PreparedStatement pstmtSelectSegment = null;
	
	private boolean allowDuplicateSequences = false;
	
	public MappingManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

        cacheByChecksum = new HashMap<String,CanonicalMapping>();
        
        allowDuplicateSequences = Boolean.getBoolean("mappingmanager.allowduplicatesequences");
        
        if (allowDuplicateSequences)
        	Arcturus.logInfo("The mapping manager *WILL* ignore duplicate sequences");
		
		try {
			setConnection(adb.getDefaultConnection());
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the mapping manager", conn, adb);
		}
	}

	protected void prepareConnection() throws SQLException {
		String query;

        query = "insert into CANONICALMAPPING (cspan,rspan,cigar, mapping_quality) values (?,?,?,?)";
        pstmtInsertCanonicalMapping = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);

		query = "insert into SEQ2CONTIG (contig_id,seq_id,mapping_id,coffset,roffset,direction) "
			  + "values (?,?,?,?,?,?)";
		pstmtInsertInSequenceToContig = conn.prepareStatement(query);
		
		query = "insert into PARENT2CONTIG (contig_id,parent_id,mapping_id,coffset,roffset,direction,weight) "
			  + "values (?,?,?,?,?,?,?)";
		pstmtInsertInParentToContig   = conn.prepareStatement(query);

		query = "select mapping_id,cspan,rspan,cigar from CANONICALMAPPING";
		pstmtSelectAllCanonicalMappings = conn.prepareStatement(query);
		
		query = "select cspan,rspan,cigar from CANONICALMAPPING where mapping_id = ?";
		pstmtSelectCanonicalMappingByID = conn.prepareStatement(query);
		
		query = "select mapping_id,cspan,rspan from CANONICALMAPPING where cigar = ?";
		pstmtSelectCanonicalMappingByCigarString= conn.prepareStatement(query);
		
		query = "select seq_id,SEQ2CONTIG.mapping_id,coffset,roffset,direction,cspan,rspan,cigar"
			  + "  from SEQ2CONTIG join CANONICALMAPPING using (mapping_id)"
			  + " where contig_id = ? order by SEQ2CONTIG.mapping_id";
		pstmtSelectSequenceToContigMappings = conn.prepareStatement(query);
		
		query = "select cstart,rstart,length from SEGMENT where mapping_id = ?";
		pstmtSelectSegment = conn.prepareStatement(query); // only apply to regular mapping
		
		query = "select seq_id,mapping_id,cstart,cfinish,direction"
			  + "  from MAPPING"
			  + " where contig_id = ? order by mapping_id";
		
		query = "select cstart,rstart,length from SEGMENT where mapping_id=?";
	}
	
    public void clearCache() {
    	cacheByChecksum.clear();
    }

    public void preload() throws ArcturusDatabaseException {
        clearCache();
    
        Arcturus.logFine("Building Canonical Mapping hash");
	
        long t0 = System.currentTimeMillis();
        
	    try {
	    	ResultSet rs = pstmtSelectAllCanonicalMappings.executeQuery();
		    
            while (rs.next()) {
            	int mapping_id = rs.getInt(1);
        	    int refSpan = rs.getInt(2);
        	    int subSpan = rs.getInt(3);
        	    String cigar = rs.getString(4);

	    	    CanonicalMapping mapping = new CanonicalMapping(mapping_id,refSpan,subSpan,cigar, 0);
        	    cacheByChecksum.put(cigar,mapping);
		    }
		    rs.close();
		    
		    long dt = System.currentTimeMillis() - t0;
		    Arcturus.logFine("DONE Building Canonical Mapping hash " + cacheByChecksum.size() +
		    		" entries in " + dt + " ms");
	    }
	    catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to build the canonical mapping cache", conn, adb);
	    }
    }
    
/**
 * Handling Canonical Mappings
 * 
 * @param mapping CanonicalMapping instance
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
	
	public CanonicalMapping findOrCreateCanonicalMapping(CanonicalMapping mapping) throws ArcturusDatabaseException {
		if (mapping == null) 
			throw new IllegalArgumentException("A CanonicalMapping is required as argument");
		String cigar = mapping.getExtendedCigarString();
		if (cigar == null)
		    throw new IllegalArgumentException("Incomplete Canonical Mapping: missing cigar string");
        
		if (cacheByChecksum.containsKey(cigar))
			return cacheByChecksum.get(cigar);

        if (findCanonicalMapping(mapping)) // try database for new data
            return mapping;

		if (addCanonicalMapping(mapping))
			return mapping;
		
		return null;
    }
	
	private boolean addCanonicalMapping(CanonicalMapping mapping) throws ArcturusDatabaseException {
		boolean success = false;
 
        try {
            String cigar = mapping.getExtendedCigarString();

		    pstmtInsertCanonicalMapping.setInt(1, mapping.getReferenceSpan());
			pstmtInsertCanonicalMapping.setInt(2, mapping.getSubjectSpan());
			pstmtInsertCanonicalMapping.setString(3, cigar);
			
			int rc = pstmtInsertCanonicalMapping.executeUpdate();
						
			if (rc == 1) {
				ResultSet rs = pstmtInsertCanonicalMapping.getGeneratedKeys();
				int inserted_ID = rs.next() ? rs.getInt(1) : 0;
				rs.close();
				if (inserted_ID > 0) {
 				    mapping.setMappingID(inserted_ID);
			       	cacheByChecksum.put(cigar,mapping);
				    success = true;
				}
            }
        }
		catch (SQLException e) {
			adb.handleSQLException(e,"Failed to insert new Canonical Mapping", conn, adb);
		}

		return success;
	}
	
	private boolean findCanonicalMapping(CanonicalMapping mapping) throws ArcturusDatabaseException {
		String cigar = mapping.getExtendedCigarString();		
		
		try {
			pstmtSelectCanonicalMappingByCigarString.setString(1, cigar);
		    ResultSet rs = pstmtSelectCanonicalMappingByCigarString.executeQuery();
						
			if (rs.next()) {
			    mapping.setMappingID(rs.getInt(1));
			    mapping.setReferenceSpan(rs.getInt(2));
			    mapping.setSubjectSpan(rs.getInt(3));

			    cacheByChecksum.put(cigar,mapping);
		    }
			rs.close();
						
			if (mapping.getMappingID() > 0)
			    return true;
	    }
	    catch (SQLException e) {
			adb.handleSQLException(e,"Failed to access database", conn, adb);
	    }
	    return false;
	}
	
	public CanonicalMapping findCanonicalMapping(String cigar) throws ArcturusDatabaseException {
		CanonicalMapping mapping = new CanonicalMapping(cigar);
		if (findCanonicalMapping(mapping)) 
			return mapping;
		return null;
	}
	
	/**
	 * Handling SequenceToContigMappings
	 * 
	 * @param contig Contig instance
	 * @throws ArcturusDatabaseException
	 */

	public boolean putSequenceToContigMappings(Contig contig) throws ArcturusDatabaseException {

		SequenceToContigMapping[] mappings = contig.getSequenceToContigMappings();
		
		int failures = 0;

		for (int i = 0; i < mappings.length; i++) {
	    	if (!storeSequenceToContigMapping(mappings[i])) {
	    		if (allowDuplicateSequences)
	    			failures++;
	    		else
	    			return false;
	    	}
	    }
		
	    return true;
	}
	
	private boolean storeSequenceToContigMapping(SequenceToContigMapping mapping) throws ArcturusDatabaseException {

		CanonicalMapping cm = mapping.getCanonicalMapping();
		if (cm == null || cm.getMappingID() < 1)
			throw new IllegalArgumentException("Mapping has no canonical mapping or invalid mapping ID");
		if (mapping.getSequence() == null || mapping.getContig() == null)
			throw new IllegalArgumentException("Mapping has no Sequence or Contig reference");
		
		try {
            pstmtInsertInSequenceToContig.setInt(1, mapping.getContig().getID());
            pstmtInsertInSequenceToContig.setInt(2, mapping.getSequence().getID());
            pstmtInsertInSequenceToContig.setInt(3, cm.getMappingID());		    
            pstmtInsertInSequenceToContig.setInt(4, mapping.getReferenceOffset());		    
            pstmtInsertInSequenceToContig.setInt(5, mapping.getSubjectOffset());		    
            pstmtInsertInSequenceToContig.setString(6, (mapping.isForward() ? "Forward" : "Reverse"));		    

            int rc = pstmtInsertInSequenceToContig.executeUpdate();
            
            return rc == 1;
		}
		catch (SQLException e) {
			String sqlState = e.getSQLState();
			
			if (allowDuplicateSequences && sqlState.equalsIgnoreCase("23000")) {
				String readName = mapping.getSequence().getRead().getUniqueName();
				String contigName = mapping.getContig().getName();
				
				String message = "The read " + readName + " appears more than once in contig " + contigName;
				
				Arcturus.logWarning(message);
				
				return true;
			} else	        
				adb.handleSQLException(e,"Failed to insert new Sequence-Contig Mapping", conn, adb);			
		}
		
		return false;
	}
	
	/**
	 * Handling ContigToParentMappings
	 * 
	 * @param contig
	 * @throws ArcturusDatabaseException
	 */

	public boolean putContigToParentMappings(Contig contig) throws ArcturusDatabaseException {
	    ContigToParentMapping[] mappings = contig.getContigToParentMappings();
	    
	    if (mappings == null) 
	    	return true;
	    
	    boolean success = true;
	    for (int i=0 ; i < mappings.length ; i++) {
//	    	if (!storeContigToParentMapping(mappings[i])) return false
	    }
	    
	    return success;
	}
	
/**
* retrieval of sequence to contig mappings with Canonical Mappings in minimal form
*/
	
	public int getSequenceToContigMappings(Contig contig) throws ArcturusDatabaseException {		
		int numberOfMappings = 0;
		
		if (contig == null || contig.getID() <= 0) 
		    throw new IllegalArgumentException("Missing contig or invalid contig ID");
		
		try {
 		    pstmtSelectSequenceToContigMappings.setInt(1, contig.getID());
 		    
 		    ResultSet rs = pstmtSelectSequenceToContigMappings.executeQuery();		    
 		    
 		    Vector<SequenceToContigMapping> mappings = new Vector<SequenceToContigMapping>();
 		    
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
                mappings.add(new SequenceToContigMapping(sequence,contig,cmapping,
                		                                 refOffset,subOffset,direction));
 		    }
            rs.close();	
    		
    		contig.setSequenceToContigMappings(mappings.toArray(new SequenceToContigMapping[0]));
		}
		catch (SQLException e) {
	        adb.handleSQLException(e,"Failed to retrieve Sequence-Contig Mappings", conn, adb);			
		}
		
		return numberOfMappings;
	}
	
	
	public void addMappingsToContig(Contig contig) {
		// read mappings from MAPPING table (OLD REPRESENTATION)
		// build SequenceToContigMappings from that (NEEDS a temporary mapping_id field?) + SEGMENTS
		// but using the Canonical Representation internally.
    }
	
	public void addSegmentsToMapping(GenericMapping mappings) { // SEE perl code
	    // 
	}

	public String getCacheStatistics() {
		return "ByChecksum: " + cacheByChecksum.size();
	}
}
