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

package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.awt.BorderLayout;
import java.awt.Cursor;
import java.awt.Dimension;
import java.awt.Toolkit;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;

import javax.swing.*;
import javax.swing.border.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ContigTransferTablePanel extends MinervaPanel {
	private ContigTransferTable tableRequester = null;
	private ContigTransferTableModel modelRequester = null;

	private ContigTransferTable tableContigOwner = null;
	private ContigTransferTableModel modelContigOwner = null;

	private JSplitPane splitpane;

	private ContigTransferTable tableAdmin = null;
	private ContigTransferTableModel modelAdmin = null;
	
	private boolean firstRefresh = false;
	
	private static final Cursor defaultCursor = Cursor.getDefaultCursor();
	private static final Cursor busyCursor = Cursor.getPredefinedCursor(Cursor.WAIT_CURSOR);
	
	public ContigTransferTablePanel(MinervaTabbedPane mtp, ArcturusDatabase adb) throws ArcturusDatabaseException {
		this(mtp, adb, false);
	}

	protected ContigTransferTablePanel(MinervaTabbedPane mtp, ArcturusDatabase adb,
			boolean isAdmin) throws ArcturusDatabaseException {
		super(mtp, adb);
		
		Person user = adb.findMe();

		if (isAdmin) {
			modelAdmin = new ContigTransferTableModel(adb, user,
					ArcturusDatabase.USER_IS_ADMINISTRATOR);
			
			tableAdmin = new ContigTransferTable(modelAdmin);		

			JScrollPane scrollpane = new JScrollPane(tableAdmin);

			Border loweredetched1 = BorderFactory
					.createEtchedBorder(EtchedBorder.LOWERED);
			Border title1 = BorderFactory.createTitledBorder(loweredetched1,
					"All requests");
			
			scrollpane.setBorder(title1);

			add(scrollpane, BorderLayout.CENTER);
		} else {
			modelRequester = new ContigTransferTableModel(adb, user,
					ArcturusDatabase.USER_IS_REQUESTER);

			tableRequester = new ContigTransferTable(modelRequester);

			JScrollPane scrollpane1 = new JScrollPane(tableRequester);

			Border loweredetched1 = BorderFactory
					.createEtchedBorder(EtchedBorder.LOWERED);
			Border title1 = BorderFactory.createTitledBorder(loweredetched1,
					"Requests I have made, or to a project I own");
			scrollpane1.setBorder(title1);

			modelContigOwner = new ContigTransferTableModel(adb, user,
					ArcturusDatabase.USER_IS_CONTIG_OWNER);

			tableContigOwner = new ContigTransferTable(modelContigOwner);

			JScrollPane scrollpane2 = new JScrollPane(tableContigOwner);

			Border loweredetched2 = BorderFactory
					.createEtchedBorder(EtchedBorder.LOWERED);
			Border title2 = BorderFactory.createTitledBorder(loweredetched2,
					"Requests for contigs I own");
			scrollpane2.setBorder(title2);

			splitpane = new JSplitPane(JSplitPane.VERTICAL_SPLIT, scrollpane1,
					scrollpane2);

			add(splitpane, BorderLayout.CENTER);

			splitpane.setDividerLocation(0.5);
		}

		createActions();

		createMenus();

		getPrintAction().setEnabled(false);
		
		addComponentListener(new ComponentAdapter() {
			public void componentShown(ComponentEvent e) {
				if (!firstRefresh) {
					try {
						Arcturus.logInfo("ContigTransferTablePanel initial refresh");
						refresh();
					} catch (ArcturusDatabaseException adbe) {
						Arcturus.logWarning("ContigTransferTablePanel initial refresh failed", adbe);
					}
					firstRefresh = true;
				}
			}
		});
	}

	protected void createActions() {
	}

	public void closeResources() {
		// Does nothing
	}

	public void refresh() throws ArcturusDatabaseException {
		refreshTablesInBackground();
	}
	
	public void refreshTablesInBackground() {
		ContigTransferTablePanelRefreshWorker worker = new ContigTransferTablePanelRefreshWorker(this);
		
		setBusyCursor(true);
		
		worker.execute();
	}
	
	void refreshAllTables() throws ArcturusDatabaseException {
		refreshTable(tableRequester);
		refreshTable(tableContigOwner);
		refreshTable(tableAdmin);
	}
	
	private void refreshTable(ContigTransferTable table) throws ArcturusDatabaseException {
		if (table != null) 
			table.refresh();
	}
	
	void setBusyCursor(boolean busy) {
		setCursor(busy ? busyCursor : defaultCursor);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
		//if (tableAdmin != null)
		//	return;
		
		menu.addSeparator();

		ButtonGroup group = new ButtonGroup();

		int[] cutoffs = { 0, 7, 14, 28, 90 };

		JRadioButtonMenuItem rb = null;

		for (int i = 0; i < cutoffs.length; i++) {
			String caption = cutoffs[i] == 0 ? "Show full history"
					: "Show requests made in last " + cutoffs[i] + " days";

			rb = new JRadioButtonMenuItem(caption);
			group.add(rb);
			menu.add(rb);

			final int n = cutoffs[i];

			rb.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					if (modelContigOwner != null)
						modelContigOwner.setDateCutoff(n);
					
					if (modelRequester != null)
						modelRequester.setDateCutoff(n);
					
					if (modelAdmin != null)
						modelAdmin.setDateCutoff(n);
				}
			});

			if (cutoffs[i] == 0)
				rb.doClick();
		}

		int[] status = { ContigTransferRequest.ACTIVE,
				ContigTransferRequest.FAILED, ContigTransferRequest.REFUSED,
				ContigTransferRequest.DONE, ContigTransferRequest.ALL };

		menu.addSeparator();

		group = new ButtonGroup();

		for (int i = 0; i < status.length; i++) {
			String caption = status[i] == ContigTransferRequest.ALL ? "Show all requests"
					: "Show requests which are "
							+ ContigTransferRequest
									.convertStatusToString(status[i]);

			rb = new JRadioButtonMenuItem(caption);
			group.add(rb);
			menu.add(rb);

			final int n = status[i];

			rb.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					if (modelContigOwner != null)
						modelContigOwner.setShowStatus(n);

					if (modelRequester != null)
						modelRequester.setShowStatus(n);

					if (modelAdmin != null)
						modelAdmin.setShowStatus(n);
				}
			});

			if (status[i] == ContigTransferRequest.ACTIVE)
				rb.doClick();
		}
	}

	protected void createClassSpecificMenus() {
	}

	protected boolean isRefreshable() {
		return true;
	}

	protected void doPrint() {
		// Do nothing.
	}

	public Dimension getPreferredSize() {
		Dimension screen = Toolkit.getDefaultToolkit().getScreenSize();

		// Some window managers don't take into account toolbars, menu bars etc.
		screen.height -= 200;
		screen.width -= 50;

		Dimension prefsize = super.getPreferredSize();

		if (prefsize.height > screen.height)
			prefsize.height = screen.height;

		if (prefsize.width > screen.width)
			prefsize.width = screen.width;

		return prefsize;
	}

	public void resetDivider() {
		splitpane.setDividerLocation(0.5);
	}
}
