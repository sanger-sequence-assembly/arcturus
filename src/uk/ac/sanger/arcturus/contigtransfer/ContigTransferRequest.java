package uk.ac.sanger.arcturus.contigtransfer;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.people.Person;
import java.util.Date;

public class ContigTransferRequest {
	public static final int UNKNOWN = 0;
	public static final int PENDING = 1;
	public static final int APPROVED = 2;
	public static final int DONE = 4;
	public static final int CANCELLED = 8;
	public static final int FAILED = 16;
	public static final int REFUSED = 32;
	
	public static final int ACTIVE = PENDING | APPROVED;
	public static final int ALL = PENDING | APPROVED | DONE | CANCELLED | FAILED | REFUSED;

	private int request_id;
	private Contig contig;
	private int contig_id;
	private Project oldProject;
	private Project newProject;

	private Person requester;
	private Date openedDate;
	private String requesterComment;

	private Person reviewer;
	private String reviewerComment;
	private Date reviewedDate;

	private int status = PENDING;

	private Date closedDate;
	
	private ContigTransferRequestEventListener listener;
	private ContigTransferRequestEvent event;

	public ContigTransferRequest(int request_id, Contig contig,
			Project oldProject, Project newProject, Person requester,
			String requesterComment) {
		this.request_id = request_id;
		this.contig = contig;
		this.oldProject = oldProject;
		this.newProject = newProject;
		this.requester = requester;
		this.requesterComment = requesterComment;
	}

	public ContigTransferRequest(Contig contig, Project oldProject,
			Project newProject, Person requester, String requesterComment) {
		this(-1, contig, oldProject, newProject, requester, requesterComment);
	}

	public ContigTransferRequest(Contig contig, Project oldProject,
			Project newProject, Person requester) {
		this(-1, contig, oldProject, newProject, requester, null);
	}

	public int getRequestID() {
		return request_id;
	}

	public void setRequestID(int request_id) {
		this.request_id = request_id;
	}

	public Contig getContig() {
		return contig;
	}
	
	public Person getContigOwner() {
		return (oldProject == null) ? null : oldProject.getOwner();
	}
	
	public int getContigID() {
		return contig != null ? contig.getID() : contig_id;
	}
	
	public void setContigID(int contig_id) {
		if (contig == null)
			this.contig_id = contig_id;
		else
			throw new IllegalStateException("Cannot set an explicit contig ID when contig is not null");
	}

	public Project getOldProject() {
		return oldProject;
	}

	public Project getNewProject() {
		return newProject;
	}

	public Person getRequester() {
		return requester;
	}
	
	public Date getOpenedDate() { return openedDate; }
	
	public void setOpenedDate(Date openedDate) {
		this.openedDate = openedDate;
	}

	public String getRequesterComment() {
		return requesterComment;
	}

	public void setRequesterComment(String requesterComment) {
		this.requesterComment = requesterComment;
	}
	
	public Person getReviewer() {
		return reviewer;
	}
	
	public void setReviewer(Person reviewer) {
		this.reviewer = reviewer;
	}
	
	public Date getReviewedDate() {
		return reviewedDate;
	}
	
	public void setReviewedDate(Date reviewedDate) {
		this.reviewedDate = reviewedDate;
	}
	
	public String getReviewerComment() {
		return reviewerComment;
	}
	
	public void setReviewerComment(String reviewerComment) {
		this.reviewerComment = reviewerComment;
	}
	
	public int getStatus() {
		return status;
	}
	
	public static String convertStatusToString(int status) {
		switch(status) {
			case PENDING:
				return "pending";
				
			case APPROVED:
				return "approved";
				
			case CANCELLED:
				return "cancelled";
				
			case FAILED:
				return "failed";
				
			case REFUSED:
				return "refused";
				
			case DONE:
				return "done";
				
			case ACTIVE:
				return "active (pending or approved)";
				
			default:
				return "unknown";
		}
	}
	
