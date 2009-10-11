package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Template;

import java.util.*;
import java.io.PrintStream;

public class BridgeSet {
	private HashMap byContigA = new HashMap();
	private Set allBridges = new HashSet();

	private Bridge getBridge(Contig contiga, Contig contigb, int endcode) {
		// Enforce the condition that the first contig must have the smaller ID.
		if (contigb.getID() < contiga.getID()) {
			Contig temp = contiga;
			contiga = contigb;
			contigb = temp;

			if (endcode == 0 || endcode == 3)
				endcode = 3 - endcode;
		}

		HashMap byContigB = (HashMap) byContigA.get(contiga);

		if (byContigB == null) {
			byContigB = new HashMap();
			byContigA.put(contiga, byContigB);
		}

		HashMap byEndCode = (HashMap) byContigB.get(contigb);

		if (byEndCode == null) {
			byEndCode = new HashMap();
			byContigB.put(contigb, byEndCode);
		}

		Integer intEndCode = new Integer(endcode);

		Bridge bridge = (Bridge) byEndCode.get(intEndCode);

		if (bridge == null) {
			bridge = new Bridge(contiga, contigb, endcode);
			byEndCode.put(intEndCode, bridge);
			allBridges.add(bridge);
		}

		return bridge;
	}

	public void addBridge(Contig contiga, Contig contigb, int endcode,
			Template template, ReadMapping mappinga, ReadMapping mappingb,
			GapSize gapsize) {
		Bridge bridge = getBridge(contiga, contigb, endcode);

		// Enforce the condition that the first contig must have the smaller ID.
		if (contigb.getID() < contiga.getID()) {
			ReadMapping temp = mappinga;
			mappinga = mappingb;
			mappingb = temp;
		}

		bridge.addLink(template, mappinga, mappingb, gapsize);
	}

	public HashMap getHashMap() {
		return byContigA;
	}

	public int getTemplateCount(Contig contiga, Contig contigb, int endcode) {
		Bridge bridge = getBridge(contiga, contigb, endcode);

		return (bridge == null) ? 0 : bridge.getLinkCount();
	}

	public void dump(PrintStream ps, int minlinks) {
		ps.println("BridgeSet.dump");
		for (Iterator iterator = allBridges.iterator(); iterator.hasNext();) {
			Bridge bridge = (Bridge) iterator.next();
			if (bridge.getLinkCount() >= minlinks)
				ps.println(bridge);
		}
	}

	public Set getSubgraph(Contig seedcontig, int minlinks) {
		Set contigsToProcess = new HashSet();
		Set subgraph = new HashSet();
		Set newContigs = new HashSet();

		Set all = new HashSet(allBridges);

		contigsToProcess.add(seedcontig);

		while (!contigsToProcess.isEmpty()) {
			newContigs.clear();

			for (Iterator iterator = all.iterator(); iterator.hasNext();) {
				Bridge bridge = (Bridge) iterator.next();

				if (bridge.getLinkCount() < minlinks) {
					iterator.remove();
					continue;
				}

				Contig contiga = bridge.getContigA();
				Contig contigb = bridge.getContigB();

				boolean toProcessA = contigsToProcess.contains(contiga);
				boolean toProcessB = contigsToProcess.contains(contigb);

				if (toProcessA || toProcessB) {
					iterator.remove();

					if (bridge.getLinkCount() >= minlinks) {
						subgraph.add(bridge);

						if (!toProcessA)
							newContigs.add(contiga);

						if (!toProcessB)
							newContigs.add(contigb);
					}
				}
			}

			contigsToProcess.clear();

			contigsToProcess.addAll(newContigs);
		}

		return subgraph.isEmpty() ? null : subgraph;
	}
}
