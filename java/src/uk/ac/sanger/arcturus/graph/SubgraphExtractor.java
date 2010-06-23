package uk.ac.sanger.arcturus.graph;

import java.util.HashSet;
import java.util.Set;
import java.util.SortedSet;
import java.util.TreeSet;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

public class SubgraphExtractor<V> {
	public Set<SimpleDirectedWeightedGraph<V, DefaultWeightedEdge>> analyseSubgraphs(SimpleDirectedWeightedGraph<V, DefaultWeightedEdge> graph) {
		Set<SimpleDirectedWeightedGraph<V, DefaultWeightedEdge>> resultSet =
			new HashSet<SimpleDirectedWeightedGraph<V, DefaultWeightedEdge>>();
		
		Set<V> vertexSet = graph.vertexSet();
		
		SortedSet<V> allChildren = new TreeSet<V>();
		
		for (V vertex : vertexSet)
			if (graph.outDegreeOf(vertex) > 0)
				allChildren.add(vertex);
		
		while (!allChildren.isEmpty()) {
			V nextChild = pop(allChildren);
			
			SortedSet<V> childrenToProcess = new TreeSet<V>();
			
			childrenToProcess.add(nextChild);
			
			SimpleDirectedWeightedGraph<V, DefaultWeightedEdge> subgraph =
				new SimpleDirectedWeightedGraph<V, DefaultWeightedEdge>(DefaultWeightedEdge.class);
			
			while (!childrenToProcess.isEmpty()) {
				V child = pop(childrenToProcess);

				allChildren.remove(child);
				
				subgraph.addVertex(child);
				
				Set<DefaultWeightedEdge> outEdges = graph.outgoingEdgesOf(child);
				
				for (DefaultWeightedEdge outEdge : outEdges) {
					V parent = graph.getEdgeTarget(outEdge);
					
					if (!subgraph.containsVertex(parent)) {
						subgraph.addVertex(parent);
						
						Set<DefaultWeightedEdge> inEdges = graph.incomingEdgesOf(parent);
						
						for (DefaultWeightedEdge inEdge : inEdges) {
							V child2 = graph.getEdgeSource(inEdge);
							
							if (!subgraph.containsVertex(child2))
								childrenToProcess.add(child2);
						}
					}
					
					DefaultWeightedEdge edge = subgraph.addEdge(child, parent);
					subgraph.setEdgeWeight(edge, graph.getEdgeWeight(outEdge));
				}
			}
			
			resultSet.add(subgraph);
		}
		
		return resultSet;
	}
	
	private V pop(SortedSet<V> set) {
		if (set == null || set.isEmpty())
			return null;
			
		synchronized (set) {
			V vertex = set.first();
			set.remove(vertex);
			return vertex;
		}
	}

}
