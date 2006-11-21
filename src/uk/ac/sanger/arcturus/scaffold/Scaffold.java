package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.data.*;
import java.util.*;

public class Scaffold {
	protected int totalLength = 0;
	protected int contigCount = 0;
	protected Set bridgeSet = null;
	protected Set contigSet = null;
	
	public Scaffold(Set bridgeSet) {
		this.bridgeSet = bridgeSet;
		
		for (Iterator iterator = bridgeSet.iterator(); iterator.hasNext();) {
			Bridge bridge = (Bridge) iterator.next();
			
			Contig contiga = bridge.getContigA();
			contigSet.add(contiga);
			
			Contig contigb = bridge.getContigB();
			contigSet.add(contigb);
		}
		
		contigCount = contigSet.size();
		
		for (Iterator iterator = contigSet.iterator(); iterator.hasNext();) {
			Contig contig = (Contig) iterator.next();
			totalLength += contig.getLength();
		}
	}

	public int getContigCount() {
		return contigCount;
	}
	
	public int getTotalLength() {
		return totalLength;
	}
	
	public Set getContigSet() {
		return new HashSet(contigSet);
	}
	
	public boolean containsContig(Contig contig) {
		return contigSet.contains(contig);
	}
}
