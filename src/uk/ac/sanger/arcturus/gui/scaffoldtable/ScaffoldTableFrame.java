package uk.ac.sanger.arcturus.gui.scaffoldtable;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;

import javax.swing.*;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

public class ScaffoldTableFrame extends MinervaFrame implements
		ScaffoldBuilderListener {
	protected ScaffoldTable table = null;
	protected ScaffoldTableModel model = null;
	protected JMenu projectMenu = null;

	public ScaffoldTableFrame(Minerva minerva, String title,
			ArcturusDatabase adb, Set projectSet) {
		super(minerva, title);

		Set scaffoldSet = createScaffoldSet(projectSet, adb);

		model = new ScaffoldTableModel(scaffoldSet);

		table = new ScaffoldTable(this, model);

		JScrollPane scrollpane = new JScrollPane(table);

		JPanel panel = new JPanel(new BorderLayout());

		panel.add(scrollpane, BorderLayout.CENTER);
		panel.setPreferredSize(new Dimension(900, 530));

		setContentPane(panel);

		pack();
		setVisible(true);
	}

	class ViewScaffoldAction extends AbstractAction {
		public ViewScaffoldAction(String name) {
			super(name);
		}

		public void actionPerformed(ActionEvent event) {
			table.displaySelectedScaffolds();
		}
	}

	protected Set createScaffoldSet(Set projectSet, ArcturusDatabase adb) {
		int minlen = 5000;

		SortedSet contigset = new TreeSet(new ContigLengthComparator());

		for (Iterator iterator = projectSet.iterator(); iterator.hasNext();) {
			Project project = (Project) iterator.next();

			try {
				Set contigSet = adb.getContigsByProject(project.getID(),
						ArcturusDatabase.CONTIG_BASIC_DATA, minlen);

				contigset.addAll(contigSet);
			} catch (Exception e) {
			}
		}

		SortedSet savedset = new TreeSet(contigset);

		ScaffoldBuilder sb = new ScaffoldBuilder(adb);

		BridgeSet bs = null;

		try {
			bs = sb.processContigSet(contigset, this);
		} catch (Exception e) {
		}

		Set scaffoldSet = extractSubgraphs(bs, savedset);

		return scaffoldSet;
	}

	private Set extractSubgraphs(BridgeSet bs, Set contigset) {
		Set subgraphs = new HashSet();
		
		for (Iterator iterator = contigset.iterator(); iterator.hasNext();) {
			Contig contig = (Contig) iterator.next();

			Set subgraph = bs.getSubgraph(contig, 2);

			if (subgraph != null && !subgraph.isEmpty()) {
				if (!subgraphs.contains(subgraph)) {
					System.out.println();
					System.out.println("Scaffold for Contig " + contig.getID()
							+ ":");

					for (Iterator iterator2 = subgraph.iterator(); iterator2
							.hasNext();)
						System.out.println(iterator2.next());

					subgraphs.add(subgraph);
				}
			}
		}

		return subgraphs;
	}

	class ContigLengthComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			Contig c1 = (Contig) o1;
			Contig c2 = (Contig) o2;

			return c2.getLength() - c1.getLength();
		}
	}

	public void scaffoldUpdate(ScaffoldEvent event) {
	}
}
