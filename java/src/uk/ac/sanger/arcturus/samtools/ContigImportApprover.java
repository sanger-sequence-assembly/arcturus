package uk.ac.sanger.arcturus.samtools;

import java.io.PrintStream;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public interface ContigImportApprover {
	public boolean approveImport(SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph,
			Project targetProject, PrintStream reportStream) throws ArcturusDatabaseException;
}
