package test.importer;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.samtools.*;
import uk.ac.sanger.arcturus.samtools.Utility;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

//import java.sql.Connection;
import java.text.DecimalFormat;
import java.util.*;
import java.io.PrintStream;

import uk.ac.sanger.arcturus.data.*;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;


public class BAMContigLoaderWrapper extends BAMContigLoader {
	private DecimalFormat format = new DecimalFormat();
	
	public BAMContigLoaderWrapper(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		super(adb,brl);
		format.setGroupingSize(3);
	}

    public void processFile(SAMFileReader reader, Project project, String contigName) throws ArcturusDatabaseException {
    	
    	System.out.println("USING TEST SCRIPT");
	    	
	    Contig[] contigs;
	    
	    if (contigName == null)
	    	contigs = getContigs(reader);
	    else {
	    	contigs = new Contig[1];
	    	contigs[0] = new Contig(contigName);
	    }
	    
	    for (Contig contig : contigs)
	    	contig.setProject(project);

System.out.println("before LM cache Memory usage: " + memoryUsage());

	    prepareLinkManagerCache(adb, project);

System.out.println("after LM cache Memory usage: " + memoryUsage());

//	    findParentsForContigs(contigs,reader); // for reference
	    
System.out.println("Building Graph");
	    
	    graph = gbuilder.identifyParentsForContigs(contigs,reader);
 
	    System.out.println("graph built");
    	System.out.println();
    	Utility.displayGraph(System.out, graph);
	    
	    discardLinkManagerCache(adb);

System.out.println("after LM cache removal: " + memoryUsage());

// get sub graphs
System.out.println("Analysing SubGraphs");
	    
	    Set<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> subGraphs = extractor.analyseSubgraphs(graph);

	    Iterator<SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>> iterator = subGraphs.iterator();
	    
	    while (iterator.hasNext()) {
	    	SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> subGraph = iterator.next();
	    	System.out.println();
	    	System.out.println("subgraph");
	    	System.out.println();
	    	Utility.displayGraph(System.out, subGraph);
	    }
	    
	    System.out.println("before loading canonical mappings Memory usage: " + memoryUsage());
	    
	    adb.preloadCanonicalMappings();

	    System.out.println("after loading CMsMemory usage: " + memoryUsage());
/*
	    addMappingsToContigs(contigs, reader);
*/	    
    }
    
    
	

	private void findParentsForContigs(Contig[] contigs, SAMFileReader reader) {
		
	     	for (int i=0 ; i < contigs.length ; i++) {
	    		String referenceSequenceName = contigs[i].getName();
	     		System.out.println("Processing contig " + referenceSequenceName);
	 
	     		CloseableIterator<SAMRecord> iterator = reader.query(referenceSequenceName, 0, 0, false);

	     	   	Map<Integer,Integer> graph = new HashMap<Integer,Integer>();
	     	   	
	     		while (iterator.hasNext()) {
	     		    SAMRecord record = iterator.next();
	    		    String readName = record.getReadName();
	    		    int flags = record.getFlags();
// System.out.println("get readname " + readName + " flag " + flags);

	    		    try {
	    			    int maskedFlags = Utility.maskReadFlags(flags);
	    				Read read = new Read(readName,maskedFlags);
	    		        Contig parent = adb.getCurrentContigForRead(read);	    		        

	    		        if (parent != null) {
	    		            int parent_id = parent.getID();

	     		    	    int count = 0;
	     		    	    if (graph.containsKey(parent_id))
	     		    		    count = (Integer)graph.get(parent_id);
	     		    	    count++;
	     		    	    graph.put(parent_id, count);
	     		        }
	     		        else if (parent == null &&  brl != null) 
	     		        	// the read is not in a current contig or not in the database; try load it
 		             	    brl.findOrCreateSequence(record);

	     		    }
	    		    catch (ArcturusDatabaseException e) {
	    		    	System.err.println(e + " possibly database access lost");
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
	     	
	}	 
	    
	
		public void writeImportMarker() {
			
		}
		   
	    private String memoryUsage() {
	    	Runtime rt = Runtime.getRuntime();
	    	
	    	long totalMemory = rt.totalMemory()/1024;
	    	long freeMemory = rt.freeMemory()/1024;
	    	
	    	long usedMemory = totalMemory - freeMemory;
	    	
	    	return "used = " + format.format(usedMemory) + " kb, free = " +
	    		format.format(freeMemory) + " kb, total = " +
	    		format.format(totalMemory) + " kb";
	    }

}
