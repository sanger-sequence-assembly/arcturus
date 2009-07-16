package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.people.*;
import uk.ac.sanger.arcturus.people.role.Role;

import java.sql.*;
import java.io.*;

public class TestUserManager {
	private String instance;
	private String organism;
	private String username;
	private ArcturusDatabase adb;
	
	public static void main(String args[]) {
		TestUserManager tum = new TestUserManager();
		tum.execute(args);
	}

	public void execute(String args[]) {
		System.err.println("TestUserManager");
		System.err.println("===============");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-username"))
				username = args[++i];
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			adb = ai.findArcturusDatabase(organism);
			
			Person me = PeopleManager.createPerson(PeopleManager.getEffectiveUID());
			
			describeUser(me);

			if (username != null) {
				System.out.println("\n\n");
				
				Person person = PeopleManager.createPerson(username);
			
				describeUser(person);
			}			
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
	
	private void describeUser(Person person) throws SQLException {
		if (person == null)
			return;
		
		System.out.println(person);
		
		Role role = person.getRole();
		
		System.out.println("Role: " + role);
	}
	
	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-username\tName of user");
	}
}
