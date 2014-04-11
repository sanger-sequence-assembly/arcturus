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

import javax.swing.table.*;
import java.awt.*;
import java.util.*;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;

import uk.ac.sanger.arcturus.people.Person;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import uk.ac.sanger.arcturus.contigtransfer.*;

import uk.ac.sanger.arcturus.gui.SortableTableModel;

public class ContigTransferTableModel extends AbstractTableModel implements
		SortableTableModel {
	public static final int COLUMN_REQUEST_ID = 0;
	public static final int COLUMN_CONTIG_ID = 1;
	public static final int COLUMN_OLD_PROJECT = 2;
	public static final int COLUMN_NEW_PROJECT = 3;
	public static final int COLUMN_REQUESTER = 4;
	public static final int COLUMN_OPENED_DATE = 5;
	public static final int COLUMN_REVIEWER = 6;
	public static final int COLUMN_REVIEWED_DATE = 7;
	public static final int COLUMN_STATUS = 8;
	public static final int COLUMN_CLOSED_DATE = 9;

	protected ContigTransferRequest[] requests;
	protected ContigTransferRequest[] allRequests;
	protected RequestComparator comparator;
	protected int lastSortColumn = COLUMN_OPENED_DATE;
	protected ArcturusDatabase adb = null;

	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected Person user;
	protected int mode;

	protected int dateCutoff = 0;
	protected int showStatus = ContigTransferRequest.ALL;

	public ContigTransferTableModel(ArcturusDatabase adb, Person user, int mode) {
		this.adb = adb;
		this.user = user;
		this.mode = mode;

		comparator = new RequestComparator(COLUMN_OPENED_DATE, false);

		refresh();
	}

	public void refresh() {
		try {
			allRequests = adb.getContigTransferRequestsByUser(user, mode);
		} catch (SQLException sqle) {
			Arcturus.logWarning(sqle);
		}

		applyFilters();
		resort();
	}

	public String getColumnName(int col) {
		switch (col) {
			case COLUMN_REQUEST_ID:
				return "Request";

			case COLUMN_CONTIG_ID:
				return "Contig";

			case COLUMN_OLD_PROJECT:
				return "Move from";

			case COLUMN_NEW_PROJECT:
				return "Move to";

			case COLUMN_REQUESTER:
				return "Requester";

			case COLUMN_OPENED_DATE:
				return "Opened";

			case COLUMN_REVIEWER:
				return "Reviewer";

			case COLUMN_REVIEWED_DATE:
				return "Reviewed";

			case COLUMN_STATUS:
				return "Status";

			case COLUMN_CLOSED_DATE:
				return "Closed";

			default:
				return "UNKNOWN";
		}
	}

	public Class getColumnClass(int col) {
		switch (col) {
			case COLUMN_OLD_PROJECT:
			case COLUMN_NEW_PROJECT:
			case COLUMN_REQUESTER:
			case COLUMN_REVIEWER:
			case COLUMN_STATUS:
				return String.class;

			case COLUMN_REQUEST_ID:
			case COLUMN_CONTIG_ID:
				return Integer.class;

			case COLUMN_OPENED_DATE:
			case COLUMN_REVIEWED_DATE:
			case COLUMN_CLOSED_DATE:
				return java.util.Date.class;

			default:
				return null;
		}
	}

	public int getRowCount() {
		return requests.length;
	}

	public int getColumnCount() {
		return 10;
	}

	public Object getValueAt(int row, int col) {
		ContigTransferRequest request = requests[row];

		switch (col) {
			case COLUMN_REQUEST_ID:
				return new Integer(request.getRequestID());

			case COLUMN_CONTIG_ID:
				return new Integer(request.getContigID());

			case COLUMN_OLD_PROJECT:
				return request.getOldProject().getNameAndOwner();

			case COLUMN_NEW_PROJECT:
				return request.getNewProject().getNameAndOwner();

			case COLUMN_REQUESTER:
				return getRequesterName(request);

			case COLUMN_OPENED_DATE:
				return request.getOpenedDate();

			case COLUMN_REVIEWER:
				Person reviewer = request.getReviewer();
				return reviewer != null ? reviewer.getName() : null;

			case COLUMN_REVIEWED_DATE:
				return request.getReviewedDate();

			case COLUMN_STATUS:
				return request.getStatusString();

			case COLUMN_CLOSED_DATE:
				return request.getClosedDate();

			default:
				return null;
		}
	}

	private String getContigOwnerName(ContigTransferRequest request) {
		if (request == null)
			return null;

		Project project = request.getOldProject();

		if (project == null)
			return null;

		Person owner = project.getOwner();

		return (owner == null) ? null : owner.getName();
	}

	private String getRequesterName(ContigTransferRequest request) {
		if (request == null)
			return null;

		Person requester = request.getRequester();

		return (requester == null) ? null : requester.getName();
	}

	public ContigTransferRequest getRequestForRow(int row) {
		return requests[row];
	}

	public Contig getContigForRow(int row) {
		return requests[row].getContig();
	}

	public boolean isCellEditable(int row, int col) {
		return false;
	}

	public boolean isColumnSortable(int column) {
		switch (column) {
			case COLUMN_REQUEST_ID:
			case COLUMN_CONTIG_ID:
			case COLUMN_OLD_PROJECT:
			case COLUMN_NEW_PROJECT:
			case COLUMN_REQUESTER:
			case COLUMN_OPENED_DATE:
			case COLUMN_REVIEWER:
			case COLUMN_REVIEWED_DATE:
			case COLUMN_STATUS:
			case COLUMN_CLOSED_DATE:
				return true;

			default:
				return false;
		}
	}

	public void sortOnColumn(int col, boolean ascending) {
		comparator.setAscending(ascending);
		sortOnColumn(col);
	}

	public void sortOnColumn(int col) {
		comparator.setType(col);

		lastSortColumn = col;

		Arrays.sort(requests, comparator);

		fireTableDataChanged();
	}

	private void resort() {
		sortOnColumn(lastSortColumn);
	}

	public void setDateCutoff(int n) {
		dateCutoff = n;
		applyFilters();
		resort();
	}

	public void setShowStatus(int n) {
		showStatus = n;
		applyFilters();
		resort();
	}

	protected void applyFilters() {
		Vector<ContigTransferRequest> filtered = new Vector<ContigTransferRequest>();

		java.util.Date now = new Date();

		java.util.Date then = dateCutoff == 0 ? null : new Date(now.getTime()
				- 86400000 * (long) dateCutoff);

		for (int i = 0; i < allRequests.length; i++)
			if (include(allRequests[i], then))
				filtered.add(allRequests[i]);

		requests = filtered.toArray(new ContigTransferRequest[0]);
	}

	protected boolean include(ContigTransferRequest request, java.util.Date then) {
		if (showStatus == ContigTransferRequest.ACTIVE && !request.isActive())
			return false;

		if (showStatus != ContigTransferRequest.ALL
				&& showStatus != ContigTransferRequest.ACTIVE
				&& showStatus != request.getStatus())
			return false;

		if (then != null && request.getOpenedDate().before(then))
			return false;

		return true;
	}

	public ArcturusDatabase getArcturusDatabase() {
		return adb;
	}
}
