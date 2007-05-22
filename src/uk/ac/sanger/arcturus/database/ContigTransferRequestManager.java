package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.contigtransfer.*;

import java.sql.*;
import java.util.*;
import java.util.zip.DataFormatException;

public class ContigTransferRequestManager {
	protected ArcturusDatabase adb;
	protected Connection conn;

	protected HashMap<Integer, ContigTransferRequest> cache = new HashMap<Integer, ContigTransferRequest>();

	protected PreparedStatement pstmtByRequester = null;
	protected PreparedStatement pstmtByContigOwner = null;
	protected PreparedStatement pstmtByID = null;

	protected PreparedStatement pstmtCountActiveRequestsByContigId = null;

	protected PreparedStatement pstmtInsertNewRequest = null;

	protected PreparedStatement pstmtUpdateRequestStatus = null;

	protected PreparedStatement pstmtMarkRequestAsFailed = null;

	protected PreparedStatement pstmtProjectIDForContig = null;

	protected PreparedStatement pstmtCheckProjectLock = null;

	protected PreparedStatement pstmtMoveContig = null;

	protected PreparedStatement pstmtMarkRequestAsDone = null;
	
	protected PreparedStatement pstmtSetClosedDate = null;

	protected boolean debugging = false;

	protected ContigTransferRequestNotifier notifier = ContigTransferRequestNotifier
			.getInstance();

	/**
	 * Creates a new ContigTransferRequestManager to provide contig transfer
	 * request management services to an ArcturusDatabase object.
	 */

	public ContigTransferRequestManager(ArcturusDatabase adb)
			throws SQLException {
		this.adb = adb;

		conn = adb.getConnection();

		prepareStatements();
	}

	protected void prepareStatements() throws SQLException {
		String columns = "request_id,contig_id,old_project_id,new_project_id,requester,"
				+ "requester_comment,opened,reviewer,reviewer_comment,reviewed,CONTIGTRANSFERREQUEST.status,closed";

		String query;

		query = "select "
				+ columns
				+ " from CONTIGTRANSFERREQUEST left join PROJECT on new_project_id=project_id"
				+ " where (requester = ? or owner = ?)";

		pstmtByRequester = conn.prepareStatement(query);

		query = "select "
				+ columns
				+ " from CONTIGTRANSFERREQUEST left join PROJECT on old_project_id=project_id"
				+ " where owner = ? and requester != owner";

		pstmtByContigOwner = conn.prepareStatement(query);

		query = "select "
				+ columns
				+ " from CONTIGTRANSFERREQUEST left join PROJECT on old_project_id=project_id"
				+ " where request_id = ?";

		pstmtByID = conn.prepareStatement(query);

		query = "select count(*) from CONTIGTRANSFERREQUEST"
				+ " where contig_id = ? and (status = 'pending' or status = 'approved')";

		pstmtCountActiveRequestsByContigId = conn.prepareStatement(query);

		query = "insert into CONTIGTRANSFERREQUEST(contig_id,old_project_id,new_project_id,requester,opened)"
				+ " values(?,?,?,?,NOW())";

		pstmtInsertNewRequest = conn.prepareStatement(query,
				Statement.RETURN_GENERATED_KEYS);

		query = "update CONTIGTRANSFERREQUEST set status=?,reviewer=?,reviewed=now() where request_id = ?";

		pstmtUpdateRequestStatus = conn.prepareStatement(query);

		query = "update CONTIGTRANSFERREQUEST set status = 'failed', closed=NOW() where request_id = ?";

		pstmtMarkRequestAsFailed = conn.prepareStatement(query);

		query = "select project_id from CONTIG where contig_id = ?";

		pstmtProjectIDForContig = conn.prepareStatement(query);

		query = "select lockdate,lockowner from PROJECT where project_id = ?";

		pstmtCheckProjectLock = conn.prepareStatement(query);

		query = "update CONTIG set project_id = ? where contig_id = ? and project_id = ?";

		pstmtMoveContig = conn.prepareStatement(query);

		query = "update CONTIGTRANSFERREQUEST set status = 'done', closed=NOW() where request_id = ?";

		pstmtMarkRequestAsDone = conn.prepareStatement(query);
		
		query = "update CONTIGTRANSFERREQUEST set closed=NOW() where request_id = ?";
		
		pstmtSetClosedDate = conn.prepareStatement(query);
	}

