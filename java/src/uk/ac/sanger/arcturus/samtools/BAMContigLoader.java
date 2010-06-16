package uk.ac.sanger.arcturus.samtools;

import java.util.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.jdbc.*;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;

public class BAMContigLoader {
	protected ArcturusDatabase adb;
	protected BAMReadLoader brl = null;
	

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
    		    String readName = record.getReadName();
    		    int flags = record.getFlags();
System.out.println("get readname " + readName + " flag " + flags);

    		    try {
    			    int maskedFlags = Utility.maskReadFlags(flags);
    				Read read = new Read(readName,maskedFlags);
    		        int parent_id = adb.getCurrentContigIDForRead(read);
    		        System.out.println("cpcid " + parent_id + " for readname " + readName + " flag " + flags);
     		        if (parent_id > 0) {
     		    	    int count = 0;
     		    	    if (graph.containsKey(parent_id))
     		    		    count = (Integer)graph.get(parent_id);
     		    	    count++;
     		    	    graph.put(parent_id, count);
     		        }
// either the read is not in the database, or not in a current contig (of the project)
     		        else if (parent_id < 0 && brl != null) { // only load if it's not in the database
//System.out.println("Trying to load read " + readName);
     		            if (adb.getReadByNameAndFlags(readName,flags) == null)
     		            	brl.findOrCreateSequence(record);
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
System.out.println("Resulting parent contigs");
                        
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

