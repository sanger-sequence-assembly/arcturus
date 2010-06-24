package uk.ac.sanger.arcturus.samtools;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

public class GraphBuilder {
	protected ArcturusDatabase adb = null;
	protected BAMReadLoader brl = null;
	
	public GraphBuilder(ArcturusDatabase adb, BAMReadLoader brl) {
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
    		String referenceSequenceName = contigs[i].getName();
 
     		CloseableIterator<SAMRecord> iterator = reader.query(referenceSequenceName, 0, 0, false);
	     	   	
     		while (iterator.hasNext()) {
     		    SAMRecord record = iterator.next();
    		    String readName = record.getReadName();
    		    int flags = record.getFlags();

    		    try {
    			    int maskedFlags = Utility.maskReadFlags(flags);
    				Read read = new Read(readName,maskedFlags);
    		        Contig parent = adb.getCurrentContigForRead(read);
	    		        
    		        if (parent != null) {
    		        	addOrUpdateLink(graph, contigs[i], parent);
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
	    	graph.addVertex(contig);
	    	graph.addVertex(parent);
	    	edge = graph.addEdge(contig,parent);
	    	graph.setEdgeWeight(edge, 1.0);
	    }
    }

}
