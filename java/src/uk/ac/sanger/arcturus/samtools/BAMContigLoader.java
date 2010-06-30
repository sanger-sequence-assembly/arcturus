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
    protected ContigGraphBuilder gbuilder;
    protected ContigImportApprover approver;
    
	public BAMContigLoader(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		this.adb = adb;
		this.brl = brl;
		
	    gbuilder = new ContigGraphBuilder(adb, brl);
	    extractor = new SubgraphExtractor<Contig>();
	    approver = new SimpleContigImportApprover();
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

	    Utility.reportMemory("Before loading readname-to-current contig cache");

	    prepareLinkManagerCache(adb, project);
	    
	    Utility.reportMemory("After loading readname-to-current contig cache");

	    graph = gbuilder.identifyParentsForContigs(contigs, reader);
	    
	    Utility.reportMemory("After creating parent-child graph");
	    
	    System.out.println("\n\nPARENT-CHILD GRAPH\n");
	    
	    Utility.displayGraph(System.out, graph);

	    discardLinkManagerCache(adb);
	    
	    Utility.reportMemory("After dropping readname-to-current contig cache");
	    
	    boolean approved = approver.approveImport(graph, project, System.err);
	    
	    System.out.println("Approver returned " + approved);
	    
	    Set<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> subGraph = extractor.analyseSubgraphs(graph);
	    
	    Utility.reportMemory("After analysing parent-child sub-graphs");
	    
	    System.out.println("\n\nPARENT-CHILD SUB-GRAPHS\n");
	    
	    for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> g : subGraph) {
	    	Utility.displayGraph(System.out, g);
	    	System.out.println("\n\n======================================================================\n");
	    }
  
	    adb.preloadCanonicalMappings();

	    Utility.reportMemory("After loading canonical mappings");

	    if (approved && !Boolean.getBoolean("noloadcontigs"))
	    	addMappingsToContigs(contigs, reader);    
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