	public ContigTransferRequest[] getContigTransferRequestsByUser(Person user,
			int mode) throws SQLException {
		PreparedStatement pstmt;

		if (mode == ArcturusDatabase.USER_IS_REQUESTER) {
			pstmt = pstmtByRequester;
			pstmt.setString(1, user.getUID());
			pstmt.setString(2, user.getUID());
		} else {
			pstmt = pstmtByContigOwner;
			pstmt.setString(1, user.getUID());
		}

		ResultSet rs = pstmt.executeQuery();

		ContigTransferRequest[] transfers = getTransfersFromResultSet(rs);

		rs.close();

		return transfers;
	}

	protected ContigTransferRequest[] getTransfersFromResultSet(ResultSet rs)
			throws SQLException {
		Vector<ContigTransferRequest> v = new Vector<ContigTransferRequest>();

		Contig contig = null;

		while (rs.next()) {
			int requestId = rs.getInt(1);

			int contigId = rs.getInt(2);
			try {
				contig = adb.getContigByID(contigId,
						ArcturusDatabase.CONTIG_BASIC_DATA);
			} catch (DataFormatException dfe) {
				Arcturus.logWarning("Failed to get contig " + contigId, dfe);
				contig = null;
			}

			int oldProjectId = rs.getInt(3);
			Project oldProject = adb.getProjectByID(oldProjectId);

			int newProjectId = rs.getInt(4);
			Project newProject = adb.getProjectByID(newProjectId);

			String requesterUid = rs.getString(5);
			Person requester = PeopleManager.findPerson(requesterUid);

			String requesterComment = rs.getString(6);

			ContigTransferRequest request = cache.get(requestId);

			if (request == null) {
				request = new ContigTransferRequest(requestId, contig,
						oldProject, newProject, requester, requesterComment);

				if (contig == null)
					request.setContigID(contigId);

				cache.put(requestId, request);
			}

			request.setOpenedDate(rs.getTimestamp(7));

			String reviewerUid = rs.getString(8);
			Person reviewer = reviewerUid != null ? PeopleManager
					.findPerson(reviewerUid) : null;

			request.setReviewer(reviewer);

			request.setReviewerComment(rs.getString(9));

			request.setReviewedDate(rs.getTimestamp(10));

			request.setStatusAsString(rs.getString(11));

			request.setClosedDate(rs.getTimestamp(12));

			v.add(request);
		}

		ContigTransferRequest[] array = v.toArray(new ContigTransferRequest[0]);
		return array;
	}

	public ContigTransferRequest findContigTransferRequest(int requestId)
			throws ContigTransferRequestException, SQLException {
		pstmtByID.setInt(1, requestId);

		ResultSet rs = pstmtByID.executeQuery();

		ContigTransferRequest[] transfers = getTransfersFromResultSet(rs);

		rs.close();

		return (transfers == null || transfers.length == 0) ? null
				: transfers[0];
	}

	public ContigTransferRequest createContigTransferRequest(Person requester,
			int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException {
		/*
		 * Ensure that the requester is a real person.
		 */

		if (requester == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.USER_IS_NULL);

		/*
		 * Check that the transfer makes sense.
		 * 
		 * 1. Is the contig current? 2. Is it already the subject of a current
		 * transfer request? 3. Is the contig's current project valid? 4. Is the
		 * destination project valid? 5. Is the contig already in the
		 * destination project?
		 */

		checkIsCurrentContig(contigId);

		checkForExistingRequests(contigId);

		Contig contig = null;

		try {
			contig = adb.getContigByID(contigId,
					ArcturusDatabase.CONTIG_BASIC_DATA);
		} catch (DataFormatException e) {
			// This will never happen in the CONTIG_BASIC_DATA mode.
		}

		if (contig == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.NO_SUCH_CONTIG);

		Project fromProject = contig.getProject();

		if (fromProject == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.NO_SUCH_PROJECT,
					"The contig does not belong to a valid project");

		Project toProject = adb.getProjectByID(toProjectId);

		if (toProject == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.NO_SUCH_PROJECT,
					"No such project with ID=" + toProjectId);

		if (fromProject.equals(toProject))
			throw new ContigTransferRequestException(
					ContigTransferRequestException.CONTIG_ALREADY_IN_DESTINATION_PROJECT);

		/*
		 * Check that the requester is authorised to create a request.
		 */

		checkCanUserTransferBetweenProjects(requester, fromProject, toProject);

		/*
		 * Create the request.
		 */

		return realCreateContigTransferRequest(requester, contig, toProject);
	}

	protected ContigTransferRequest realCreateContigTransferRequest(
			Person requester, Contig contig, Project toProject)
			throws ContigTransferRequestException, SQLException {
		pstmtInsertNewRequest.setInt(1, contig.getID());
		pstmtInsertNewRequest.setInt(2, contig.getProject().getID());
		pstmtInsertNewRequest.setInt(3, toProject.getID());
		pstmtInsertNewRequest.setString(4, requester.getUID());

		int rc = pstmtInsertNewRequest.executeUpdate();

		if (rc == 1) {
			ResultSet rs = pstmtInsertNewRequest.getGeneratedKeys();

			int requestId = rs.next() ? rs.getInt(1) : -1;

			rs.close();

			ContigTransferRequest request = findContigTransferRequest(requestId);

			notifier.notifyRequestStatusChange(requester, request,
					ContigTransferRequest.UNKNOWN);

			return request;
		} else
			throw new ContigTransferRequestException(
					ContigTransferRequestException.SQL_INSERT_FAILED);
	}

	protected void checkForExistingRequests(int contigId)
			throws ContigTransferRequestException, SQLException {
		int requestId = countActiveRequestsForContig(contigId);

		if (requestId > 0)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.CONTIG_ALREADY_REQUESTED);
	}

