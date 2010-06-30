package uk.ac.sanger.arcturus.samtools;

import java.util.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.graph.*;

import net.sf.samtools.*;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

public class BAMContigLoader {
	protected ArcturusDatabase adb;
	protected BAMReadLoader brl = null;
	
    //protected SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph;
    protected SubgraphExtractor<Contig> extractor;
    protected ContigGraphBuilder graphBuilder;
    protected ContigImportApprover approver;
	protected SAMContigBuilder contigBuilder;

	public BAMContigLoader(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		this.adb = adb;
		this.brl = brl;
		
	    graphBuilder = new ContigGraphBuilder(adb, brl);
	    extractor = new SubgraphExtractor<Contig>();
	    approver = new SimpleContigImportApprover();
	    contigBuilder = new SAMContigBuilder(adb, brl);
     }

	public void processFile(SAMFileReader reader, Project project, String contigName) throws ArcturusDatabaseException {
    	
    	System.out.println("USING PRODUCTION SCRIPT");
	    	
	    Set<Contig> contigs;
	    
	    if (contigName == null)
	    	contigs = getContigs(reader);
	    else {
	    	contigs = new HashSet<Contig>();
	    	contigs.add(new Contig(contigName));
	    }
	    
	    for (Contig contig : contigs)
	    	contig.setProject(project);

	    Utility.reportMemory("Before loading readname-to-current contig cache");

    	if (project != null)
            adb.prepareToLoadProject(project);
        else 
            adb.prepareToLoadAllProjects();
    
	    Utility.reportMemory("After loading readname-to-current contig cache");

	    SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph =
	    	graphBuilder.identifyParentsForContigs(contigs, reader);
	    
	    Utility.reportMemory("After creating parent-child graph");
	    
	    System.out.println("\n\nPARENT-CHILD GRAPH\n");
	    
	    Utility.displayGraph(System.out, graph);

	    adb.clearCache(ArcturusDatabase.LINK);
	    
	    Utility.reportMemory("After dropping readname-to-current contig cache");
	    
	    boolean approved = approver.approveImport(graph, project, System.err);
	    
	    System.out.println("Approver returned " + approved);
	    
	    Set<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> subGraphs = extractor.analyseSubgraphs(graph);
	    
	    Utility.reportMemory("After analysing parent-child sub-graphs");
	    
	    System.out.println("\n\nPARENT-CHILD SUB-GRAPHS\n");
	    
	    for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> g : subGraphs) {
	    	Utility.displayGraph(System.out, g);
	    	System.out.println("\n\n======================================================================\n");
	    }
  
	    adb.preloadCanonicalMappings();

	    Utility.reportMemory("After loading canonical mappings");

	    if (approved && !Boolean.getBoolean("noloadcontigs")) {
	    	for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> subgraph : subGraphs)
	    		importChildContigs(subgraph, reader);  
	    }
    }

	protected Set<Contig> getContigs(SAMFileReader reader) {
        SAMFileHeader header = reader.getFileHeader();
         
     	SAMSequenceDictionary dictionary = header.getSequenceDictionary();
     	
      	List<SAMSequenceRecord> seqs = dictionary.getSequences();
      	
      	if (seqs.isEmpty())
     		throw new IllegalArgumentException("The input file is empty");
      	
        Set<Contig> contigs = new HashSet<Contig>();
        
     	for (SAMSequenceRecord record : seqs) {
      		String contigName = record.getSequenceName();
      		
      		Contig contig = new Contig(contigName);
      		
      		contig.setLength(record.getSequenceLength());
      		
      		contigs.add(contig);

      		System.out.println("Added contig " + contig);
     	}
     	
        return contigs;      	
    }    
  
    private void importChildContigs(
			SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph,
			SAMFileReader reader) {
    	Set<Contig> vertices = graph.vertexSet();
    	
    	Set<Contig> children = new HashSet<Contig>();
       	Set<Contig> parents = new HashSet<Contig>();
		
    	for (Contig contig : vertices) {
    		if (graph.inDegreeOf(contig) > 0)
    			parents.add(contig);
    		else
    			children.add(contig);
    	}
	}

    private void addMappingsToContigs(Set<Contig> contigs, SAMFileReader reader) {	
    	for (Contig contig : contigs) {
    		try {
     		    contigBuilder.addMappingsToContig(contig, reader);
    		}
    		catch (ArcturusDatabaseException e) {
    		
    		}
    	    
    	    try {
    	        adb.putContig(contig);
    	    }
    	    catch (ArcturusDatabaseException e) {
    	        Arcturus.logWarning(e);
    	    }
    	    
    	    contig.setSequenceToContigMappings(null);
    	}
    }
}

