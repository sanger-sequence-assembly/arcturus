package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.contigtransfer.*;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.data.*;

import java.io.*;
import java.sql.*;
import java.util.StringTokenizer;

public class TestContigTransferRequestManager {
	protected ArcturusDatabase adb = null;
	protected ContigTransferRequestManager ctrm = null;

	public static void main(String[] args) {
		TestContigTransferRequestManager tctrm = new TestContigTransferRequestManager();
		tctrm.execute();
	}

	public void execute() {
		System.err.println("TestContigTransferRequestManager");
		System.err.println("================================");
		System.err.println();

		try {
			String instance = "test";

			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			String organism = "TESTPKN";

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			adb = ai.findArcturusDatabase(organism);
			ctrm = adb.getContigTransferRequestManager();

		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

		String line = null;

		BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

		while (true) {
			System.out.print("CMD> ");

			try {
				line = br.readLine();
			} catch (IOException ioe) {
				ioe.printStackTrace();
				System.exit(1);
			}

			if (line == null)
				break;

			StringTokenizer st = new StringTokenizer(line);

			int nwords = st.countTokens();

			if (nwords < 1)
				continue;

			String[] words = new String[nwords];

			for (int i = 0; i < nwords; i++)
				words[i] = st.nextToken();

			if (words[0].equalsIgnoreCase("quit")
					|| words[0].equalsIgnoreCase("exit")) {
				System.out.println("Exiting. Byebye!");
				break;
			}

			executeCommand(words);
		}
	}

	protected void executeCommand(String[] words) {
		if (words[0].equalsIgnoreCase("list"))
			listRequests(words);
		else if (words[0].equalsIgnoreCase("create"))
			createRequest(words);
		else if (words[0].equalsIgnoreCase("review"))
			reviewRequest(words);
		else
			System.out.println("*** Unknown command verb \"" + words[0]
					+ "\" ***");
	}

	protected void listRequests(String[] words) {
		if (words.length < 2) {
			System.out.println("*** Too few arguments: expected username ***");
			return;
		}

		Person user = PeopleManager.findPerson(words[1]);

		if (user == null) {
			System.out.println("User \"" + words[1] + "\" not known");
			return;
		}

		try {
			ContigTransferRequest[] requests = ctrm
					.getContigTransferRequestsByUser(user,
							ArcturusDatabase.USER_IS_REQUESTER);

			for (int i = 0; i < requests.length; i++)
				System.out.println("Request #" + i + " : \n" + prettyPrint(requests[i]));
		} catch (SQLException e) {
			e.printStackTrace();
		}
	}

	protected void createRequest(String[] words) {
		if (words.length < 4) {
			System.out
					.println("*** Too few arguments: expected contig_id project_name username ***");
			return;
		}

		try {
			int contig_id = Integer.parseInt(words[1]);

			Project toProject = adb.getProjectByName(null, words[2]);
			
			if (toProject == null) {
				System.out.println("Project \"" + words[2] + "\" not known");
				return;
			}
			
			int to_project_id = toProject.getID();

			Person requester = PeopleManager.findPerson(words[3]);

			if (requester == null) {
				System.out.println("User \"" + words[3] + "\" not known");
				return;
			}

			ContigTransferRequest request = ctrm.createContigTransferRequest(
					requester, contig_id, to_project_id);
			
			System.out.println("Created new request: \n" + prettyPrint(request));
		} catch (ContigTransferRequestException ctre) {
			reportContigTransferRequestException(ctre);
		}
		catch (Exception e) {
			e.printStackTrace();
		}
	}

	protected void reviewRequest(String[] words) {
		if (words.length < 4) {
			System.out
					.println("*** Too few arguments: expected request_id new_status username ***");
			return;
		}

		try {
			int request_id = Integer.parseInt(words[1]);
			
			ContigTransferRequest request = ctrm.findContigTransferRequest(request_id);
			
			if (request == null) {
				System.out.println("Request #" + request_id + " not found");
				return;
			}
			
			System.out.println("Before review: \n" + prettyPrint(request));
			
			Person reviewer = PeopleManager.findPerson(words[3]);

			if (reviewer == null) {
				System.out.println("User \"" + words[3] + "\" not known");
				return;
			}

			int new_status = ContigTransferRequest.stringToStatus(words[2]);
			
			if (new_status == ContigTransferRequest.UNKNOWN) {
				System.out.println("Status \"" + words[2] + "\" not known");
				return;
			}
			
			ctrm.reviewContigTransferRequest(request_id, reviewer, new_status);
			
			request = ctrm.findContigTransferRequest(request_id);
			
			System.out.println("After review: \n" + prettyPrint(request));
		}
		catch (ContigTransferRequestException ctre) {
			reportContigTransferRequestException(ctre);
		}
		catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	protected String prettyPrint(ContigTransferRequest request) {
		StringBuffer sb = new StringBuffer(80);
		
		Person contigOwner = request.getContigOwner();
		String ownerName = contigOwner == null ? "nobody" : contigOwner.getName();
		
		sb.append("ContigTransferRequest\n");
		sb.append("\tID = " + request.getRequestID() + "\n");
		sb.append("\tContig = " + request.getContig().getID() +
				", owner " + ownerName +
				", in project " + request.getContig().getProject().getName() +
				"\n");
		
		sb.append("\tRequester = " + request.getRequester().getName() + "\n");
		
		sb.append("\tOpened on " + request.getOpenedDate() + "\n");
		
		String reqcomment = request.getRequesterComment();
		if (reqcomment != null)
			sb.append("\tRequester comment = " + reqcomment + "\n");
		
		Project fromProject = request.getOldProject();
		Project toProject = request.getNewProject();
		
		sb.append("\t" + fromProject.getName() + " --> " + toProject.getName() + "\n");
		
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
	
	protected void reportContigTransferRequestException(ContigTransferRequestException ctre) {
		System.err.println("ContigTransferRequestException : " + ctre.getTypeAsString());
		ctre.printStackTrace();
	}
}