	protected int countActiveRequestsForContig(int contigId)
			throws SQLException {
		pstmtCountActiveRequestsByContigId.setInt(1, contigId);

		ResultSet rs = pstmtCountActiveRequestsByContigId.executeQuery();

		int count = rs.next() ? rs.getInt(1) : 0;

		rs.close();

		return count;
	}

	protected void checkIsCurrentContig(int contigId)
			throws ContigTransferRequestException, SQLException {
		if (!adb.isCurrentContig(contigId))
			throw new ContigTransferRequestException(
					ContigTransferRequestException.CONTIG_NOT_CURRENT);
	}

	protected void checkCanUserTransferBetweenProjects(Person requester,
			Project fromProject, Project toProject)
			throws ContigTransferRequestException, SQLException {
		/*
		 * Is the requester transferring a contig from her project to the bin?
		 */

		if (requester.equals(fromProject.getOwner()) && toProject.isBin())
			return;

		/*
		 * Is the requester the owner of the destination project?
		 */

		if (requester.equals(toProject.getOwner()))
			return;

		/*
		 * Does the requester have the "mover_any_contig" privilege?
		 */

		if (adb.hasPrivilege(requester, "move_any_contig"))
			return;

		/*
		 * Does the requester have the "team leader", "administrator" or
		 * "superuser" role?
		 */

		if (hasFullPrivileges(requester))
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.USER_NOT_AUTHORISED);
	}

	protected boolean hasFullPrivileges(Person person) {
		if (person == null)
			return false;

		String role = null;
		
		try {
			role = adb.getRoleForUser(person);
		} catch (SQLException e) {
			Arcturus.logWarning("Failed to get role for user " + person.getUID(), e);
			return false;
		}

		if (role == null)
			return false;

		return role.equalsIgnoreCase("team leader")
				|| role.equalsIgnoreCase("administrator")
				|| role.equalsIgnoreCase("superuser");
	}

	public ContigTransferRequest createContigTransferRequest(int contigId,
			int toProjectId) throws ContigTransferRequestException,
			SQLException {
		return createContigTransferRequest(PeopleManager.findMe(), contigId,
				toProjectId);
	}

	public ContigTransferRequest createContigTransferRequest(Person requester,
			Contig contig, Project project)
			throws ContigTransferRequestException, SQLException {
		return createContigTransferRequest(requester, contig.getID(), project
				.getID());
	}

	public ContigTransferRequest createContigTransferRequest(Contig contig,
			Project project) throws ContigTransferRequestException,
			SQLException {
		return createContigTransferRequest(PeopleManager.findMe(), contig
				.getID(), project.getID());
	}

	public boolean canCancelRequest(ContigTransferRequest request, Person person) {
		if (request == null || person == null)
			return false;
		
		int status = request.getStatus();

		if (status == ContigTransferRequest.REFUSED
				|| status == ContigTransferRequest.FAILED
				|| status == ContigTransferRequest.DONE)
			return false;

		return request.getRequester().equals(person) || hasFullPrivileges(person);
	}
	
	public boolean canRefuseRequest(ContigTransferRequest request, Person person) {
		if (request == null || person == null)
			return false;
		
		if (request.getStatus() != ContigTransferRequest.PENDING)
			return false;
		
		Person requester = request.getRequester();
		
		Person srcOwner = request.getOldProject().getOwner();
		Person dstOwner = request.getNewProject().getOwner();
		
		if (person.equals(srcOwner) && !requester.equals(srcOwner))
			return true;
		
		if (person.equals(dstOwner) && !requester.equals(dstOwner))
			return true;
		
		return hasFullPrivileges(person);
	}
		
	public boolean canApproveRequest(ContigTransferRequest request, Person person) {
		if (request == null || person == null)
			return false;
		
		if (request.getStatus() != ContigTransferRequest.PENDING)
			return false;
		
		Person requester = request.getRequester();
		
		Project oldProject = request.getOldProject();
		Person srcOwner = oldProject.getOwner();
		
		Project newProject = request.getNewProject();
		Person dstOwner = newProject.getOwner();
		
		if (person.equals(requester) && (newProject.isUnowned() || newProject.isBin()))
			return true;
		
		if (person.equals(srcOwner) && !requester.equals(srcOwner))
			return true;
		
		if (person.equals(dstOwner) && 
				(oldProject.isUnowned() || oldProject.isBin()))
			return true;
		
		return hasFullPrivileges(person);
	}
	
	public boolean canExecuteRequest(ContigTransferRequest request, Person person) {
		if (request == null || person == null)
			return false;
		
		if (request.getStatus() != ContigTransferRequest.APPROVED)
			return false;
		
		Person requester = request.getRequester();
		
		Person srcOwner = request.getOldProject().getOwner();
		Person dstOwner = request.getNewProject().getOwner();
	
		return person.equals(requester) || person.equals(srcOwner) || person.equals(dstOwner) ||
			hasFullPrivileges(person);
	}
	
	protected boolean markRequestAsFailed(ContigTransferRequest request)
			throws SQLException {
		pstmtMarkRequestAsFailed.setInt(1, request.getRequestID());
		if (pstmtMarkRequestAsFailed.executeUpdate() == 1) {
			request.setStatus(ContigTransferRequest.FAILED);
			return true;
		} else
			return false;
	}

	public void reviewContigTransferRequest(ContigTransferRequest request,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		/*
		 * Ensure that the requester is a real person.
		 */

		if (reviewer == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.USER_IS_NULL);

		/*
		 * Check that the contig is still current, and that it is still in the
		 * project specified when the request was created.
		 */

		try {
			Contig contig = request.getContig();
			int contig_id = contig == null ? 0 : contig.getID();
			checkIsCurrentContig(contig_id);
			checkContigProjectStillValid(request);
		} catch (ContigTransferRequestException ctre) {
			markRequestAsFailed(request);
			throw ctre;
		}

		/*
		 * Check that the proposed new status is valid.
		 */

		checkStatusChangeIsAllowed(request, newStatus);

		/*
		 * Check that the user is authorised to change the status of the
		 * request.
		 */

		checkCanUserAlterRequestStatus(request, reviewer, newStatus);

		/*
		 * Change the request status.
		 */

		changeContigRequestStatus(request, reviewer, newStatus);
	}

	protected void checkContigProjectStillValid(ContigTransferRequest request)
			throws ContigTransferRequestException, SQLException {
		pstmtProjectIDForContig.setInt(1, request.getContig().getID());

		ResultSet rs = pstmtProjectIDForContig.executeQuery();

		int currentProjectID = rs.next() ? rs.getInt(1) : -1;

		rs.close();

		Project fromProject = request.getOldProject();
		Project contigProject = request.getContig().getProject();

		if (fromProject != null && contigProject != null
				&& fromProject.getID() == currentProjectID)
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.CONTIG_HAS_MOVED);
	}

	protected void checkCanUserAlterRequestStatus(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		/*
		 * The requester is allowed to cancel her own request.
		 */

		if (newStatus == ContigTransferRequest.CANCELLED
				&& reviewer.equals(request.getRequester()))
			return;

		/*
		 * The owner of the contig can refuse or approve a request.
		 */

		if ((newStatus == ContigTransferRequest.REFUSED || newStatus == ContigTransferRequest.APPROVED)
				&& reviewer.equals(request.getContigOwner()))
			return;

		/*
		 * The owner of the destination project can refuse or approve a transfer
		 * from a bin project or an unowned project made by another user.
		 */

		if ((newStatus == ContigTransferRequest.REFUSED || newStatus == ContigTransferRequest.APPROVED)
				&& !reviewer.equals(request.getRequester())
				&& reviewer.equals(request.getNewProject().getOwner())
				&& (request.getOldProject().isBin() || request.getOldProject()
						.isUnowned()))
			return;

		/*
		 * The requester is allowed to approve a transfer from a bin project or
		 * an unowned project.
		 */

		if (newStatus == ContigTransferRequest.APPROVED
				&& reviewer.equals(request.getRequester())
				&& (request.getOldProject().isBin() || request.getOldProject()
						.isUnowned()))
			return;

		/*
		 * The request can be executed by the owner of the contig, the requester
		 * or the owner of the destination project.
		 */

		if ((newStatus == ContigTransferRequest.DONE)
				&& (reviewer.equals(request.getContigOwner())
						|| reviewer.equals(request.getRequester()) || reviewer
						.equals(request.getNewProject().getOwner())))
			return;

		/*
		 * A reviewer who has the "team leader", "administrator" or "superuser"
		 * role can make any change at all.
		 */

		if (hasFullPrivileges(reviewer))
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.USER_NOT_AUTHORISED);
	}

	protected void checkStatusChangeIsAllowed(ContigTransferRequest request,
			int newStatus) throws ContigTransferRequestException {
		int oldStatus = request.getStatus();

		/*
		 * A PENDING request can change to APPROVED or REFUSED or CANCELLED.
		 */

		if (oldStatus == ContigTransferRequest.PENDING
				&& (newStatus == ContigTransferRequest.APPROVED
						|| newStatus == ContigTransferRequest.CANCELLED || newStatus == ContigTransferRequest.REFUSED))
			return;

		/*
		 * An APPROVED request can change to DONE or CANCELLED.
		 */

		if (oldStatus == ContigTransferRequest.APPROVED
				&& (newStatus == ContigTransferRequest.DONE || newStatus == ContigTransferRequest.CANCELLED))
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.INVALID_STATUS_CHANGE);
	}

	protected void changeContigRequestStatus(ContigTransferRequest request,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		int oldStatus = request.getStatus();

		String newStatusString = ContigTransferRequest
				.convertStatusToString(newStatus);
		pstmtUpdateRequestStatus.setString(1, newStatusString);
		pstmtUpdateRequestStatus.setString(2, reviewer.getUID());
		pstmtUpdateRequestStatus.setInt(3, request.getRequestID());

		int rc = pstmtUpdateRequestStatus.executeUpdate();

		if (rc != 1)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.SQL_UPDATE_FAILED);

		request.setStatus(newStatus);
		request.setReviewer(reviewer);
		
		if (newStatus == ContigTransferRequest.REFUSED || newStatus == ContigTransferRequest.CANCELLED) {
			pstmtSetClosedDate.setInt(1, request.getRequestID());
			pstmtSetClosedDate.executeUpdate();
		}
		
		notifier.notifyRequestStatusChange(reviewer, request, oldStatus);
	}

	public void reviewContigTransferRequest(int requestId, Person reviewer,
			int newStatus) throws ContigTransferRequestException, SQLException {
		ContigTransferRequest request = findContigTransferRequest(requestId);
		reviewContigTransferRequest(request, reviewer, newStatus);
	}

	public void reviewContigTransferRequest(int requestId, int newStatus)
			throws ContigTransferRequestException, SQLException {
		reviewContigTransferRequest(requestId, PeopleManager.findMe(),
				newStatus);
	}

	public void executeContigTransferRequest(ContigTransferRequest request,
			Person reviewer) throws ContigTransferRequestException,
			SQLException {
		int oldStatus = request.getStatus();

		if (reviewer == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.USER_IS_NULL);

		checkStatusChangeIsAllowed(request, ContigTransferRequest.DONE);

		try {
			Contig contig = request.getContig();
			int contig_id = contig == null ? 0 : contig.getID();
			checkIsCurrentContig(contig_id);
			checkContigProjectStillValid(request);
		} catch (ContigTransferRequestException ctre) {
			markRequestAsFailed(request);
			throw ctre;
		}

		checkCanUserAlterRequestStatus(request, reviewer,
				ContigTransferRequest.DONE);

		checkProjectsAreUnlocked(request);

		executeRequest(request);

		notifier.notifyRequestStatusChange(reviewer, request, oldStatus);
	}

	protected void executeRequest(ContigTransferRequest request)
			throws ContigTransferRequestException, SQLException {
		Contig contig = request.getContig();

		pstmtMoveContig.setInt(1, request.getNewProject().getID());
		pstmtMoveContig.setInt(2, contig.getID());
		pstmtMoveContig.setInt(3, request.getOldProject().getID());

		int rc = pstmtMoveContig.executeUpdate();

		if (rc == 1) {
			pstmtMarkRequestAsDone.setInt(1, request.getRequestID());

			rc = pstmtMarkRequestAsDone.executeUpdate();

			if (rc == 1) {
				request.setStatus(ContigTransferRequest.DONE);
				contig.setProject(request.getNewProject());
				return;
			}
		}

		throw new ContigTransferRequestException(
				ContigTransferRequestException.SQL_UPDATE_FAILED);
	}

	protected void checkProjectsAreUnlocked(ContigTransferRequest request)
			throws ContigTransferRequestException, SQLException {
		checkProjectIsUnlocked(request.getOldProject());
		checkProjectIsUnlocked(request.getNewProject());
	}

	protected void checkProjectIsUnlocked(Project project)
			throws ContigTransferRequestException, SQLException {
		pstmtCheckProjectLock.setInt(1, project.getID());

		ResultSet rs = pstmtCheckProjectLock.executeQuery();

		rs.next();

		rs.getTimestamp(1);
		boolean lockdateNull = rs.wasNull();

		rs.getString(2);
		boolean lockownerNull = rs.wasNull();

		rs.close();

		if (lockdateNull && lockownerNull)
			return;
		else
			throw new ContigTransferRequestException(
					ContigTransferRequestException.PROJECT_IS_LOCKED);
	}

	public void executeContigTransferRequest(int requestId, Person reviewer)
			throws ContigTransferRequestException, SQLException {
		ContigTransferRequest request = findContigTransferRequest(requestId);
		executeContigTransferRequest(request, reviewer);
	}

	public void executeContigTransferRequest(int requestId)
			throws ContigTransferRequestException, SQLException {
		executeContigTransferRequest(requestId, PeopleManager.findMe());
	}

	public static String prettyPrint(ContigTransferRequest request) {
		StringBuffer sb = new StringBuffer(80);

		Person contigOwner = request.getContigOwner();
		String ownerName = contigOwner == null ? "nobody" : contigOwner
				.getName();

		Contig contig = request.getContig();

		sb.append("ContigTransferRequest (" + request.hashCode() + ")\n");
		sb.append("\tID = " + request.getRequestID() + "\n");
		sb.append("\tContig = " + ((contig == null) ? 0 : contig.getID())
				+ ", owner " + ownerName + ", in project "
				+ ((contig == null) ? "null" : contig.getProject().getName())
				+ "\n");

		sb.append("\tRequester = " + request.getRequester().getName() + "\n");

		sb.append("\tOpened on " + request.getOpenedDate() + "\n");

		String reqcomment = request.getRequesterComment();
		if (reqcomment != null)
			sb.append("\tRequester comment = " + reqcomment + "\n");

		Project fromProject = request.getOldProject();
		Project toProject = request.getNewProject();

		sb.append("\t" + fromProject.getName() + " --> " + toProject.getName()
				+ "\n");

		sb.append("\tStatus = " + request.getStatusString() + "\n");

		Person reviewer = request.getReviewer();

		if (reviewer != null) {
			sb.append("\n\tReviewer = " + reviewer.getName() + "\n");

			java.util.Date revdate = request.getReviewedDate();
			if (revdate != null)
				sb.append("\tReviewed on " + revdate + "\n");

			String revcomment = request.getReviewerComment();
			if (revcomment != null)
				sb.append("\tReviewer comment = " + revcomment + "\n");
		}

		java.util.Date closed = request.getClosedDate();
		if (closed != null)
			sb.append("\n\tClosed on " + closed + "\n");

		return sb.toString();
	}

	public void setDebugging(boolean debugging) {
		this.debugging = debugging;
	}
}
