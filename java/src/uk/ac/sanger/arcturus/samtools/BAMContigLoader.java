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
	
    protected SubgraphExtractor<Contig> extractor;
    protected ContigGraphBuilder graphBuilder;
    protected ContigImportApprover approver;
	protected SAMContigBuilder contigBuilder;
	protected ContigComparator contigComparator;

	public BAMContigLoader(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		this.adb = adb;
		this.brl = brl;
		
	    graphBuilder = new ContigGraphBuilder(adb, brl);
	    extractor = new SubgraphExtractor<Contig>();
	    approver = new SimpleContigImportApprover();
	    contigBuilder = new SAMContigBuilder(adb, brl);
	    contigComparator = new ContigComparator(adb);
     }

	public void processFile(SAMFileReader reader, Project project, String contigName) throws ArcturusDatabaseException {
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
	    
	    boolean haveCurrentContigs = adb.countCurrentContigs() > 0;

    	if (project != null && haveCurrentContigs)
            adb.prepareToLoadProject(project);
        else 
            adb.prepareToLoadAllProjects();
    
	    Utility.reportMemory("After loading readname-to-current contig cache");

	    SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph =
	    	graphBuilder.identifyParentsForContigs(contigs, reader);
	    
	    Utility.reportMemory("After creating parent-child graph");
	    
	    Utility.displayGraph("PARENT-CHILD GRAPH", graph);

	    adb.clearCache(ArcturusDatabase.LINK);
	    System.gc();
	    
	    Utility.reportMemory("After dropping readname-to-current contig cache and garbage-collecting");
	    
	    Set<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> subGraphs = extractor.analyseSubgraphs(graph);
	    
	    Utility.reportMemory("After analysing parent-child sub-graphs");
	    
	    int i = 0;
	    
	    for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> g : subGraphs) {
	    	i++;
	    	Utility.displayGraph("PARENT-CHILD SUB-GRAPH " + i, g);
	    }
	    
	    boolean approved = approver.approveImport(graph, project, System.err);
	    
	    Arcturus.logFine("Approver returned " + approved + "\n");
	
	    if (!approved) {
	    	Arcturus.logWarning("The import was not approved: " + approver.getReason());
	    } else {
	    	if (Boolean.getBoolean("noloadcontigs")) {
	    		Arcturus.logWarning("The \"noloadcontigs\" option was specified, so no contigs will be loaded");
			} else {
				adb.preloadCanonicalMappings();

				Utility.reportMemory("After loading canonical mappings");

				for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> subgraph : subGraphs)
					importChildContigs(subgraph, reader);
			}
	    }
	    
	    Arcturus.logFine("===== " + getClass().getName() + " FINISHED =====");
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

      		Arcturus.logFine("Added contig " + contig);
     	}
     	
        return contigs;      	
    }    
  
    private void importChildContigs(
			SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph,
			SAMFileReader reader) throws ArcturusDatabaseException {
    	Set<Contig> vertices = graph.vertexSet();
    	
    	Set<Contig> children = new HashSet<Contig>();
       	Set<Contig> parents = new HashSet<Contig>();
		
    	for (Contig contig : vertices) {
    		if (graph.inDegreeOf(contig) > 0)
    			parents.add(contig);
    		else
    			children.add(contig);
    	}
    	
    	boolean doImport = true;
    	
    	if (parents.size() == 1 && children.size() == 1) {
    		Contig parent = getFirst(parents);
    		Contig child = getFirst(children);
    		
    		contigBuilder.addMappingsToContig(child, reader);
    		
 			doImport = !contigComparator.equalsParentContig(child, parent);
 			
 			if (!doImport)
 				child.setSequenceToContigMappings(null);
    	}
    	
    	if (doImport) {
    		storeChildContigs(children, reader);
    		
    		Set<DefaultWeightedEdge> edges = graph.edgeSet();
    		
    		for (DefaultWeightedEdge edge : edges) {
    			Contig child = graph.getEdgeSource(edge);
    			
    			Contig parent = graph.getEdgeTarget(edge);
    			
    			int mapping_id = adb.setChildContig(parent, child);
    			Arcturus.logFine("Parent contig #" + parent.getID() +
    					" has child contig #" + child.getID() +
    					" with mapping ID " + mapping_id);
    		}
    	}
	}
    
    private Contig getFirst(Set<Contig> contigs) {
    	if (contigs == null || contigs.isEmpty())
    		return null;
    	
    	Iterator<Contig> iter = contigs.iterator();
    	
    	if (iter.hasNext())
    		return iter.next();
    	else
    		return null;
    }

    private void storeChildContigs(Set<Contig> contigs, SAMFileReader reader)
    	throws ArcturusDatabaseException {	
    	for (Contig contig : contigs) {
    		Arcturus.logFine("Storing contig " + contig + " in database");
    		
     		contigBuilder.addMappingsToContig(contig, reader);
    	    
    	    adb.putContig(contig);
    	    
    	    Utility.reportMemory("Contig " + contig + " stored in database");
    	    
    	    contig.setSequenceToContigMappings(null);
    	}
    }
}

