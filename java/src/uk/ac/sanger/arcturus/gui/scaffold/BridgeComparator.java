package uk.ac.sanger.arcturus.gui.scaffold;

import java.util.Comparator;

import uk.ac.sanger.arcturus.scaffold.Bridge;

public class BridgeComparator implements Comparator {
	public int compare(Object o1, Object o2) {
		Bridge bridgea = (Bridge) o1;
		Bridge bridgeb = (Bridge) o2;

		return bridgeb.getLinkCount() - bridgea.getLinkCount();
	}
}
