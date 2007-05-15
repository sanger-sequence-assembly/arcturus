package uk.ac.sanger.arcturus.contigtransfer;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ContigTransferRequestManager;
import uk.ac.sanger.arcturus.people.Person;

import javax.mail.*;
import javax.mail.internet.*;

import java.util.Properties;

public class ContigTransferRequestNotifier {
	public static final int AS_REQUESTER = 1;
	public static final int AS_CONTIG_OWNER = 2;
	public static final int AS_DESTINATION_PROJECT_OWNER = 3;

	private static ContigTransferRequestNotifier instance = new ContigTransferRequestNotifier();

	protected Session session = null;

	private ContigTransferRequestNotifier() {
		Properties props = Arcturus.getProperties();
		session = Session.getDefaultInstance(props);
	}

	public static ContigTransferRequestNotifier getInstance() {
		return instance;
	}

	public void notifyRequestStatusChange(Person reviewer,
			ContigTransferRequest request, int oldStatus) {
		Person requester = request.getRequester();

		Person contigOwner = request.getContigOwner();

		Person destinationProjectOwner = request.getNewProject().getOwner();

		if (!reviewer.equals(requester))
			notify(requester, AS_REQUESTER, reviewer, request, oldStatus);

		if (contigOwner != null && !reviewer.equals(contigOwner)
				&& !requester.equals(contigOwner))
			notify(contigOwner, AS_CONTIG_OWNER, reviewer, request, oldStatus);

		if (destinationProjectOwner != null
				&& !reviewer.equals(destinationProjectOwner)
				&& !requester.equals(destinationProjectOwner))
			notify(destinationProjectOwner, AS_DESTINATION_PROJECT_OWNER,
					reviewer, request, oldStatus);
	}

	protected String getRoleName(int role) {
		switch (role) {
			case AS_REQUESTER:
				return "requester";
			case AS_CONTIG_OWNER:
				return "contig owner";
			case AS_DESTINATION_PROJECT_OWNER:
				return "destination project owner";
			default:
				return "unknown";
		}
	}

	protected void notify(Person person, int role, Person reviewer,
			ContigTransferRequest request, int oldStatus) {
		System.err
				.println("================================================================================\n");
		System.err.println("NOTIFICATION TO " + person.getName() + " <"
				+ person.getMail() + "> as " + getRoleName(role) + "\n");

		String message = createMessage(person, role, reviewer, request,
				oldStatus);
		System.err.println(message);

		System.err
				.println("================================================================================\n");
		System.err.println("\n\n");
	}

	protected String createMessage(Person person, int role, Person reviewer,
			ContigTransferRequest request, int oldStatus) {
		StringBuffer sb = new StringBuffer(2048);

		Contig contig = request.getContig();
		Project oldProject = request.getOldProject();
		Project newProject = request.getNewProject();

		String organism = contig.getArcturusDatabase().getName();

		String requesterName = request.getRequester().getName();

		sb.append("Dear " + person.getGivenName() + ",\n\n");

		if (oldStatus == ContigTransferRequest.UNKNOWN) {
			sb.append("A new contig transfer request has been created by "
					+ requesterName + ".\n\n");
			sb.append("The request is " + organism + " #"
					+ request.getRequestID() + ".\n\n");

			switch (role) {
				case AS_CONTIG_OWNER:
					sb.append(requesterName + " has asked to move your contig "
							+ contig.getID() + " (" + contig.getLength()
							+ "bp, " + contig.getReadCount()
							+ " reads)\nfrom project " + oldProject.getName()
							+ " to project " + newProject.getName() + "\n\n");
					break;

				case AS_DESTINATION_PROJECT_OWNER:
					sb.append(requesterName + " has asked to move contig "
							+ contig.getID() + " (" + contig.getLength()
							+ "bp, " + contig.getReadCount()
							+ " reads)\nfrom project " + oldProject.getName()
							+ " to your project " + newProject.getName()
							+ "\n\n");
					break;
			}

			sb.append("Please use Minerva to view this request and approve or refuse it.");
		} else {
			String verb = request.getStatus() == ContigTransferRequest.DONE ? "executed"
					: "reviewed";

			sb.append("Contig transfer request " + organism + " #"
					+ request.getRequestID() + " has been " + verb + " by "
					+ reviewer.getName() + ".\n\n");

			sb.append("This request is for contig " + contig.getID()
							+ " (" + contig.getLength() + "bp, "
							+ contig.getReadCount() + " reads) in project "
							+ oldProject.getName() + "\nto be moved to project "
							+ newProject.getName() + ".\n\n");

			switch (role) {
				case AS_REQUESTER:
					sb.append("You are the owner of this request.\n\n");
					break;

				case AS_CONTIG_OWNER:
					verb = request.getStatus() == ContigTransferRequest.DONE ?
							"were" : "are";
					sb.append("You " + verb + " the owner of the contig in question.\n\n");
					break;

				case AS_DESTINATION_PROJECT_OWNER:
					sb.append("You own the destination project.\n\n");
					break;
			}

			sb.append("The status of the request has changed from "
					+ ContigTransferRequest.convertStatusToString(oldStatus)
					+ " to " + request.getStatusString() + ".\n\n");

			switch (request.getStatus()) {
				case ContigTransferRequest.APPROVED:
					sb.append("This means that permission has been granted to execute the request.\n");
					sb.append("However, please note that for the moment, the contig is still in " 
							+ oldProject.getName() + ".\n");
					break;

				case ContigTransferRequest.REFUSED:
					sb.append("This means that permisson for this request was denied.\n");
					break;

				case ContigTransferRequest.FAILED:
					sb.append("This means that there was a problem with the request,\nand it was deleted.\n");
					break;

				case ContigTransferRequest.DONE:
					sb.append("This means that the contig has been moved from "
							+ oldProject.getName() + " to "
							+ newProject.getName() + ".\n");
					break;
			}
		}

		return sb.toString();
	}
}
