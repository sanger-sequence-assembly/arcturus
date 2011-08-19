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

	public Map<String, Integer> processFile(SAMFileReader reader, Project project, String contigName) throws ArcturusDatabaseException {
	    Set<Contig> contigs;
	    
	    Map<String, Integer> nameToID = new HashMap<String, Integer>();
	    
	    if (contigName == null)
	    	contigs = getContigs(reader);
	    else {
	    	contigs = new HashSet<Contig>();
	    	contigs.add(new Contig(contigName));
	    }
	    
	    reportProgress("===== WELCOME TO THE ARCTURUS 2 CONTIG LOADER =====");
	        
	    reportProgress("\nFound " + contigs.size() + " contigs in the input file for project " + project.getName());
	    
	    for (Contig contig : contigs)
	    	contig.setProject(project);

	    Utility.reportMemory("Before loading readname-to-current contig cache");
	    
	    boolean haveCurrentContigs = adb.countCurrentContigs() > 0;
	    
	    reportProgress("\nBuilding list of names of reads in current contigs.");

    	if (project != null && haveCurrentContigs)
            adb.prepareToLoadProject(project);
        else 
            adb.prepareToLoadAllProjects();
    
	    Utility.reportMemory("After loading readname-to-current contig cache");
	    
	    reportProgress("DONE.");
	    
	    reportProgress("\nLinking contigs in the file to their parents in the database.");

	    SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph =
	    	graphBuilder.identifyParentsForContigs(contigs, reader);
	    
	    reportProgress("DONE.");
    
	    Utility.reportMemory("After creating parent-child graph");
	    
	    Utility.displayGraph("PARENT-CHILD GRAPH", graph);

	    adb.clearCache(ArcturusDatabase.LINK);
	    System.gc();
	    
	    Utility.reportMemory("After dropping readname-to-current contig cache and garbage-collecting");
	    
	    reportProgress("\nGrouping parent contigs and their children into family groups.");
	    
	    Set<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> subGraphs = extractor.analyseSubgraphs(graph);
	    
	    reportProgress("DONE.");
    
	    Utility.reportMemory("After analysing parent-child sub-graphs");
	    
	    int i = 0;
	    
	    for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> g : subGraphs) {
	    	i++;
	    	Utility.displayGraph("PARENT-CHILD SUB-GRAPH " + i, g);
	    }
	    
	    reportProgress("\nDetermining whether there are any problems which might prevent the import.");
    
	    boolean approved = approver.approveImport(graph, project, System.err);
	    
	    reportProgress("DONE.");
    
	    Arcturus.logFine("Approver returned " + approved + "\n");
	
	    if (!approved) {
	    	Arcturus.logWarning("The import was not approved: " + approver.getReason());
	    } else {
	    	if (Boolean.getBoolean("noloadcontigs")) {
	    		Arcturus.logWarning("The \"noloadcontigs\" option was specified, so no contigs will be loaded");
			} else {
			    reportProgress("\nPreparing to analyse the new contigs in detail.");
			    
				adb.preloadCanonicalMappings();
			    
			    reportProgress("DONE.");

				Utility.reportMemory("After loading canonical mappings");
				
				reportProgress("\nPreparing to import read groups.");
				
				importSAMReadGroupRecords(reader, project);
				
				reportProgress("\nPreparing to import any new child contigs.");

				for (SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> subgraph : subGraphs)
					importChildContigs(subgraph, reader, nameToID);
			}
	    }
	    
	    Arcturus.logFine("===== " + getClass().getName() + " FINISHED =====");
	    
	    reportProgress("\n===== THE ARCTURUS 2 CONTIG LOADER HAS FINISHED =====");
	    
	    return nameToID;
    }
	
	protected void reportProgress(String message) {
    	System.out.println(message);
    	Arcturus.logInfo(message);
	}
	
	protected void importSAMReadGroupRecords(SAMFileReader reader, Project project) {
        SAMFileHeader header = reader.getFileHeader();
       
        int import_id = 0;
        import_id = adb.getLastImportId(project);
         
        reportProgress("BAMContigLoader:  Loading the Read groups from the SAM Header for import id " + import_id);

        try {
        	adb.addReadGroupsFromThisImport(header.getReadGroups(), import_id);
        } catch (ArcturusDatabaseException e) {
        	e.printStackTrace();
        }
       
	}
	
	protected Set<Contig> getContigs(SAMFileReader reader) {
        SAMFileHeader header = reader.getFileHeader();
         
     	SAMSequenceDictionary dictionary = header.getSequenceDictionary();
     	
      	List<SAMSequenceRecord> seqs = dictionary.getSequences();
      	
      	if (seqs.isEmpty())
     		throw new IllegalArgumentException("BAMContigLoader:  The input file is empty");
      	
        Set<Contig> contigs = new HashSet<Contig>();
        
     	for (SAMSequenceRecord record : seqs) {
      		String contigName = record.getSequenceName();
      		
      		Contig contig = new Contig(contigName);
      		
      		contig.setLength(record.getSequenceLength());
      		
      		contigs.add(contig);

      		reportProgress("BAMContigLoader:  Added contig " + contig.getID());
     	}
     	
        return contigs;      	
    }    
  
    private void importChildContigs(
			SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph,
			SAMFileReader reader, Map<String, Integer> nameToID) throws ArcturusDatabaseException {
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
 			
 			if (!doImport) {
 				//reportProgress("BAMContigLoader:  about to check if the tag sets are equal");
 				doImport = !contigComparator.equalsParentContigTags(child, parent);
 			}
 			
 			if (!doImport) {
 				child.setSequenceToContigMappings(null);
 				
 				nameToID.put(child.getName(), parent.getID());
 				
 				reportProgress("\nBAMContigLoader:  Child contig " + child.getName() + 
 						" (" + child.getLength() + " bp, " + child.getReadCount() + " reads)" + 
 						" is identical to parent contig " + parent.getName() +
						" (Arcturus ID " + parent.getID() + ", " + parent.getLength() + " bp, " + parent.getReadCount() + " reads, created " +
						parent.getCreated() + ") and does not need to be imported.");
 			}
    	}
    	
    	if (doImport) {
    		
    		storeChildContigs(children, reader, nameToID);
    		
    		Set<DefaultWeightedEdge> edges = graph.edgeSet();
    		
    		for (DefaultWeightedEdge edge : edges) {
    			Contig child = graph.getEdgeSource(edge);
    			
    			Contig parent = graph.getEdgeTarget(edge);
    			
    			int mapping_id = adb.setChildContig(parent, child);
    			Arcturus.logFine("BAMContigLoader:  Parent contig #" + parent.getID() +
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

    private void storeChildContigs(Set<Contig> contigs, SAMFileReader reader, Map<String, Integer> nameToID)
    	throws ArcturusDatabaseException {	
    	for (Contig contig : contigs) {
    		String message = "storeChildContigs: Contig " + contig.getName() + 
				" (" + contig.getLength() + " bp, " + contig.getReadCount() +
				" reads) will be stored in the database.";
    		
    		Arcturus.logFine(message);
    		
    		reportProgress("\n" + message);
    		
     		// this has already been done in importChildContigs so that the comparison can be done for mappings and tags
    		// contigBuilder.addMappingsToContig(contig, reader);
     		    	    
    	    adb.putContig(contig);
    	    
    	    nameToID.put(contig.getName(), contig.getID());
    	    
    	    message = "storeChildContigs: Stored contig " + contig.getName() + " with Arcturus ID " + contig.getID() + " tags: " + contig.getTagCount() + " mappings: " + contig.getSequenceToContigMappingsCount();
    	    
    	    Utility.reportMemory(message);
    	    
    	    reportProgress(message);
    	    
    	    contig.setSequenceToContigMappings(null);
    	}
    }
}

