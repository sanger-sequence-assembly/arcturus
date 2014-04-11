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

package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.contigtransfer.*;

import java.sql.*;
import java.util.*;

public class ContigTransferRequestManager extends AbstractManager {
	protected HashMap<Integer, ContigTransferRequest> cache = new HashMap<Integer, ContigTransferRequest>();

	protected PreparedStatement pstmtByRequester = null;
	protected PreparedStatement pstmtByContigOwner = null;
	protected PreparedStatement pstmtAllRequests = null;

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
	
	protected PreparedStatement pstmtContigsByProjectID = null;

	protected ContigTransferRequestNotifier notifier = ContigTransferRequestNotifier
			.getInstance();

	/**
	 * Creates a new ContigTransferRequestManager to provide contig transfer
	 * request management services to an ArcturusDatabase object.
	 */

	public ContigTransferRequestManager(ArcturusDatabase adb)
			throws ArcturusDatabaseException {
		super(adb);

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the contig transfer request manager", conn, adb);
		}
	}

	protected void prepareConnection() throws SQLException {
		String columns = "request_id,contig_id,old_project_id,new_project_id,requester,"
				+ "requester_comment,opened,reviewer,reviewer_comment,reviewed,CTR.status,closed";

		String query;
		
		String tables = "CONTIGTRANSFERREQUEST CTR left join PROJECT P";
		
		String omitInactiveRequests = " and CTR.status not in ('cancelled')";

		query = "select "
				+ columns
				+ " from " + tables + " on new_project_id=project_id"
				+ " where (requester = ? or owner = ?)" + omitInactiveRequests;

		pstmtByRequester = conn.prepareStatement(query);

		query = "select "
				+ columns
				+ " from " + tables + " on old_project_id=project_id"
				+ " where owner = ? and requester != owner" + omitInactiveRequests;

		pstmtByContigOwner = conn.prepareStatement(query);

		query = "select " + columns + " from " + tables + " on old_project_id=project_id";

		pstmtAllRequests = conn.prepareStatement(query);

		query = "select "
				+ columns
				+ " from " + tables + " on old_project_id=project_id"
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
		
		query = "select contig_id from CURRENTCONTIGS where project_id = ?";
		
		pstmtContigsByProjectID = conn.prepareStatement(query);
	}

	public ContigTransferRequest[] getContigTransferRequestsByUser(Person user,
			int mode) throws ArcturusDatabaseException {
		PreparedStatement pstmt;
		ContigTransferRequest[] transfers = null;
		
		try {
			switch (mode) {
				default:
				case ArcturusDatabase.USER_IS_REQUESTER:
					pstmt = pstmtByRequester;
					pstmt.setString(1, user.getUID());
					pstmt.setString(2, user.getUID());
					break;

				case ArcturusDatabase.USER_IS_CONTIG_OWNER:
					pstmt = pstmtByContigOwner;
					pstmt.setString(1, user.getUID());
					break;

				case ArcturusDatabase.USER_IS_ADMINISTRATOR:
					pstmt = pstmtAllRequests;
					break;
			}

			ResultSet rs = pstmt.executeQuery();

			transfers = getTransfersFromResultSet(rs);

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to fetch contig transfer requests for user " + user.getName(),
					conn, this);
		}

		return transfers;
	}

	protected ContigTransferRequest[] getTransfersFromResultSet(ResultSet rs)
			throws ArcturusDatabaseException {
		Vector<ContigTransferRequest> v = new Vector<ContigTransferRequest>();

		Contig contig = null;

		try {
			while (rs.next()) {
				int requestId = rs.getInt(1);

				int contigId = rs.getInt(2);
					
				contig = adb.getContigByID(contigId, ArcturusDatabase.CONTIG_BASIC_DATA);

				int oldProjectId = rs.getInt(3);
				Project oldProject = adb.getProjectByID(oldProjectId);

				int newProjectId = rs.getInt(4);
				Project newProject = adb.getProjectByID(newProjectId);

				String requesterUid = rs.getString(5);
				Person requester = adb.findUser(requesterUid);

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
				Person reviewer = reviewerUid != null ? adb
						.findUser(reviewerUid) : null;

				request.setReviewer(reviewer);

				request.setReviewerComment(rs.getString(9));

				request.setReviewedDate(rs.getTimestamp(10));

				request.setStatusAsString(rs.getString(11));

				request.setClosedDate(rs.getTimestamp(12));

				v.add(request);
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to fetch contig transfer requests", conn, this);
		}

		ContigTransferRequest[] array = v.toArray(new ContigTransferRequest[0]);
		return array;
	}

	public ContigTransferRequest findContigTransferRequest(int requestId)
			throws ArcturusDatabaseException {
		ContigTransferRequest[] transfers = null;
		
		try {
			pstmtByID.setInt(1, requestId);

			ResultSet rs = pstmtByID.executeQuery();

			transfers = getTransfersFromResultSet(rs);

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to fetch contig transfer request ID=" + requestId, conn, this);
		}

		return (transfers == null || transfers.length == 0) ? null
				: transfers[0];
	}

	public ContigTransferRequest createContigTransferRequest(Person requester,
			int contigId, int toProjectId)
			throws ContigTransferRequestException, ArcturusDatabaseException {
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

		contig = adb.getContigByID(contigId, ArcturusDatabase.CONTIG_BASIC_DATA);

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
			throws ContigTransferRequestException, ArcturusDatabaseException {
		adb.updateContig(contig, ArcturusDatabase.CONTIG_BASIC_DATA);
		
		ContigTransferRequest request = null;
		
		try {
			pstmtInsertNewRequest.setInt(1, contig.getID());
			pstmtInsertNewRequest.setInt(2, contig.getProject().getID());
			pstmtInsertNewRequest.setInt(3, toProject.getID());
			pstmtInsertNewRequest.setString(4, requester.getUID());

			int rc = pstmtInsertNewRequest.executeUpdate();

			if (rc != 1)
				throw new ContigTransferRequestException(
						ContigTransferRequestException.SQL_INSERT_FAILED);

			ResultSet rs = pstmtInsertNewRequest.getGeneratedKeys();

			int requestId = rs.next() ? rs.getInt(1) : -1;

			rs.close();

			request = findContigTransferRequest(requestId);

			notifier.notifyRequestStatusChange(requester, request,
					ContigTransferRequest.UNKNOWN);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to create contig transfer request for " + requester.getName() +
					" to move contig " + contig.getID() + " to project ID=" + toProject.getID() , conn, this);
		}

		return request;
	}

	protected void checkForExistingRequests(int contigId)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		int requestId = countActiveRequestsForContig(contigId);

		if (requestId > 0)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.CONTIG_ALREADY_REQUESTED);
	}

	protected int countActiveRequestsForContig(int contigId)
			throws ArcturusDatabaseException {
		int count = 0;
		
		try {
			pstmtCountActiveRequestsByContigId.setInt(1, contigId);

			ResultSet rs = pstmtCountActiveRequestsByContigId.executeQuery();

			count = rs.next() ? rs.getInt(1) : 0;

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to count active requests for contig ID=" + contigId, conn, this);
		}

		return count;
	}

	protected void checkIsCurrentContig(int contigId)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		if (!adb.isCurrentContig(contigId))
			throw new ContigTransferRequestException(
					ContigTransferRequestException.CONTIG_NOT_CURRENT);
	}

	protected void checkCanUserTransferBetweenProjects(Person requester,
			Project fromProject, Project toProject)
			throws ContigTransferRequestException, ArcturusDatabaseException {
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

		if (requester.canMoveAnyContig())
			return;

		/*
		 * Does the requester have the "team leader", "administrator" or
		 * "superuser" role?
		 */

		if (adb.hasFullPrivileges(requester))
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.USER_NOT_AUTHORISED);
	}

	public ContigTransferRequest createContigTransferRequest(int contigId,
			int toProjectId) throws ContigTransferRequestException,
			ArcturusDatabaseException {
		return createContigTransferRequest(adb.findMe(), contigId,
				toProjectId);
	}

	public ContigTransferRequest createContigTransferRequest(Person requester,
			Contig contig, Project project)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		return createContigTransferRequest(requester, contig.getID(), project
				.getID());
	}

	public ContigTransferRequest createContigTransferRequest(Contig contig,
			Project project) throws ContigTransferRequestException,
			ArcturusDatabaseException {
		return createContigTransferRequest(adb.findMe(), contig
				.getID(), project.getID());
	}

	public boolean canCancelRequest(ContigTransferRequest request, Person user) throws ArcturusDatabaseException {
		if (request == null || user == null)
			return false;

		int status = request.getStatus();

		if (status == ContigTransferRequest.REFUSED
				|| status == ContigTransferRequest.FAILED
				|| status == ContigTransferRequest.DONE)
			return false;

		return request.getRequester().equals(user)
				|| adb.hasFullPrivileges(user);
	}

	public boolean canRefuseRequest(ContigTransferRequest request, Person user) throws ArcturusDatabaseException {
		if (request == null || user == null)
			return false;

		if (request.getStatus() != ContigTransferRequest.PENDING)
			return false;

		Person requester = request.getRequester();

		Person srcOwner = request.getOldProject().getOwner();
		Person dstOwner = request.getNewProject().getOwner();

		if (user.equals(srcOwner) && !requester.equals(srcOwner))
			return true;

		if (user.equals(dstOwner) && !requester.equals(dstOwner))
			return true;
		
		return adb.hasFullPrivileges(user);
	}
	
	public boolean canApproveRequest(ContigTransferRequest request,
			Person user) throws ArcturusDatabaseException {
		if (request == null || user == null)
			return false;

		if (request.getStatus() != ContigTransferRequest.PENDING)
			return false;

		Person requester = request.getRequester();

		Project srcProject = request.getOldProject();
		Person srcOwner = srcProject.getOwner();

		Project dstProject = request.getNewProject();
		Person dstOwner = dstProject.getOwner();

		boolean userIsRequester = user.equals(requester);
		
		boolean userOwnsSrcProject = user.equals(srcOwner);
		boolean userOwnsDstProject = user.equals(dstOwner);
		
		boolean srcProjectIsUnowned = srcProject.isUnowned() || srcProject.isBin();
		boolean dstProjectIsUnowned = dstProject.isUnowned() || dstProject.isBin();
		
		boolean bothProjectsAreOwned = !srcProjectIsUnowned && !dstProjectIsUnowned;
		
		boolean requesterOwnsSrcProject = requester.equals(srcOwner);
		boolean requesterOwnsDstProject = requester.equals(dstOwner);

		// The requester can approve a transfer between a project which s/he
		// owns and an unowned project, or between two project which s/he owns.
		
		if (userIsRequester) {	
			if (userOwnsSrcProject && dstProjectIsUnowned)
				return true;
			
			if (userOwnsDstProject && srcProjectIsUnowned)
				return true;
			
			if (userOwnsSrcProject && userOwnsDstProject)
				return true;
			
			if (srcProjectIsUnowned && dstProjectIsUnowned)
				return true;
		}
		
		// If the source and destination projects have owners, then the owner
		// who is not the requester must approve the request.
		
		if (bothProjectsAreOwned) {		
			if (requesterOwnsSrcProject && userOwnsDstProject)
				return true;
			
			if (requesterOwnsDstProject && userOwnsSrcProject)
				return true;
		}	
		
		if (userOwnsSrcProject && dstProjectIsUnowned)
			return true;
		
		if (userOwnsDstProject && srcProjectIsUnowned)
			return true;
		
		// A project manager, coordinator or administrator can approve any request.
		return adb.hasFullPrivileges(user);
	}

	public boolean canExecuteRequest(ContigTransferRequest request,
			Person user) throws ArcturusDatabaseException {
		if (request == null || user == null)
			return false;

		if (request.getStatus() != ContigTransferRequest.APPROVED)
			return false;

		Person requester = request.getRequester();

		Person srcOwner = request.getOldProject().getOwner();
		Person dstOwner = request.getNewProject().getOwner();

		return user.equals(requester) || user.equals(srcOwner)
				|| user.equals(dstOwner) || adb.hasFullPrivileges(user);
	}

	protected boolean markRequestAsFailed(ContigTransferRequest request)
			throws ArcturusDatabaseException {
		boolean success = false;
		
		try {
			pstmtMarkRequestAsFailed.setInt(1, request.getRequestID());
			
			success = pstmtMarkRequestAsFailed.executeUpdate() == 1;
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to mark request ID=" + request.getRequestID() + " as failed",
					conn, this);
		}
		
		if (success) {
			request.setStatus(ContigTransferRequest.FAILED);
			return true;
		} else
			return false;
	}

	public void reviewContigTransferRequest(ContigTransferRequest request,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		/*
		 * Ensure that the requester is a real person.
		 */

		if (reviewer == null)
			throw new ContigTransferRequestException(request,
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
			ctre.setRequest(request);
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
			throws ContigTransferRequestException, ArcturusDatabaseException {
		int currentProjectID = -1;
		
		try {
			pstmtProjectIDForContig.setInt(1, request.getContig().getID());

			ResultSet rs = pstmtProjectIDForContig.executeQuery();

			currentProjectID = rs.next() ? rs.getInt(1) : -1;

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e,
					"Failed to confirm project is still valid for request ID=" + request.getRequestID(),
					conn, this);
		}

		Project fromProject = request.getOldProject();
		Project contigProject = request.getContig().getProject();

		if (fromProject != null && contigProject != null
				&& fromProject.getID() == currentProjectID)
			return;

		throw new ContigTransferRequestException(request,
				ContigTransferRequestException.CONTIG_HAS_MOVED);
	}

	protected void checkCanUserAlterRequestStatus(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		if (adb.hasFullPrivileges(reviewer))
			return;
		
		switch (newStatus) {
			case ContigTransferRequest.CANCELLED:
				if (canCancelRequest(request, reviewer))
					return;
				break;
				
			case ContigTransferRequest.REFUSED:
				if (canRefuseRequest(request, reviewer))
					return;				
				break;
				
			case ContigTransferRequest.APPROVED:
				if (canApproveRequest(request, reviewer))
					return;
				break;
				
			case ContigTransferRequest.DONE:
				if (canExecuteRequest(request, reviewer))
					return;
				break;
		}

		throw new ContigTransferRequestException(request,
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

		throw new ContigTransferRequestException(request,
				ContigTransferRequestException.INVALID_STATUS_CHANGE);
	}

	protected void changeContigRequestStatus(ContigTransferRequest request,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		int oldStatus = request.getStatus();

		String newStatusString = ContigTransferRequest
				.convertStatusToString(newStatus);
		
		int rc = -1;
		
		try {
			pstmtUpdateRequestStatus.setString(1, newStatusString);
			pstmtUpdateRequestStatus.setString(2, reviewer.getUID());
			pstmtUpdateRequestStatus.setInt(3, request.getRequestID());

			rc = pstmtUpdateRequestStatus.executeUpdate();
		}
			catch (SQLException e) {
				adb.handleSQLException(e, "Failed to update status for request ID=" + request.getRequestID(),
						conn, this);
		}

		if (rc != 1)
			throw new ContigTransferRequestException(request,
					ContigTransferRequestException.SQL_UPDATE_FAILED);

		request.setStatus(newStatus);
		request.setReviewer(reviewer);

		if (newStatus == ContigTransferRequest.REFUSED
				|| newStatus == ContigTransferRequest.CANCELLED) {
			try {
				pstmtSetClosedDate.setInt(1, request.getRequestID());
				pstmtSetClosedDate.executeUpdate();
			}
			catch (SQLException e) {
				adb.handleSQLException(e, "Failed to set closed date for request ID=" + request.getRequestID(),
						conn, this);
		}
		}

		notifier.notifyRequestStatusChange(reviewer, request, oldStatus);
	}

	public void reviewContigTransferRequest(int requestId, Person reviewer,
			int newStatus) throws ContigTransferRequestException, ArcturusDatabaseException {
		ContigTransferRequest request = findContigTransferRequest(requestId);
		reviewContigTransferRequest(request, reviewer, newStatus);
	}

	public void reviewContigTransferRequest(int requestId, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		reviewContigTransferRequest(requestId, adb.findMe(),
				newStatus);
	}

	public void executeContigTransferRequest(ContigTransferRequest request,
			Person reviewer, boolean notifyListeners) throws ContigTransferRequestException,
			ArcturusDatabaseException {
		int oldStatus = request.getStatus();

		if (reviewer == null)
			throw new ContigTransferRequestException(request,
					ContigTransferRequestException.USER_IS_NULL);

		checkStatusChangeIsAllowed(request, ContigTransferRequest.DONE);

		try {
			Contig contig = request.getContig();
			int contig_id = contig == null ? 0 : contig.getID();
			checkIsCurrentContig(contig_id);
			checkContigProjectStillValid(request);
		} catch (ContigTransferRequestException ctre) {
			markRequestAsFailed(request);
			ctre.setRequest(request);
			throw ctre;
		}

		checkCanUserAlterRequestStatus(request, reviewer,
				ContigTransferRequest.DONE);

		checkProjectsAreUnlocked(request);

		executeRequest(request);

		notifier.notifyRequestStatusChange(reviewer, request, oldStatus);
		
		if (notifyListeners) {
			Project project = request.getOldProject();
		
			ProjectChangeEvent event = new ProjectChangeEvent(this,
					project, ProjectChangeEvent.CONTIGS_CHANGED);

			adb.notifyProjectChangeEventListeners(event, null);
		
			project = request.getNewProject();
		
			event = new ProjectChangeEvent(this,
					project, ProjectChangeEvent.CONTIGS_CHANGED);

			adb.notifyProjectChangeEventListeners(event, null);
		}
	}

	protected void executeRequest(ContigTransferRequest request)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		Contig contig = request.getContig();

		try {
			pstmtMoveContig.setInt(1, request.getNewProject().getID());
			pstmtMoveContig.setInt(2, contig.getID());
			pstmtMoveContig.setInt(3, request.getOldProject().getID());

			int rc = pstmtMoveContig.executeUpdate();

			if (rc != 1)
				throw new ContigTransferRequestException(request,
						ContigTransferRequestException.SQL_UPDATE_FAILED);

			pstmtMarkRequestAsDone.setInt(1, request.getRequestID());

			rc = pstmtMarkRequestAsDone.executeUpdate();

			if (rc == 1) {
				request.setStatus(ContigTransferRequest.DONE);
				contig.setProject(request.getNewProject());
				return;
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to execute request ID=" + request.getRequestID(), conn, this);
		}
	}

	protected static final int SOURCE_PROJECT = 1;
	protected static final int DESTINATION_PROJECT = 2;
	
	protected void checkProjectsAreUnlocked(ContigTransferRequest request)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		checkProjectIsUnlocked(request, SOURCE_PROJECT);
		checkProjectIsUnlocked(request, DESTINATION_PROJECT);
	}

	protected void checkProjectIsUnlocked(ContigTransferRequest request, int mode)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		Project project = (mode == SOURCE_PROJECT) ? request.getOldProject() : request.getNewProject();
		
		boolean lockdateNull = false;
		boolean lockownerNull = false;
		
		try {
			pstmtCheckProjectLock.setInt(1, project.getID());

			ResultSet rs = pstmtCheckProjectLock.executeQuery();

			rs.next();

			rs.getTimestamp(1);
			lockdateNull = rs.wasNull();

			rs.getString(2);
			lockownerNull = rs.wasNull();

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to execute request ID=" + request.getRequestID(), conn, this);
		}

		if (lockdateNull && lockownerNull)
			return;
		else
			throw new ContigTransferRequestException(request,
					ContigTransferRequestException.PROJECT_IS_LOCKED,
					mode == SOURCE_PROJECT ? "Source project is locked" : "Destination project is locked");
	}

	public void executeContigTransferRequest(int requestId, Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		ContigTransferRequest request = findContigTransferRequest(requestId);
		executeContigTransferRequest(request, reviewer, notifyListeners);
	}

	public void executeContigTransferRequest(int requestId, boolean notifyListeners)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		executeContigTransferRequest(requestId, adb.findMe(), notifyListeners);
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

	public void moveContigs(Project fromProject, Project toProject) throws ArcturusDatabaseException {
		if (fromProject == null || toProject == null) {
			Arcturus.logWarning("Attempted to move contigs from " + 
					(fromProject == null ? "NULL project" : fromProject.getName()) +
					" to " +
					(toProject == null ? "NULL project " : toProject.getName()));
			return;	
		}
			
		int fromID = fromProject.getID();
		int toID = toProject.getID();
		
		try {
			pstmtContigsByProjectID.setInt(1, fromID);

			ResultSet rs = pstmtContigsByProjectID.executeQuery();

			while (rs.next()) {
				int contig_id = rs.getInt(1);

				pstmtMoveContig.setInt(1, toID);
				pstmtMoveContig.setInt(2, contig_id);
				pstmtMoveContig.setInt(3, fromID);

				pstmtMoveContig.executeUpdate();
			}

			rs.close();		
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to move contigs from project ID=" + fromProject.getID() +
					" to project ID=" + toProject.getID(), conn, this);
		}
	
	}

	public void clearCache() {
		// Does nothing
	}

	public void preload() throws ArcturusDatabaseException {
		// Does nothing
	}

	public String getCacheStatistics() {
		return "ByID: " + cache.size();
	}
}
