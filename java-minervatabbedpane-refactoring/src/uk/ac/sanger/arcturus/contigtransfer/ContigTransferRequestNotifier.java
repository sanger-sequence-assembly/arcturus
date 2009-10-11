package uk.ac.sanger.arcturus.contigtransfer;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.people.*;

import javax.mail.*;
import javax.mail.internet.*;

import java.io.UnsupportedEncodingException;
import java.util.*;

public class ContigTransferRequestNotifier {
	public static final int AS_REQUESTER = 1;
	public static final int AS_CONTIG_OWNER = 2;
	public static final int AS_DESTINATION_PROJECT_OWNER = 3;

	private static ContigTransferRequestNotifier instance = new ContigTransferRequestNotifier();

	protected Session session = null;
	
	protected Map<Person, List<String>> messageQueues = new HashMap<Person, List<String>>();
	
	protected boolean noMail = false;
	
	protected ArcturusDatabase adb;

	public ContigTransferRequestNotifier() {
		Properties props = Arcturus.getProperties();
		session = Session.getDefaultInstance(props);
		
		noMail = Boolean.getBoolean("contigtransferrequestnotifier.nomail");
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
		String message = createMessage(person, role, reviewer, request,
				oldStatus);
		
		enqueueMessage(person, message);
	}
	
	protected synchronized void enqueueMessage(Person recipient, String message) {
		List<String> messageList = messageQueues.get(recipient);
		
		if (messageList == null) {
			messageList = new Vector<String>();
			messageQueues.put(recipient, messageList);
		}
		
		messageList.add(message);
	}
	
	public synchronized void processAllQueues() {		
		for (Person recipient: messageQueues.keySet())
			processQueueForRecipient(recipient);
	}
	
	protected synchronized void processQueueForRecipient(Person person) {
		List<String> messages = messageQueues.get(person);
		
		if (messages == null || messages.isEmpty())
			return;
		
		StringBuffer sb = new StringBuffer();

		sb.append("Dear " + person.getGivenName() + ",\n\n");

		String separator = "\n----------------------------------------"
			+ "----------------------------------------\n\n";
		
		for (Iterator<String> iter = messages.iterator(); iter.hasNext();) {
			sb.append(iter.next());
			iter.remove();
			sb.append(separator);
		}

		Message msg = new MimeMessage(session);

		Person realme = PeopleManager.createPerson(PeopleManager.getRealUID());

		try {
			InternetAddress realMeAddress = new InternetAddress(realme.getMail(), realme
					.getName());

			String email = PeopleManager.isMasquerading() ? realme.getUID()
					+ "+" + person.getMail() : person.getMail();

			InternetAddress recipient = null;

			try {
				recipient = new InternetAddress(email, person.getName());
			} catch (UnsupportedEncodingException e) {
				e.printStackTrace();
			}

			msg.addRecipient(Message.RecipientType.TO, recipient);

			msg.setFrom(realMeAddress);
			
			String subject = "[Arcturus]" + (PeopleManager.isMasquerading()  ? " *** TEST ***" : "") +
				" Notification from the contig transfer request manager";
			
			msg.setSubject(subject);
			
			msg.setText(sb.toString());

			msg.setHeader("X-Mailer", "Arcturus-Notification");
			msg.setSentDate(new java.util.Date());
			
			if (noMail)
				msg.writeTo(System.err);
			else
				Transport.send(msg);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	protected String createMessage(Person person, int role, Person reviewer,
			ContigTransferRequest request, int oldStatus) {
		StringBuffer sb = new StringBuffer(2048);

		Contig contig = request.getContig();
		Project oldProject = request.getOldProject();
		Project newProject = request.getNewProject();

		String organism = contig.getArcturusDatabase().getName();

		String requesterName = request.getRequester().getName();
		String requesterGivenName = request.getRequester().getGivenName();

		if (oldStatus == ContigTransferRequest.UNKNOWN) {
			sb.append("A new contig transfer request has been created by "
					+ requesterName + ".\n\n");
			sb.append("The request is " + organism + " #"
					+ request.getRequestID() + ".\n\n");

			switch (role) {
				case AS_CONTIG_OWNER:
					sb.append(requesterGivenName + " has asked to move your contig "
							+ contig.getID() + " (" + contig.getLength()
							+ "bp, " + contig.getReadCount()
							+ " reads)\nfrom project " + oldProject.getName()
							+ " to project " + newProject.getName() + "\n\n");
					break;

				case AS_DESTINATION_PROJECT_OWNER:
					sb.append(requesterGivenName + " has asked to move contig "
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
					: request.getStatusString();

			sb.append("Contig transfer request " + organism + " #"
					+ request.getRequestID() + " has been " + verb + " by "
					+ reviewer.getName() + ".\n\n");

			sb.append("This request is for contig " + contig.getID() + " ("
					+ contig.getLength() + "bp, " + contig.getReadCount()
					+ " reads) in project " + oldProject.getName()
					+ "\nto be moved to project " + newProject.getName()
					+ ".\n\n");

			switch (role) {
				case AS_REQUESTER:
					sb.append("You are the owner of this request.\n\n");
					break;

				case AS_CONTIG_OWNER:
					verb = request.getStatus() == ContigTransferRequest.DONE ? "were"
							: "are";
					sb.append("You " + verb
							+ " the owner of the contig in question.\n\n");
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
					sb
							.append("This means that permission has been granted to execute the request.\n");
					sb
							.append("However, please note that for the moment, the contig is still in "
									+ oldProject.getName() + ".\n");
					break;

				case ContigTransferRequest.REFUSED:
					sb
							.append("This means that permisson for this request was denied.\n");
					break;

				case ContigTransferRequest.FAILED:
					sb
							.append("This means that there was a problem with the request,\nand it was deleted.\n");
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
