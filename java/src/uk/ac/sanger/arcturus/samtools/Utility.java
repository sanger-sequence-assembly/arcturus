package uk.ac.sanger.arcturus.samtools;

import java.io.PrintStream;
import java.text.DecimalFormat;
import java.util.List;
import java.util.Set;
import java.util.Vector;
import java.util.zip.DataFormatException;
import java.util.zip.Inflater;

import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleDirectedWeightedGraph;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;

public class Utility {
	private static final String NL = "\n";
	
	private static final int READ_FLAGS_MASK = 128 + 64 + 1;
	
	private static final Inflater decompresser = new Inflater();

	public static final int maskReadFlags(int flags) {
		return flags & READ_FLAGS_MASK;
	}

	public static byte[] reverseComplement(byte[] src) {
		if (src == null)
			return null;
		
		int srclen = src.length;
		
		byte[] dst = new byte[srclen];
		
		int j = srclen - 1;
		
		for (int i = 0; i < srclen; i++)
			dst[j--] = reverseComplement(src[i]);
		
		return dst;
	}
	
	private static byte reverseComplement(byte c) {
		switch (c) {
			case 'a': return 't';
			case 'A': return 'T';
			
			case 'c': return 'g';
			case 'C': return 'G';
			
			case 'g': return 'c';
			case 'G': return 'C';
			
			case 't': return 'a';
			case 'T': return 'A';
			
			default: return c;
		}
	}
	
	public static byte[] reverseQuality(byte[] src) {
		if (src == null)
			return null;
		
		int srclen = src.length;
		
		byte[] dst = new byte[srclen];
		
		int j = srclen - 1;
		
		for (int i = 0; i < srclen; i++)
			dst[j--] = src[i];
		
		return dst;
	}

	public static byte[] decodeCompressedData(byte[] compressed, int length) throws DataFormatException {
		byte[] buffer = new byte[length];

		decompresser.setInput(compressed, 0, compressed.length);
		decompresser.inflate(buffer, 0, buffer.length);
		decompresser.reset();

		return buffer;
	}

	private static long T0 = System.currentTimeMillis();
	
	private static DecimalFormat format;
	
	static {
		format = new DecimalFormat();
		format.setGroupingSize(3);
	}
	
	public static void reportMemory(String message) {
		Runtime rt = Runtime.getRuntime();
		
		long freeMemory = rt.freeMemory();
		long totalMemory = rt.totalMemory();
		
		long usedMemory = totalMemory - freeMemory;
		
		freeMemory /= 1024;
		totalMemory /= 1024;
		usedMemory /= 1024;
		
		long t = System.currentTimeMillis();
		
		long dt = t - T0;
		
		T0 = t;
		
		Arcturus.logFine(message + " ; Memory used " + format.format(usedMemory) + " kb, free " +
				format.format(freeMemory) + " kb, total " + format.format(totalMemory) +
				" kb ; dt = " + format.format(dt) + " ms");
		
		System.out.println(message + " ; Memory used " + format.format(usedMemory) + " kb, free " +
				format.format(freeMemory) + " kb, total " + format.format(totalMemory) +
				" kb ; dt = " + format.format(dt) + " ms");
	}
	   
    public static void displayGraph(String caption, SimpleDirectedWeightedGraph<Contig, DefaultWeightedEdge> graph) {
        Set<Contig> vertices = graph.vertexSet();
        
        StringBuilder sb = new StringBuilder();
        
        sb.append(caption + NL + NL);
       
        sb.append("CHILD VERTICES" + NL);
       
        List<Contig> children = new Vector<Contig>();
       
        for (Contig contig : vertices) {
            if (graph.inDegreeOf(contig) == 0) {
                sb.append("\t" + contig + NL);
                children.add(contig);
            }
        }
       
        sb.append(NL);
       
        sb.append("PARENT VERTICES" + NL);
       
        for (Contig contig : vertices) {
            if (graph.inDegreeOf(contig) > 0)
            	sb.append("\t" + contig + NL);
        }
       
        sb.append(NL);
       
        sb.append("EDGES" + NL);
       
        for (Contig child : children) {
            Set<DefaultWeightedEdge> outEdges = graph.outgoingEdgesOf(child);
           
            for (DefaultWeightedEdge outEdge : outEdges) {
                Contig parent = graph.getEdgeTarget(outEdge);
                double weight = graph.getEdgeWeight(outEdge);
               
                sb.append("\n\t" + child + "\n\t\t|\n\t\t| [" + weight + "]\n\t\tV\n\t" + parent + NL);
            }
           
            sb.append(NL);
        }
        
        Arcturus.logFine(sb.toString());
    }
}
