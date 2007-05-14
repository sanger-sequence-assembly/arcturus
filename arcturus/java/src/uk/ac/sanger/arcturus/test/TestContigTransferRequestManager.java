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

			ctrm.setDebugging(true);
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
		String verb = words[0];
		
		if (verb.equalsIgnoreCase("list")) {
			if (words.length > 1) {
				for (int i = 1; i < words.length; i++)	
					listRequests(words[i], false);
			} else
				System.err.println("list: expects one or more user names");
			
			return;
		}
		
		if (verb.equalsIgnoreCase("listall")) {
			if (words.length > 1) {
				for (int i = 1; i < words.length; i++)	
					listRequests(words[i], true);
			} else
				System.err.println("listall: expects one or more user names");
			
			return;
		}
		
		if (verb.equalsIgnoreCase("create")) {
			if (words.length == 4) {
				createRequest(words[1], words[2], words[3]);
			} else
				System.err.println("create: expects contig_id to-project user");
			
			return;
		}
		
		if (verb.equalsIgnoreCase("cancel")) {
			if (words.length == 3) {
				cancelRequest(words[1], words[2]);
			} else
				System.err.println("cancel: expects request_id user");
			
			return;
		}
		
		if (verb.equalsIgnoreCase("approve")) {
			if (words.length == 3) {
				approveRequest(words[1], words[2]);
			} else
				System.err.println("approve: expects request_id user");
			
			return;
		}
		
		if (verb.equalsIgnoreCase("refuse")) {
			if (words.length == 3) {
				refuseRequest(words[1], words[2]);
			} else
				System.err.println("refuse: expects request_id user");

			return;
		}
		
		if (verb.equalsIgnoreCase("execute")) {
			if (words.length == 3) {
				executeRequest(words[1], words[2]);
			} else
				System.err.println("execute: expects request_id user");

			return;
		}
		
		System.out.println("*** Unknown command verb \"" + verb
				+ "\" ***");
	}

	protected void listRequests(String username, boolean showall) {
		Person user = PeopleManager.findPerson(username);

		if (user == null) {
			System.out.println("User \"" + username + "\" not known");
			return;
		}

		System.out.println("\n>>> Requests for user " + username + " <<<\n");
		
		try {
			ContigTransferRequest[] requests = ctrm
					.getContigTransferRequestsByUser(user,
							ArcturusDatabase.USER_IS_REQUESTER);

			int j = 0;
			
			for (int i = 0; i < requests.length; i++) {
				boolean closed = requests[i].isClosed();
				
				if (showall || !closed) {
					j++;
					System.out.println("Request #" + j + " : \n" + ctrm.prettyPrint(requests[i]));
				}
			}
		} catch (SQLException e) {
			e.printStackTrace();
		}
	}

	protected void createRequest(String strContigId, String projectname, String username) {
		try {
			int contig_id = Integer.parseInt(strContigId);

			Project toProject = adb.getProjectByName(null, projectname);
			
			if (toProject == null) {
				System.out.println("Project \"" + projectname + "\" not known");
				return;
			}
			
			int to_project_id = toProject.getID();

			Person requester = PeopleManager.findPerson(username);

			if (requester == null) {
				System.out.println("User \"" + username + "\" not known");
				return;
			}

			ContigTransferRequest request = ctrm.createContigTransferRequest(
					requester, contig_id, to_project_id);
			
			System.out.println("Created new request: \n" + ctrm.prettyPrint(request));
		} catch (ContigTransferRequestException ctre) {
			reportContigTransferRequestException(ctre);
		}
		catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	protected void cancelRequest(String strRequestId, String username) {
		reviewRequest(strRequestId, username, ContigTransferRequest.CANCELLED);
	}
	
	protected void approveRequest(String strRequestId, String username) {
		reviewRequest(strRequestId, username, ContigTransferRequest.APPROVED);
	}
	
	protected void refuseRequest(String strRequestId, String username) {
		reviewRequest(strRequestId, username, ContigTransferRequest.REFUSED);
	}
	
	protected void executeRequest(String strRequestId, String username) {
		try {
			int request_id = Integer.parseInt(strRequestId);
			
			ContigTransferRequest request = ctrm.findContigTransferRequest(request_id);
			
			if (request == null) {
				System.out.println("Request #" + request_id + " not found");
				return;
			}
			
			System.out.println("Before review: \n" + ctrm.prettyPrint(request));
			
			Person reviewer = PeopleManager.findPerson(username);

			if (reviewer == null) {
				System.out.println("User \"" + username + "\" not known");
				return;
			}
			
			ctrm.executeContigTransferRequest(request, reviewer);
			
			request = ctrm.findContigTransferRequest(request_id);
			
			System.out.println("After review: \n" + ctrm.prettyPrint(request));
		}
		catch (ContigTransferRequestException ctre) {
			reportContigTransferRequestException(ctre);
		}
		catch (Exception e) {
			e.printStackTrace();
		}
	}

	protected void reviewRequest(String strRequestId, String username, int new_status) {
		try {
			int request_id = Integer.parseInt(strRequestId);
			
			ContigTransferRequest request = ctrm.findContigTransferRequest(request_id);
			
			if (request == null) {
				System.out.println("Request #" + request_id + " not found");
				return;
			}
			
			System.out.println("Before review: \n" + ctrm.prettyPrint(request));
			
			Person reviewer = PeopleManager.findPerson(username);

			if (reviewer == null) {
				System.out.println("User \"" + username + "\" not known");
				return;
			}
			
			if (new_status == ContigTransferRequest.UNKNOWN) {
				System.out.println("Status \"" + new_status + "\" not known");
				return;
			}
			
			ctrm.reviewContigTransferRequest(request_id, reviewer, new_status);
			
			request = ctrm.findContigTransferRequest(request_id);
			
			System.out.println("After review: \n" + ctrm.prettyPrint(request));
		}
		catch (ContigTransferRequestException ctre) {
			reportContigTransferRequestException(ctre);
		}
		catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	protected void reportContigTransferRequestException(ContigTransferRequestException ctre) {
		System.out.println("ContigTransferRequestException : " + ctre.getTypeAsString());
	}
}
