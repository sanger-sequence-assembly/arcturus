package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Template;

import java.util.*;
import java.io.PrintStream;

public class BridgeSet {
    private HashMap byContigA = new HashMap();

    public void addBridge(Contig contiga, Contig contigb, int endcode, Template template,
			  ReadMapping mappinga, ReadMapping mappingb, GapSize gapsize) {
	// Enforce the condition that the first contig must have the smaller ID.
	if (contigb.getID() < contiga.getID()) {
	    Contig temp = contiga;
	    contiga = contigb;
	    contigb = temp;

	    if (endcode == 0 || endcode == 3)
		endcode = 3 - endcode;
	}

	HashMap byContigB = (HashMap)byContigA.get(contiga);

	if (byContigB == null) {
	    byContigB = new HashMap();
	    byContigA.put(contiga, byContigB);
	}

	HashMap byEndCode = (HashMap)byContigB.get(contigb);

	if (byEndCode == null) {
	    byEndCode = new HashMap();
	    byContigB.put(contigb, byEndCode);
	}

	Integer intEndCode = new Integer(endcode);

	Bridge bridge = (Bridge)byEndCode.get(intEndCode);

	if (bridge == null) {
	    bridge = new Bridge(contiga, contigb, endcode);
	    byEndCode.put(intEndCode, bridge);
	}

	bridge.addLink(template, mappinga, mappingb, gapsize);
    }

    public HashMap getHashMap() { return byContigA; }

    public int getTemplateCount(Contig contiga, Contig contigb, int endcode) {
	HashMap byContigB = (HashMap)byContigA.get(contiga);

	if (byContigB == null)
	    return 0;
	
	HashMap byEndCode = (HashMap)byContigB.get(contigb);
	
	if (byEndCode == null)
	    return 0;
	
	Integer intEndCode = new Integer(endcode);
	
	HashMap byTemplate = (HashMap)byEndCode.get(intEndCode);
	
	return (byTemplate == null) ? 0 : byTemplate.size();
    }
    
    public void dump(PrintStream ps, int minsize) {
	ps.println("BridgeSet.dump");
	
	Set entries = byContigA.entrySet();
	
	for (Iterator iterator = entries.iterator(); iterator.hasNext();) {
	    Map.Entry entry = (Map.Entry)iterator.next();
	    
	    Contig contiga = (Contig)entry.getKey();
	    HashMap byContigB = (HashMap)entry.getValue();
	    
	    Set entries2 = byContigB.entrySet();
	    
	    for (Iterator iterator2 = entries2.iterator(); iterator2.hasNext();) {
		Map.Entry entry2 = (Map.Entry)iterator2.next();
		
		Contig contigb = (Contig)entry2.getKey();
		HashMap byEndCode = (HashMap)entry2.getValue();
		
		Set entries3 = byEndCode.entrySet();
		
		for (Iterator iterator3 = entries3.iterator(); iterator3.hasNext();) {
		    Map.Entry entry3 = (Map.Entry)iterator3.next();
		    
		    Integer intEndCode = (Integer)entry3.getKey();
		    Bridge bridge = (Bridge)entry3.getValue();
		    
		    int mysize = bridge.getLinkCount();
		    GapSize gapsize = bridge.getGapSize();
		    
		    if (mysize >= minsize && contiga.getID() < contigb.getID())
			ps.println( contiga.getID() + " " + contiga.getLength() + " " +
				    contigb.getID() + " " + contigb.getLength() + " " +
				    intEndCode + " " + mysize + " " +
				    gapsize.getMinimum() + ":" + gapsize.getMaximum());
		}
	    }
	}	    
    }
}
