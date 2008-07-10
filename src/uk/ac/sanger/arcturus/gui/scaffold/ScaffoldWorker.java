package uk.ac.sanger.arcturus.gui.scaffold;

import java.util.*;

import javax.swing.JOptionPane;

import org.jdesktop.swingworker.SwingWorker;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.MinervaTabbedPane;
import uk.ac.sanger.arcturus.scaffold.Bridge;
import uk.ac.sanger.arcturus.scaffold.ScaffoldBuilder;

public class ScaffoldWorker extends SwingWorker<Void, Void> {
	protected final ArcturusDatabase adb;
	protected final MinervaTabbedPane mtp;
	protected final Contig seedcontig;
	protected Set bridgeset;
	protected ContigBox[] contigBoxes;
	
	public ScaffoldWorker(Contig seedcontig, MinervaTabbedPane mtp, ArcturusDatabase adb) {
		this.adb = adb;
		this.mtp = mtp;
		this.seedcontig = seedcontig;
	}
	
	protected Void doInBackground() throws Exception {
		boolean cacheing = adb.getSequenceManager().isCacheing();
		
		adb.getSequenceManager().setCacheing(false);

		ScaffoldBuilder sb = new ScaffoldBuilder(adb);

		bridgeset = sb.createScaffold(seedcontig.getID(), null);
		
		adb.getSequenceManager().setCacheing(cacheing);
		
		if (bridgeset != null && !bridgeset.isEmpty()) {
			Map layout = createLayout(bridgeset);

			contigBoxes = (ContigBox[]) layout.values().toArray(new ContigBox[0]);

			Arrays.sort(contigBoxes, new ContigBoxComparator());

		}		

		return null;
	}

	protected Map createLayout(Set bridges) {
		Map layout = new HashMap();
		RowRanges rowranges = new RowRanges();

		Vector bridgevector = new Vector(bridges);

		Collections.sort(bridgevector, new BridgeComparator());

		Bridge bridge = (Bridge) bridgevector.firstElement();
		bridgevector.removeElementAt(0);

		Contig contiga = bridge.getContigA();
		Contig contigb = bridge.getContigB();
		int endcode = bridge.getEndCode();
		int gapsize = bridge.getGapSize().getMinimum();

		Range rangea = new Range(0, contiga.getLength());

		int rowa = rowranges.addRange(rangea, 0);

		ContigBox cba = new ContigBox(contiga, rowa, rangea, true);
		layout.put(contiga, cba);

		ContigBox cbb = calculateRelativePosition(cba, contiga, contigb,
				endcode, gapsize, rowranges);
		layout.put(contigb, cbb);

		while (bridgevector.size() > 0) {
			bridge = null;

			boolean hasa = false;
			boolean hasb = false;

			for (int i = 0; i < bridgevector.size(); i++) {
				Bridge nextbridge = (Bridge) bridgevector.elementAt(i);

				contiga = nextbridge.getContigA();
				contigb = nextbridge.getContigB();

				hasa = layout.containsKey(contiga);
				hasb = layout.containsKey(contigb);

				if (hasa || hasb) {
					bridge = nextbridge;
					bridgevector.removeElementAt(i);
					break;
				}
			}

			if (bridge != null) {
				if (hasa && hasb) {
				} else {
					endcode = bridge.getEndCode();
					gapsize = bridge.getGapSize().getMinimum();

					if (hasa) {
						cba = (ContigBox) layout.get(contiga);

						cbb = calculateRelativePosition(cba, contiga, contigb,
								endcode, gapsize, rowranges);
						layout.put(contigb, cbb);
					} else {
						cbb = (ContigBox) layout.get(contigb);

						if (endcode == 0 || endcode == 3)
							endcode = 3 - endcode;

						cba = calculateRelativePosition(cbb, contigb, contiga,
								endcode, gapsize, rowranges);
						layout.put(contiga, cba);
					}
				}
			} else {
				break;
			}
		}

		normaliseLayout(layout);

		return layout;
	}

	private ContigBox calculateRelativePosition(ContigBox cba, Contig contiga,
			Contig contigb, int endcode, int gapsize, RowRanges rowranges) {
		int starta = cba.getRange().getStart();
		boolean forwarda = cba.isForward();
		int lengtha = contiga.getLength();
		int enda = starta + lengtha;
		int rowa = cba.getRow();

		boolean forwardb = (endcode == 0 || endcode == 3) ? forwarda
				: !forwarda;

		int startb;
		int endb;

		if ((endcode > 1) ^ forwarda) {
			startb = enda + gapsize;
			endb = startb + contigb.getLength() - 1;
		} else {
			endb = starta - gapsize;
			startb = endb - contigb.getLength() + 1;
		}

		Range rangeb = new Range(startb, endb);

		int rowb = rowranges.addRange(rangeb, rowa);

		return new ContigBox(contigb, rowb, rangeb, forwardb);
	}

	private void normaliseLayout(Map layout) {
		int xmin = 0;

		for (Iterator iterator = layout.entrySet().iterator(); iterator
				.hasNext();) {
			Map.Entry mapentry = (Map.Entry) iterator.next();
			ContigBox cb = (ContigBox) mapentry.getValue();
			int left = cb.getRange().getStart();
			if (left < xmin)
				xmin = left;
		}

		if (xmin == 0)
			return;

		xmin = -xmin;

		for (Iterator iterator = layout.entrySet().iterator(); iterator
				.hasNext();) {
			Map.Entry mapentry = (Map.Entry) iterator.next();
			ContigBox cb = (ContigBox) mapentry.getValue();
			cb.getRange().shift(xmin);
		}
	}

	protected void done() {
		if (bridgeset != null && !bridgeset.isEmpty()) {
			ScaffoldPanel sp = new ScaffoldPanel(contigBoxes, bridgeset, seedcontig, mtp, adb);
			mtp.addTab("Scaffold", sp);
			mtp.setSelectedComponent(sp);
		} else {
			JOptionPane.showMessageDialog(null,
					"No scaffold could be built from the selected contig",
					"Unable to scaffold", JOptionPane.WARNING_MESSAGE, null);

		}
	}
}
