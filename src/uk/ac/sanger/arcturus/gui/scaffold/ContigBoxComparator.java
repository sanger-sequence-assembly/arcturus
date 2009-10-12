package uk.ac.sanger.arcturus.gui.scaffold;

import java.util.Comparator;

public class ContigBoxComparator implements Comparator<ContigBox> {
	public int compare(ContigBox box1, ContigBox box2) {
		int diff = box1.getLeft() - box2.getLeft();

		if (diff != 0)
			return diff;

		diff = box1.getRight() - box2.getRight();

		if (diff != 0)
			return diff;
		else
			return box1.getRow() - box2.getRow();
	}
}
