package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.Arcturus;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.contigtransfer.*;

import java.sql.*;
import java.util.*;
import java.util.zip.DataFormatException;

public class ContigTransferRequestManager {
	private ArcturusDatabase adb;
	private Connection conn;

	protected PreparedStatement pstmtByRequester = null;
	protected PreparedStatement pstmtByContigOwner = null;
	
	/**
	 * Creates a new ContigTransferRequestManager to provide contig transfer request
	 * management services to an ArcturusDatabase object.
	 */

	public ContigTransferRequestManager(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;

		conn = adb.getConnection();

		prepareStatements();
	}
	
	private void prepareStatements() throws SQLException {
		String columns= "request_id,contig_id,old_project_id,new_project_id,requester," +
			"requester_comment,opened,reviewer,reviewer_comment,reviewed,CONTIGTRANSFERREQUEST.status,closed";
		
		String query;

		query = "select " + columns +
			" from CONTIGTRANSFERREQUEST" +
			" where requester = ? and status = ?";

		pstmtByRequester = conn.prepareStatement(query);

		query = "select " + columns +
			" from CONTIGTRANSFERREQUEST left join PROJECT on old_project_id=project_id" +
			" where owner = ? and CONTIGTRANSFERREQUEST.status = ?";
		
		pstmtByContigOwner = conn.prepareStatement(query);
	}

	public ContigTransferRequest[] getContigTransferRequestsByUser(Person user, int mode) throws SQLException {
		PreparedStatement pstmt = (mode == ArcturusDatabase.USER_IS_REQUESTER) ? pstmtByRequester : pstmtByContigOwner;
		
		pstmt.setString(1, user.getUID());
		pstmt.setString(2, "pending");
		
		ResultSet rs = pstmt.executeQuery();
		
		ContigTransferRequest[] transfers = getTransfersFromResultSet(rs);
		
		rs.close();
		
		return transfers;
	}
	
	private ContigTransferRequest[] getTransfersFromResultSet(ResultSet rs) throws SQLException {
		Vector v = new Vector();
		
		Contig contig = null;
		
		while (rs.next()) {
			int requestId = rs.getInt(1);
			
			int contigId = rs.getInt(2);
			try {
				contig = adb.getContigByID(contigId, ArcturusDatabase.CONTIG_BASIC_DATA);
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
			
			ContigTransferRequest request = new ContigTransferRequest(requestId, contig,
					oldProject, newProject, requester, requesterComment);
		
			request.setOpenedDate(rs.getTimestamp(7));
			
			String reviewerUid = rs.getString(8);
			Person reviewer = reviewerUid != null ? PeopleManager.findPerson(reviewerUid) : null;
			
			request.setReviewer(reviewer);
			
			request.setReviewerComment(rs.getString(9));
			
			request.setReviewedDate(rs.getTimestamp(10));
			
			request.setStatusAsString(rs.getString(11));
			
			request.setClosedDate(rs.getTimestamp(12));
			
			v.add(request);
		}
		
		return (ContigTransferRequest[])(v.toArray(new ContigTransferRequest[0]));
	}
}