	public String getStatusString() {
		return convertStatusToString(status);
	}
	
	public void setStatusAsString(String str) {
		int s = convertStringToStatus(str);
		
		if (s == UNKNOWN)
			throw new IllegalArgumentException("Status is invalid: \"" + str + "\"");
		
		this.status = convertStringToStatus(str);
	}
	
	public static int convertStringToStatus(String str) {
		if (str.equalsIgnoreCase("pending"))
			return PENDING;
		
		if (str.equalsIgnoreCase("approved"))
			return APPROVED;
	
		if (str.equalsIgnoreCase("cancelled"))
			return CANCELLED;
		
		if (str.equalsIgnoreCase("failed"))
			return FAILED;
		
		if (str.equalsIgnoreCase("refused"))
			return REFUSED;
		
		if (str.equalsIgnoreCase("done"))
			return DONE;
		
		return UNKNOWN;
	}
	
	public void setStatus(int status) {
		if (!isValidStatus(status))
			throw new IllegalArgumentException("Status is invalid: " + status);
		
		this.status = status;
	}
	
	public boolean isActive() {
		return status == PENDING || status == APPROVED;
	}
	
	public Date getClosedDate() {
		return closedDate;
	}
	
	public void setClosedDate(Date closedDate) {
		this.closedDate = closedDate;
	}
	
	public boolean isClosed() {
		return isClosedStatus(status);
	}
	
	private boolean isClosedStatus(int s) {
		return s == DONE || s == FAILED || s == REFUSED || s == CANCELLED;
	}
	
	private boolean isValidStatus(int s) {
		return s == PENDING || s == APPROVED || s == DONE ||
			s == FAILED || s == REFUSED || s == CANCELLED;
	}
	
	public void review(Person reviewer, Date reviewedDate, int status, String reviewerComment) {
		if (!isValidStatus(status))
			throw new IllegalArgumentException("Status is invalid: " + status);
		
		setReviewer(reviewer);
		setReviewedDate(reviewedDate);
		setReviewerComment(reviewerComment);
		
		if (isClosedStatus(status))
			setClosedDate(reviewedDate);
		
		int oldStatus = status;
		
		setStatus(status);
		
		if (listener != null) {
			event.setOldStatus(oldStatus);
			listener.stateChanged(event);
		}
	}
	
	public void pending(Person reviewer, Date reviewedDate, String reviewerComment) {
		review(reviewer, reviewedDate, PENDING, reviewerComment);
	}

	public void cancel(Person reviewer, Date reviewedDate, String reviewerComment) {
		review(reviewer, reviewedDate, CANCELLED, reviewerComment);
	}
	
	public void refuse(Person reviewer, Date reviewedDate, String reviewerComment) {
		review(reviewer, reviewedDate, REFUSED, reviewerComment);
	}
	
	public void fail(Person reviewer, Date reviewedDate, String reviewerComment) {
		review(reviewer, reviewedDate, FAILED, reviewerComment);
	}
	
	public void approve(Person reviewer, Date reviewedDate, String reviewerComment) {
		review(reviewer, reviewedDate, APPROVED, reviewerComment);
	}
	
	public void done(Person reviewer, Date reviewedDate, String reviewerComment) {
		review(reviewer, reviewedDate, DONE, reviewerComment);
	}
	
	public void setContigTransferRequestEventListener(ContigTransferRequestEventListener listener) {
		this.listener = listener;
		
		if (event == null)
			event = new ContigTransferRequestEvent(this, UNKNOWN);
	}
	
	public ContigTransferRequestEventListener getContigTransferRequestEventListener() {
		return listener;
	}
	
	public String toString() {
		return "ContigTransferRequest[id=" + request_id + ", contig_id=" + contig.getID() +
			", old_project=" + oldProject.getName() + ", new_project=" + newProject.getName() +
			", requester=" + requester.getName() + ", opened=" + openedDate + "]";
	}
}
