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

package uk.ac.sanger.arcturus.gui.scaffoldtable;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.scaffold.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.util.*;

import javax.swing.*;
import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;

public class ScaffoldTableFrame extends MinervaFrame {
	protected ScaffoldTable table = null;
	protected ScaffoldTableModel model = null;
	protected JMenu projectMenu = null;

	public ScaffoldTableFrame(Minerva minerva, String title,
			ArcturusDatabase adb, Set scaffoldSet) {
		super(minerva, title, null);

		model = new ScaffoldTableModel(scaffoldSet);

		table = new ScaffoldTable(model);

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

	public static void createAndShowFrame(Minerva minerva, String title,
			ArcturusDatabase adb, Set projectSet) {
		ScaffoldSetTask task = new ScaffoldSetTask(minerva, title, adb,
				projectSet);
		Thread thread = new Thread(task);
		thread.start();
	}
}

class ScaffoldSetTask implements Runnable {
	private final Set projectSet;
	private final ArcturusDatabase adb;
	private final Minerva minerva;
	private final String title;

	public ScaffoldSetTask(Minerva minerva, String title, ArcturusDatabase adb,
			Set projectSet) {
		this.minerva = minerva;
		this.title = title;
		this.adb = adb;
		this.projectSet = projectSet;
	}

	public void run() {
		final Set scaffoldSet = createScaffoldSet();

		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				ScaffoldTableFrame frame = new ScaffoldTableFrame(minerva,
						title, adb, scaffoldSet);

				//minerva.displayNewFrame(frame);
			}
		});
	}

	private Set createScaffoldSet() {
		int minlen = 5000;

		SortedSet contigset = new TreeSet(new ContigLengthComparator());

		for (Iterator iterator = projectSet.iterator(); iterator.hasNext();) {
			Project project = (Project) iterator.next();

			try {
				Set contigSet = adb.getContigsByProject(project.getID(),
						ArcturusDatabase.CONTIG_BASIC_DATA, minlen);

				contigset.addAll(contigSet);
			} catch (Exception e) {
				Arcturus.logWarning(e);
			}
		}

		SortedSet savedset = new TreeSet(contigset);

		ScaffoldBuilder sb = null;
		
		try {
			sb = new ScaffoldBuilder(adb);
		} catch (ArcturusDatabaseException e1) {
			Arcturus.logWarning("Failed to create a scaffold builder", e1);
		}
		
		if (sb == null)
			return null;

		BridgeSet bs = null;

		ScaffoldBuilderMonitor monitor = new ScaffoldBuilderMonitor(savedset
				.size());

		try {
			bs = sb.processContigSet(contigset, monitor);
		} catch (Exception e) {
			Arcturus.logWarning("Failed to process contig set for scaffold building", e);
		}

		Set scaffoldSet = extractSubgraphs(bs, savedset, monitor);

		return scaffoldSet;
	}

	private Set extractSubgraphs(BridgeSet bs, Set contigset,
			ScaffoldBuilderMonitor monitor) {
		Set subgraphs = new HashSet();

		String message = "Finding sub-graphs";

		ScaffoldEvent event = (monitor != null) ? new ScaffoldEvent(Minerva
				.getInstance()) : null;

		int nContigs = 0;

		for (Iterator iterator = contigset.iterator(); iterator.hasNext();) {
			Contig contig = (Contig) iterator.next();

			nContigs++;

			if (monitor != null) {
				event.setState(ScaffoldEvent.FINDING_SUBGRAPHS, message,
						new Integer(nContigs));

				monitor.scaffoldUpdate(event);
			}

			Set subgraph = bs.getSubgraph(contig, 2);

			if (subgraph != null && !subgraph.isEmpty()) {
				subgraphs.add(subgraph);
			}
		}

		if (monitor != null)
			monitor.closeProgressMonitor();

		return subgraphs;
	}

	class ContigLengthComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			Contig c1 = (Contig) o1;
			Contig c2 = (Contig) o2;

			return c2.getLength() - c1.getLength();
		}
	}

	class ScaffoldBuilderMonitor implements ScaffoldBuilderListener {
		private int nContigs;
		ProgressMonitor monitor = null;

		public ScaffoldBuilderMonitor(int nContigs) {
			this.nContigs = nContigs;

			monitor = new ProgressMonitor(null, "Creating scaffolds",
					"Initialising...", 0, 2 * nContigs);
		}

		public void scaffoldUpdate(ScaffoldEvent event) {
			Object object = event.getValue();

			int intvalue = (object instanceof Integer) ? ((Integer) object)
					.intValue() : -1;

			if (event.getMode() != ScaffoldEvent.CONTIG_SET_INFO)
				monitor.setNote(event.getDescription());

			switch (event.getMode()) {
				case ScaffoldEvent.CONTIG_SET_INFO:
					if (intvalue > 0) {
						final int value = nContigs - intvalue;
						SwingUtilities.invokeLater(new Runnable() {
							public void run() {
								monitor.setProgress(value);
							}
						});
					}
					break;

				case ScaffoldEvent.FINDING_SUBGRAPHS:
					if (intvalue > 0) {
						final int value = nContigs + intvalue;
						SwingUtilities.invokeLater(new Runnable() {
							public void run() {
								monitor.setProgress(value);
							}
						});
					}
					break;
			}
		}

		public void closeProgressMonitor() {
			if (monitor != null)
				monitor.close();
		}
	}
}
