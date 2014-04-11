// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Template;

import java.util.*;
import java.io.PrintStream;

public class BridgeSet {
	private HashMap<Contig, HashMap<Contig, HashMap<Integer, Bridge>>> byContigA =
		new HashMap<Contig, HashMap<Contig, HashMap<Integer, Bridge>>>();
	private Set<Bridge> allBridges = new HashSet<Bridge>();

	private Bridge getBridge(Contig contiga, Contig contigb, int endcode) {
		// Enforce the condition that the first contig must have the smaller ID.
		if (contigb.getID() < contiga.getID()) {
			Contig temp = contiga;
			contiga = contigb;
			contigb = temp;

			if (endcode == 0 || endcode == 3)
				endcode = 3 - endcode;
		}

		HashMap<Contig, HashMap<Integer, Bridge>> byContigB = byContigA.get(contiga);

		if (byContigB == null) {
			byContigB = new HashMap<Contig, HashMap<Integer, Bridge>>();
			byContigA.put(contiga, byContigB);
		}

		HashMap<Integer, Bridge> byEndCode = byContigB.get(contigb);

		if (byEndCode == null) {
			byEndCode = new HashMap<Integer, Bridge>();
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

	public Set<Bridge> getSubgraph(Contig seedcontig, int minlinks) {
		Set<Contig> contigsToProcess = new HashSet<Contig>();
		Set<Bridge> subgraph = new HashSet<Bridge>();
		Set<Contig> newContigs = new HashSet<Contig>();

		Set<Bridge> all = new HashSet<Bridge>(allBridges);

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
