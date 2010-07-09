package uk.ac.sanger.arcturus.samtools;

import java.io.PrintStream;
import java.util.HashSet;
import java.util.Set;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class SimpleContigImportApprover implements ContigImportApprover {
	private String reason = null;
	
	public boolean approveImport(
			SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph,
			Project targetProject, PrintStream reportStream)
			throws ArcturusDatabaseException {
        Set<Contig> vertices = graph.vertexSet();
        
        for (Contig contig : vertices) {
            if (graph.inDegreeOf(contig) > 0) {
            	Set<DefaultWeightedEdge> inEdges = graph.incomingEdgesOf(contig);
            	
            	Set<Contig> children = new HashSet<Contig>();
            	
            	for (DefaultWeightedEdge inEdge : inEdges)
            		children.add(graph.getEdgeSource(inEdge));
            	
                if (!approveParentContig(contig, targetProject, children))
                	return false;
            }
        }

		return true;
	}

	private boolean approveParentContig(Contig contig, Project targetProject, Set<Contig> children) {
		Project parentProject = contig.getProject();
		
		String prefix = "Parent " + contig + " of ";
		
		boolean first = true;
		
		for (Contig child : children) {
			if (first)
				first = false;
			else
				prefix += ",";
			
			prefix += child;
		}
		
		if (parentProject == null) {
			reason = prefix + " has no project";
			Arcturus.logFine(reason + " : DENY");
			return false;
		}
		
		if (parentProject.equals(targetProject)) {
			reason = prefix + " is in target project";
			Arcturus.logFine(reason + " : APPROVE");
			return true;
		}
		
		if (parentProject.isLocked()) {
			reason = prefix + " is in a locked project (" +
				parentProject.getName() + ")";
			Arcturus.logFine(reason + " : DENY");
			return false;
		}
		
		if (parentProject.isUnowned()) {
			reason = prefix + " is in an unowned project";
			Arcturus.logFine(reason + " : APPROVE");
			return true;
		} else {
			reason = prefix + " is in an owned project (" +
				parentProject.getName() + ", owned by " + parentProject.getOwner().getName() + ")";
			Arcturus.logFine(reason + " : DENY");
			return false;
		}
	}

	public String getReason() {
		return reason;
	}

}
