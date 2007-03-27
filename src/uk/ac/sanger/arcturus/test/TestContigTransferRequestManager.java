package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.contigtransfer.*;
import uk.ac.sanger.arcturus.people.*;

import java.io.*;
import java.sql.*;

public class TestContigTransferRequestManager {
	private String instance = null;
	private String organism = null;
	private String username = null;

	private ArcturusDatabase adb = null;

	public static void main(String[] args) {
		TestContigTransferRequestManager tctrm = new TestContigTransferRequestManager();
		tctrm.execute(args);
	}

	public void execute(String args[]) {
		System.err.println("TestContigTransferRequestManager");
		System.err.println("================================");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-username"))
				username = args[++i];
		}

		if (instance == null || organism == null || username == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();
			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			adb = ai.findArcturusDatabase(organism);

			Person user = PeopleManager.findPerson(username);

			int mode = ArcturusDatabase.USER_IS_REQUESTER;

			ContigTransferRequest[] requests = adb
					.getContigTransferRequestsByUser(user, mode);

			System.out.println("Mode: USER_IS_REQUESTER");

			if (requests.length == 0)
				System.out.println("[No requests]");
			else
				for (int i = 0; i < requests.length; i++)
					System.out.println(requests[i]);

			mode = ArcturusDatabase.USER_IS_CONTIG_OWNER;

			requests = adb.getContigTransferRequestsByUser(user, mode);

			System.out.println();

			System.out.println("Mode: USER_IS_CONTIG_OWNER");

			if (requests.length == 0)
				System.out.println("[No requests]");
			else
				for (int i = 0; i < requests.length; i++)
					System.out.println(requests[i]);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-username\tUsername of person making the request");
	}

}
