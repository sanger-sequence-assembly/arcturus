package uk.ac.sanger.arcturus.samtools;

import java.util.Set;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import net.sf.samtools.*;
import net.sf.samtools.SAMRecordIterator;

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
     * Builds a graph which links child contigs from a BAM file with their parents in the
     * database, via shared reads.
     * 
     * @param contigs  set of child contigs from a BAM file
     * @param reader   the BAM file from which the child contigs were taken
     * @return graph the graph linking the child contigsto their parents
     */

	public SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> 
	        identifyParentsForContigs(Set<Contig> contigs, SAMFileReader reader) {
	
	    SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph = 
	    	new SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge>(DefaultWeightedEdge.class);
		
     	for (Contig contig : contigs)
     		identifyParentsForContig(contig, reader, graph);
     	
     	return graph;
	}
	
	private void identifyParentsForContig(Contig contig, SAMFileReader reader,
		SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph) {
		graph.addVertex(contig);
		
		String referenceSequenceName = contig.getName();

		SAMRecordIterator iterator = reader.query(
				referenceSequenceName, 0, 0, false);

		int readCount = 0;

		while (iterator.hasNext()) {
			SAMRecord record = iterator.next();
			
			String readName = record.getReadName();
			
			int flags = record.getFlags();
			
			readCount++;

			try {
				int maskedFlags = Utility.maskReadFlags(flags);
				
				Read read = new Read(readName, maskedFlags);
				
				Contig parent = adb.getCurrentContigForRead(read);

				if (parent != null)
					addOrUpdateLink(graph, contig, parent);				
			} catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("A problem occurred whilst identifying parent contigs for " + contig, e);
			}
		}

		iterator.close();
		
		contig.setReadCount(readCount);
	} 
	    
    private void addOrUpdateLink(SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph, 
		                         Contig contig, Contig parent) {   	
	    DefaultWeightedEdge edge = graph.getEdge(contig, parent);
	    
	    if (edge == null) {
	    	graph.addVertex(contig);
	    	graph.addVertex(parent);
	    	edge = graph.addEdge(contig,parent);
	    	graph.setEdgeWeight(edge, 1.0);
	    } else {
	    	double weight = graph.getEdgeWeight(edge);
	    	graph.setEdgeWeight(edge, weight+1.0);
	    }
    }
}
