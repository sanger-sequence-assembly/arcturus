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

package uk.ac.sanger.arcturus.gui.checkconsistency;

import uk.ac.sanger.arcturus.gui.*;
import uk.ac.sanger.arcturus.consistencychecker.CheckConsistency;
import uk.ac.sanger.arcturus.consistencychecker.CheckConsistencyEvent;
import uk.ac.sanger.arcturus.consistencychecker.CheckConsistencyListener;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.Arcturus;

import javax.swing.*;

import java.util.List;

import java.awt.*;
import java.awt.event.*;
import java.io.InputStream;

public class CheckConsistencyPanel extends MinervaPanel {
	protected CheckConsistency checker;
	protected JTextArea textarea = new JTextArea();
	protected JButton btnRefresh;
	protected JButton btnClear;
	protected JButton btnCancel;
	
	protected Worker worker;

	public CheckConsistencyPanel(MinervaTabbedPane parent, ArcturusDatabase adb) {
		super(parent, adb);
		
		try {
			InputStream is = getClass().getResourceAsStream("/resources/xml/checkconsistency.xml");
			checker = new CheckConsistency(is);
			is.close();
		}
		catch (Exception e) {
			Arcturus.logSevere("An error occurred when trying to initialise the consistency checker", e);
		}
		
		createMenus();

		btnRefresh = new JButton(actionRefresh);
		btnClear = new JButton("Clear all messages");
		btnCancel = new JButton("Cancel");

		JScrollPane scrollpane = new JScrollPane(textarea);

		add(scrollpane, BorderLayout.CENTER);

		JPanel buttonpanel = new JPanel(new FlowLayout());

		buttonpanel.add(btnRefresh);
		buttonpanel.add(btnClear);
		buttonpanel.add(btnCancel);
		
		btnCancel.setEnabled(false);

		add(buttonpanel, BorderLayout.SOUTH);

		btnClear.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				textarea.setText("");
			}
		});

		btnCancel.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				cancelTask();
			}
		});

		getPrintAction().setEnabled(false);
	}

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	public void closeResources() {
	}

	protected void createActions() {
	}

	protected void createClassSpecificMenus() {
	}

	protected void doPrint() {
	}

	protected boolean isRefreshable() {
		return true;
	}

	private void cancelTask() {
		System.err.println("Cancel button pressed");
		worker.cancel(true);
	}

	public void refresh() {
		actionRefresh.setEnabled(false);
		worker = new Worker();
		worker.execute();
		btnCancel.setEnabled(true);
	}

	class Worker extends SwingWorker<Void, String> implements
			CheckConsistencyListener {
		protected Void doInBackground() throws Exception {
			try {
				checker.checkConsistency(adb, this, true);
			}
			catch (ArcturusDatabaseException e) {
				Arcturus.logWarning("An error occurred whilst checking the database", e);
			}
			return null;
		}

		protected void done() {
			if (isCancelled())
				checker.cancel();
			
			actionRefresh.setEnabled(true);
			btnCancel.setEnabled(false);
		}

		protected void process(List<String> messages) {
			for (String message : messages) {
				textarea.append(message);
				textarea.append("\n");
			}
		}

		public void report(CheckConsistencyEvent event ) {
			publish(event.getMessage());
		}
		
		public void sendEmail() {
		}
	}
}
