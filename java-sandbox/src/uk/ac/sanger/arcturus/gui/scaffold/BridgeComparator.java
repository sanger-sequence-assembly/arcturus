package uk.ac.sanger.arcturus.gui.scaffold;

import java.util.Comparator;

import uk.ac.sanger.arcturus.scaffold.Bridge;

public class BridgeComparator implements Comparator<Bridge> {
	public int compare(Bridge bridgea, Bridge bridgeb) {
		return bridgeb.getLinkCount() - bridgea.getLinkCount();
	}
}
