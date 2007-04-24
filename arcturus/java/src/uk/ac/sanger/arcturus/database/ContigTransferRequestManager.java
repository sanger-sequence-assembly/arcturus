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

	protected PreparedStatement pstmtByRequester = null;
	protected PreparedStatement pstmtByContigOwner = null;
	protected PreparedStatement pstmtByID = null;

	protected PreparedStatement pstmtCountActiveRequestsByContigId = null;

	protected PreparedStatement pstmtInsertNewRequest = null;

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
				+ " where (requester = ? or owner = ?) and opened > date_sub(now(), interval 14 day)";

		pstmtByRequester = conn.prepareStatement(query);

		query = "select "
				+ columns
				+ " from CONTIGTRANSFERREQUEST left join PROJECT on old_project_id=project_id"
				+ " where owner = ? and opened > date_sub(now(), interval 14 day)";

		pstmtByContigOwner = conn.prepareStatement(query);

		query = "select " + columns
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
		Vector v = new Vector();

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

			if (contig == null) {
				Arcturus.logWarning("Contig transfer request " + requestId
						+ " refers to a non-existent contig " + contigId);
				continue;
			}

			int oldProjectId = rs.getInt(3);
			Project oldProject = adb.getProjectByID(oldProjectId);

			int newProjectId = rs.getInt(4);
			Project newProject = adb.getProjectByID(newProjectId);

			String requesterUid = rs.getString(5);
			Person requester = PeopleManager.findPerson(requesterUid);

			String requesterComment = rs.getString(6);

			ContigTransferRequest request = new ContigTransferRequest(
					requestId, contig, oldProject, newProject, requester,
					requesterComment);

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

		return (ContigTransferRequest[]) (v
				.toArray(new ContigTransferRequest[0]));
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
		checkUser(requester);
		checkForExistingRequests(contigId);
		checkIsCurrentContig(contigId);

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

		checkCanUserTransferBetweenProjects(requester, fromProject, toProject);

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

			return findContigTransferRequest(requestId);
		} else
			throw new ContigTransferRequestException(
					ContigTransferRequestException.SQL_INSERT_FAILED);
	}

	protected void checkUser(Person user) throws ContigTransferRequestException {
		if (user == null)
			throw new ContigTransferRequestException(
					ContigTransferRequestException.USER_IS_NULL);
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
		if (requester.equals(fromProject.getOwner()) && toProject.isBin())
			return;

		if (requester.equals(toProject.getOwner()))
			return;

		if (adb.hasPrivilege(requester, "move_any_contig"))
			return;

		if (isSuperUser(requester))
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.USER_NOT_AUTHORISED);
	}

	protected boolean isSuperUser(Person person) throws SQLException {
		String role = adb.getRoleForUser(person);

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

	public void reviewContigTransferRequest(ContigTransferRequest request,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		checkUser(reviewer);
		checkIsCurrentContig(request.getContig().getID());

		checkCanUserAlterRequestStatus(request, reviewer, newStatus);

		changeContigRequestStatus(request, reviewer, newStatus);
	}

	protected void checkCanUserAlterRequestStatus(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		if (newStatus == ContigTransferRequest.CANCELLED
				&& reviewer.equals(request.getRequester()))
			return;

		if ((newStatus == ContigTransferRequest.REFUSED || newStatus == ContigTransferRequest.APPROVED)
				&& reviewer.equals(request.getContigOwner()))
			return;

		if (isSuperUser(reviewer))
			return;

		throw new ContigTransferRequestException(
				ContigTransferRequestException.USER_NOT_AUTHORISED);
	}

	protected void changeContigRequestStatus(ContigTransferRequest request,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {

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
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		// XXX to be implemented
	}

	public void executeContigTransferRequest(int requestId, Person reviewer,
			int newStatus) throws ContigTransferRequestException, SQLException {
		ContigTransferRequest request = findContigTransferRequest(requestId);
		executeContigTransferRequest(request, reviewer, newStatus);
	}

	public void executeContigTransferRequest(int requestId, int newStatus)
			throws ContigTransferRequestException, SQLException {
		executeContigTransferRequest(requestId, PeopleManager.findMe(),
				newStatus);
	}

}
