package uk.ac.sanger.arcturus.samtools;

import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.jdbc.*;
import uk.ac.sanger.arcturus.graph.*;

import net.sf.samtools.*;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

public class BAMContigLoader {
	protected ArcturusDatabase adb;
	protected BAMReadLoader brl = null;
	
    protected SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph;
    protected SubgraphExtractor<Contig> extractor;
    protected GraphBuilder gbuilder;
    
	public BAMContigLoader(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		this.adb = adb;
		this.brl = brl;
		
	    gbuilder = new GraphBuilder(adb, brl);
	    extractor = new SubgraphExtractor<Contig>();
     }

	public void processFile(SAMFileReader reader, Project project, String contigName) throws ArcturusDatabaseException {
    	
    	System.out.println("USING PRODUCTION SCRIPT");
	    	
	    Contig[] contigs;
	    
	    if (contigName == null)
	    	contigs = getContigs(reader);
	    else {
	    	contigs = new Contig[1];
	    	contigs[0] = new Contig(contigName);
	    }
	    
	    for (Contig contig : contigs)
	    	contig.setProject(project);

//	    System.out.println("before LM cache Memory usage: " + memoryUsage());

	    prepareLinkManagerCache(adb, project);

//	    System.out.println("after LM cache Memory usage: " + memoryUsage());

	    graph = gbuilder.identifyParentsForContigs(contigs,reader);

	    discardLinkManagerCache(adb);
	    
// get sub graphs
	    
	    Set<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> subGraph = extractor.analyseSubgraphs(graph);
	    
//	    System.out.println("before loading canonical mappings Memory usage: " + memoryUsage());
	    
	    /*
	    adb.preloadCanonicalMappings();

	    System.out.println("after loading CMsMemory usage: " + memoryUsage());

	    addMappingsToContigs(contigs, reader);
*/	    
    }
 	

   /**
   * Creates a list of minimal Contig objects from the given SAMFileReader 
   * @param reader
   *        SAMFileReader 
   * @return an Array of Contig instances
   */
  
    protected Contig[] getContigs(SAMFileReader reader) {

        SAMFileHeader header = reader.getFileHeader();
         
     	SAMSequenceDictionary dictionary = header.getSequenceDictionary(); 
      	List<SAMSequenceRecord> seqs = dictionary.getSequences();
      	if (seqs.isEmpty())
     		throw new IllegalArgumentException("The input file is empty");
      	
        Vector<Contig> C = new Vector<Contig>();
     	for (SAMSequenceRecord record : seqs) {
      		String contigName = record.getSequenceName();
      		Contig contig = new Contig(contigName);
      		contig.setLength(record.getSequenceLength());
      		C.add(contig);
System.out.println("Added contig " + contig);
            
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

    protected void prepareLinkManagerCache(ArcturusDatabase adb, Project project) throws ArcturusDatabaseException {

    	if (project != null) {
            adb.prepareToLoadProject(project);
            if (getLinkManagerCacheSize(adb) == 0)
            	adb.prepareToLoadAllProjects();
        }
        else 
            adb.prepareToLoadAllProjects();
System.out.println("Size of cache : " + this.getLinkManagerCacheSize(adb));    	
    }
 
 	 
    protected void addMappingsToContigs(Contig[] contigs, SAMFileReader reader) {
    	
    	SAMContigBuilder scb = new SAMContigBuilder(adb,brl);

    	for (int i=0 ; i < contigs.length ; i++) {
    		try {
     		    scb.addMappingsToContig(contigs[i],reader);
    		}
    		catch (ArcturusDatabaseException e) {
    		
    		}
    	    
    	    try {
    	        adb.putContig(contigs[i]);
    	    }
    	    catch (ArcturusDatabaseException e) {
    	        Arcturus.logWarning(e);
    	    }
    	    
    	    contigs[i].setSequenceToContigMappings(null);
    	}
    }
 	      
 /**
  *    private methods accessing the LinkManager
  */
 
	protected int getLinkManagerCacheSize(ArcturusDatabase adb) {
		int size = 0;
	
	    if (adb instanceof ArcturusDatabaseImpl) {
	        ArcturusDatabaseImpl adbi = (ArcturusDatabaseImpl)adb;
	        LinkManager lm = (LinkManager)adbi.getManager(ArcturusDatabaseImpl.LINK);
	        size = lm.getCacheSize();
	    }
	    
	    return size;
	}
	
	protected void discardLinkManagerCache(ArcturusDatabase adb) {
	    if (adb instanceof ArcturusDatabaseImpl) {
	        ArcturusDatabaseImpl adbi = (ArcturusDatabaseImpl)adb;
	        LinkManager lm = (LinkManager)adbi.getManager(ArcturusDatabaseImpl.LINK);
	        lm.clearCache();
	    }
	}
}

