package uk.ac.sanger.arcturus.samtools;

import java.util.*;
import java.io.PrintStream;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

public class ContigGraphBuilder {
	protected ArcturusDatabase adb = null;
	protected BAMReadLoader brl = null;
	
	public ContigGraphBuilder(ArcturusDatabase adb, BAMReadLoader brl) {
		this.adb = adb;
		this.brl = brl;
	}
	
    /**
     * Builds a graph of SAMcontig - currentcontig relations 
     * @param contigs  list of SAMcontig instances
     * @param reader   SAMFileReader
     * @return SimpleDirectedWeighted graph with SAMcontig(s) and currentcontigs as vertexes
     */

	public SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> 
	        identifyParentsForContigs(Contig[] contigs, SAMFileReader reader) {
	
	    SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph = 
	    	new SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>(DefaultWeightedEdge.class);
		
     	for (int i=0 ; i < contigs.length ; i++) {
     		Contig contig = contigs[i];
    		String referenceSequenceName = contig.getName();
 
     		CloseableIterator<SAMRecord> iterator = reader.query(referenceSequenceName, 0, 0, false);
	     	   	
            int readCount = 0;
     		while (iterator.hasNext()) {
     		    SAMRecord record = iterator.next();
    		    String readName = record.getReadName();
    		    int flags = record.getFlags();
    		    readCount++;

    		    try {
    			    int maskedFlags = Utility.maskReadFlags(flags);
    				Read read = new Read(readName,maskedFlags);
    		        Contig parent = adb.getCurrentContigForRead(read);
	    		        
    		        if (parent != null) {
    		        	addOrUpdateLink(graph, contig, parent);
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
     		contig.setReadCount(readCount);
     	}
     	
     	return graph;
	}	 
	    
    private void addOrUpdateLink(SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph, 
		                         Contig contig, Contig parent) {
    	
	    DefaultWeightedEdge edge = graph.getEdge(contig, parent);
	    
	    if (edge != null) {
	    	double weight = graph.getEdgeWeight(edge);
	    	graph.setEdgeWeight(edge, weight+1.0);
	    }
	    else {
//	    	System.out.println("\nNew Vertex added\t" + contig + "\n\t\t\t" + parent);
	    	graph.addVertex(contig);
	    	graph.addVertex(parent);
	    	edge = graph.addEdge(contig,parent);
	    	graph.setEdgeWeight(edge, 1.0);
	    }
    }
    
    public boolean hasOneEdge(SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph) {
        Set<Contig> vertices = graph.vertexSet();
        int childCount = 0;
        int parentCount = 0;
        for (Contig contig : vertices) {
        	if (graph.outDegreeOf(contig) > 0)
        		childCount++;
        	if (graph.inDegreeOf(contig) > 0)
        		parentCount++;
        }
        return childCount == 1 && parentCount == 1;
    }
   
    public void displayGraph(PrintStream ps, SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph) {
        Set<Contig> vertices = graph.vertexSet();
       
        ps.println("CHILD VERTICES");
       
        List<Contig> children = new Vector<Contig>();
       
        for (Contig contig : vertices) {
            if (graph.outDegreeOf(contig) > 0) {
                ps.println("\t" + contig);
                children.add(contig);
            }
        }
       
        ps.println();
       
        ps.println("PARENT VERTICES");
       
        for (Contig contig : vertices) {
            if (graph.inDegreeOf(contig) > 0)
                ps.println("\t" + contig);
        }
       
        ps.println();
       
        ps.println("EDGES");
       
        for (Contig child : children) {
            Set<DefaultWeightedEdge> outEdges = graph.outgoingEdgesOf(child);
           
            for (DefaultWeightedEdge outEdge : outEdges) {
                Contig parent = graph.getEdgeTarget(outEdge);
                double weight = graph.getEdgeWeight(outEdge);
               
                ps.println("\t" + child + " ---[" + weight + "]---> " + parent);
            }
           
            ps.println();
        }
    }
}
