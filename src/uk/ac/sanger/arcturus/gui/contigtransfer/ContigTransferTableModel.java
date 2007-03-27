package uk.ac.sanger.arcturus.gui.contigtransfer;

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
	public static final int COLUMN_REQUESTER_COMMENT = 6;
	public static final int COLUMN_REVIEWER = 7;
	public static final int COLUMN_REVIEWED_DATE = 8;
	public static final int COLUMN_REVIEWER_COMMENT = 9;
	public static final int COLUMN_STATUS = 10;
	public static final int COLUMN_CLOSED_DATE = 11;

	protected ContigTransferRequest[] requests;
	protected RequestComparator comparator;
	protected int lastSortColumn = COLUMN_OPENED_DATE;
	protected ArcturusDatabase adb = null;

	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected Person user;
	protected int mode;

	public ContigTransferTableModel(ArcturusDatabase adb, Person user, int mode) {
		this.adb = adb;
		this.user = user;
		this.mode = mode;

		comparator = new RequestComparator(COLUMN_OPENED_DATE, mode, false);

		refresh();
	}

	public void refresh() {
		try {
			requests = adb.getContigTransferRequestsByUser(user, mode);
		} catch (SQLException sqle) {
			Arcturus.logWarning(sqle);
		}

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
				return (mode == ArcturusDatabase.USER_IS_REQUESTER) ? "Owner" : "Requester";

			case COLUMN_OPENED_DATE:
				return "Opened";

			case COLUMN_REQUESTER_COMMENT:
				return "Requester comment";

			case COLUMN_REVIEWER:
				return "Reviewer";

			case COLUMN_REVIEWED_DATE:
				return "Reviewed";

			case COLUMN_REVIEWER_COMMENT:
				return "Reviewer comment";

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
			case COLUMN_REQUESTER_COMMENT:
			case COLUMN_REVIEWER:
			case COLUMN_REVIEWER_COMMENT:
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
		return 12;
	}

	public Object getValueAt(int row, int col) {
		ContigTransferRequest request = requests[row];

		switch (col) {
			case COLUMN_REQUEST_ID:
				return new Integer(request.getRequestID());

			case COLUMN_CONTIG_ID:
				return new Integer(request.getContig().getID());

			case COLUMN_OLD_PROJECT:
				return request.getOldProject().getName();

			case COLUMN_NEW_PROJECT:
				return request.getNewProject().getName();

			case COLUMN_REQUESTER:
				return (mode == ArcturusDatabase.USER_IS_REQUESTER) ?
						getContigOwnerName(request) : getRequesterName(request);

			case COLUMN_OPENED_DATE:
				return request.getOpenedDate();

			case COLUMN_REVIEWER:
				Person reviewer = request.getReviewer();
				return reviewer != null ? reviewer.getName() : null;

			case COLUMN_REVIEWED_DATE:
				return request.getReviewedDate();

			case COLUMN_REVIEWER_COMMENT:
				return request.getReviewerComment();

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
}
