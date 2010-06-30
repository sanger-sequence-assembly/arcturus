package uk.ac.sanger.arcturus.samtools;

import java.io.PrintStream;
import java.util.Set;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class SimpleContigImportApprover implements ContigImportApprover {
	public boolean approveImport(
			SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph,
			Project targetProject, PrintStream reportStream)
			throws ArcturusDatabaseException {
        Set<Contig> vertices = graph.vertexSet();
        
        for (Contig contig : vertices) {
            if (graph.inDegreeOf(contig) > 0)
                if (!approveParentContig(contig, targetProject, reportStream))
                	return false;
        }

		return false;
	}

	private boolean approveParentContig(Contig contig, Project targetProject, PrintStream reportStream) {
		Project parentProject = contig.getProject();
		
		if (parentProject == null) {
			reportStream.println("Parent " + contig + " has no project: DENY");
			return false;
		}
		
		if (parentProject.equals(targetProject)) {
			reportStream.println("Parent " + contig + " is in target project: APPROVE");
			return true;
		}
		
		if (parentProject.isLocked()) {
			reportStream.println("Parent " + contig + " is in a locked project: DENY");
			return false;
		}
		
		if (parentProject.isUnowned()) {
			reportStream.println("Parent " + contig + " is in an unowned project: APPROVE");
			return true;
		}
		
		reportStream.println("Parent " + contig + " default action: DENY");
		
		return false;
	}

}
