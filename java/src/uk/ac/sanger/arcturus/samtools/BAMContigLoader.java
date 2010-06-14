package uk.ac.sanger.arcturus.samtools;

import java.io.*;
import java.util.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.jdbc.*;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;;

public class BAMContigLoader {
	private ArcturusDatabase adb;
	private BAMReadLoader brl = null;
	

	public BAMContigLoader(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;
    }
 	
	public BAMContigLoader(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		this.adb = adb;
		this.brl = brl;
    }
  	
    public void processFile(SAMFileReader reader, Project project) throws ArcturusDatabaseException {
    	
    	Contig[] contigs = getContigs(reader);
    	
    	prepareLinkManagerCache(adb, project);
      	  
        identifyParentsForContigs(contigs,reader); // decide later if and what type to return
    	
 // identify contigs with only one parent  ; test for equality, if equal ignore
 // identify contigs with parents, analyse links for consistency; if conflict, abort
 // load new contigs        
   }

   /**
   * Creates a list of minimal Contig objects from the given SAMFileReader 
   * @param reader
   *        SAMFileReader 
   * @return an Array of Contig instances
   */
  
    private Contig[] getContigs(SAMFileReader reader) {

        SAMFileHeader header = reader.getFileHeader();
         
     	SAMSequenceDictionary dictionary = header.getSequenceDictionary(); 
      	List<SAMSequenceRecord> seqs = dictionary.getSequences();
      	if (seqs.isEmpty())
     		throw new IllegalArgumentException("The input file is empty");
      	
        Vector<Contig> C = new Vector<Contig>();
     	for (SAMSequenceRecord record : seqs) {
      		String contigName = record.getSequenceName();
      		C.add(new Contig(contigName));
System.out.println("Added contig " + contigName + " : " + record.getSequenceLength());
     	}
     	
        return C.toArray(new Contig[0]);      	
    }
    
/**
 * Preload the readname - current_contig_id hash for a specified project or for all projects
 * @param adb
 *        ArcturusDatabase instance
 * @param project
 *        Project instance or null
 */

    private void prepareLinkManagerCache(ArcturusDatabase adb, Project project) throws ArcturusDatabaseException {

    	if (project != null) {
            adb.prepareToLoadProject(project);
            if (getLinkManagerCacheSize(adb) == 0)
            	adb.prepareToLoadAllProjects();
        }
        else 
            adb.prepareToLoadAllProjects();
System.out.println("Size of cache : " + this.getLinkManagerCacheSize(adb));    	
    }
    
 /**
  *    
  * @param contigs
  * @param reader
  */
    
    
    private void identifyParentsForContigs(Contig[] contigs, SAMFileReader reader) {
    	
     	for (int i=0 ; i < contigs.length ; i++) {
    		String referenceSequenceName = contigs[i].getName();
     		System.out.println("Processing contig " + referenceSequenceName);
 
     		CloseableIterator<SAMRecord> iterator = reader.query(referenceSequenceName, 0, 0, false);

     	   	Map<Integer,Integer> graph = new HashMap<Integer,Integer>();
     	   	
     		while (iterator.hasNext()) {
     		    SAMRecord record = iterator.next();
    		    int maskedFlags = Utility.maskReadFlags(record.getFlags());
    		    String readName = record.getReadName();
    		    Read read = new Read(readName,maskedFlags);
    		    String uniqueReadName = read.getUniqueName();
    		    try {
     		        int parent_id = adb.getCurrentContigIDForReadName(uniqueReadName);
     		        if (parent_id > 0) {
     		    	    int count = 0;
     		    	    if (graph.containsKey(parent_id))
     		    		    count = (Integer)graph.get(parent_id);
     		    	    count++;
     		    	    graph.put(parent_id, count);
     		        }
// either the read is not in the database, or not in a contig
     		        else if (brl != null) { // only load if it's not in the database
//System.out.println("Trying to load read " + readName);
     		            if (adb.getReadByNameAndFlags(readName,maskedFlags) == null)
     		            	brl.processRecord(record);
     		        }
     		    }
    		    catch (ArcturusDatabaseException e) {
    		    	System.err.println(e + "possibly database access lost");
    		    }
     		}
     		
     		iterator.close();
     		
     	    Set parentIDs = graph.keySet();
     	    Iterator parentIDiterator = parentIDs.iterator();
            Vector<ContigToParentMapping> M = new Vector<ContigToParentMapping>();
     		while (parentIDiterator.hasNext()) {
     			int parent_id = (Integer)parentIDiterator.next();
     			int readCount = (Integer)graph.get(parent_id);
System.out.println("Parent contig ID " + parent_id + " readcount: " + readCount);
        		Contig parent = new Contig(parent_id,adb); // minimal parent object
        		ContigToParentMapping cpmapping = new ContigToParentMapping(contigs[i],parent);
        		cpmapping.setReadCount(readCount);
        		M.add(cpmapping);
     		}
     		contigs[i].setContigToParentMappings(M.toArray(new ContigToParentMapping[0]));
     	}
// here all input contigs have parent-to-contig mappings and their weights    	
    }
 
    
    
    
    
    
    private Contig buildContig(SAMFileReader reader, String referencename) {
    	
 		CloseableIterator<SAMRecord> iterator = reader.query(referencename, 0, 0, false);
 		
 		Contig contig = new Contig(referencename);
 		
 		Vector<SequenceToContigMapping> M = new Vector<SequenceToContigMapping>();
 		
 		while (iterator.hasNext()) {
 		    SAMRecord record = iterator.next();
 		    int maskedFlags = Utility.maskReadFlags(record.getFlags());
 		    Read read = new Read(record.getReadName(),maskedFlags);
 		    Sequence sequence = new Sequence(0,read,record.getReadBases(),record.getBaseQualities(),0);
 		    String cigar = record.getCigarString();
 		    int contigStartPosition = record.getAlignmentStart();
 		    int contigEndPosition = record.getAlignmentEnd();
 // WHAT to do with direction REVERSE ?
 		    CanonicalMapping cm = new CanonicalMapping(cigar);
 		    SequenceToContigMapping mapping = new SequenceToContigMapping(sequence,contig, cm,
 		    		                                   contigStartPosition,1,Direction.FORWARD);
 		    M.add(mapping);
 		}
 		
// 		contig.setMappings(M.toArray(new SequenceToContigMapping[0]));
   	
        return contig;	    	
    }
	
/*
    private void processCanonicalMappings(Contig contig, ArcturusDatabase adb) {
	    // identify/load canonical mappings to get canonical mappings
		SequenceToContigMapping[] mappings = contig.getMappings();
		for (int i=0 ; i < mappings.length ; i++) {
			
		}
	}
*/
   
 
	public void analyseGraph() {
		// analyse graph of parent contig relations; aborted on inconsistencies
	}
	
	public void putContigs() {
		// put the new contigs in the database
	}

	public void writeImportMarker() {
		
	}
		
// make executable for testing
	
	public static void main(String[] args) {
	
	}
	
	private int getLinkManagerCacheSize(ArcturusDatabase adb) {
		int size = 0;
	
	    if (adb instanceof ArcturusDatabaseImpl) {
	        ArcturusDatabaseImpl adbi = (ArcturusDatabaseImpl)adb;
	        LinkManager lm = (LinkManager)adbi.getManager(ArcturusDatabaseImpl.LINK);
	        size = lm.getCacheSize();
	    }
	    
	    return size;
	}
}

