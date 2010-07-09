package uk.ac.sanger.arcturus.samtools;

import java.io.PrintStream;
import java.util.Set;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

import uk.ac.sanger.arcturus.Arcturus;
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
                if (!approveParentContig(contig, targetProject))
                	return false;
        }

		return true;
	}

	private boolean approveParentContig(Contig contig, Project targetProject) {
		Project parentProject = contig.getProject();
		
		if (parentProject == null) {
			Arcturus.logFine("Parent " + contig + " has no project: DENY");
			return false;
		}
		
		if (parentProject.equals(targetProject)) {
			Arcturus.logFine("Parent " + contig + " is in target project: APPROVE");
			return true;
		}
		
		if (parentProject.isLocked()) {
			Arcturus.logFine("Parent " + contig + " is in a locked project (" +
					parentProject.getName() + ") : DENY");
			return false;
		}
		
		if (parentProject.isUnowned()) {
			Arcturus.logFine("Parent " + contig + " is in an unowned project: APPROVE");
			return true;
		} else {
			Arcturus.logFine("Parent " + contig + " is in an owned project (" +
					parentProject.getName() + ", owned by " + parentProject.getOwner().getName() +
					") : DENY");		
			return false;
		}
	}

}
