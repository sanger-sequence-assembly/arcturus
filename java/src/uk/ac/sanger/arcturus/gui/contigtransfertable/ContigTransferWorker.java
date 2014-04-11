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

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import javax.swing.ProgressMonitor;

import javax.swing.SwingWorker;

import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestNotifier;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.gui.contigtable.ContigTablePanel;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;

public class ContigTransferWorker extends SwingWorker<Void, Integer> {
	protected ContigTransferTable parent;
	protected ArcturusDatabase adb;
	protected ContigTransferRequest[] requests;
	protected int newStatus;
	protected ProgressMonitor monitor;

	protected Person me;
	protected Set<ContigTransferRequestException> failures = new HashSet<ContigTransferRequestException>();
	protected Set<Project> changedProjects = new HashSet<Project>();

	public ContigTransferWorker(ContigTransferTable parent,
			ArcturusDatabase adb, ContigTransferRequest[] requests,
			int newStatus, ProgressMonitor monitor) throws ArcturusDatabaseException {
		this.parent = parent;
		this.adb = adb;
		this.requests = requests;
		this.newStatus = newStatus;
		this.monitor = monitor;
		
		me = adb.findMe();
	}

	protected Void doInBackground() throws Exception {
		for (int i = 0; i < requests.length; i++) {
			ContigTransferRequest request = requests[i];

			try {
				if (newStatus == ContigTransferRequest.DONE) {
					adb.executeContigTransferRequest(request, me, false);

					changedProjects.add(request.getOldProject());
					changedProjects.add(request.getNewProject());
				} else
					adb.reviewContigTransferRequest(request, me, newStatus);

				publish(i);
			} catch (ContigTransferRequestException e) {
				failures.add(e);
			}
		}

		int i = requests.length - 1;

		if (monitor != null) {
			monitor.setNote("Notifying users by email");
			publish(i);
		}

		ContigTransferRequestNotifier.getInstance().processAllQueues();

		if (newStatus == ContigTransferRequest.DONE) {
			if (monitor != null) {
				monitor.setNote("Refreshing all views");
				publish(i);
			}

			ProjectChangeEvent event = new ProjectChangeEvent(this, null,
					ProjectChangeEvent.CONTIGS_CHANGED);

			boolean first = true;

			for (Project project : changedProjects) {
				event.setProject(project);
				// Notify all listeners on the first project, but only the
				// ContigTablePanel
				// objects for all other projects. This avoids updating the
				// project table
				// view repeatedly.
				adb.notifyProjectChangeEventListeners(event, first ? null
						: ContigTablePanel.class);
				first = false;
			}
		}

		parent.refresh();

		if (!failures.isEmpty()) {
			if (monitor != null) {
				monitor.setNote("Preparing failure report");
				publish(i);
			}

			parent.notifyMultipleFailures(failures, newStatus);
		}

		return null;
	}

	protected void process(List<Integer> chunks) {
		int i = chunks.get(chunks.size() - 1);

		if (monitor != null)
			monitor.setProgress(i);
	}

	protected void done() {
		if (monitor != null)
			monitor.close();
	}
}
