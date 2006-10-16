package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.*;

import java.util.logging.*;

import java.util.*;
import java.io.*;
import java.sql.SQLException;

import javax.naming.Context;

public class TestProjectManager {
	private long lasttime;
	private Comparator byname = new ByName();

	public static void main(String args[]) {
		TestProjectManager tpm = new TestProjectManager();

		tpm.run(args);
	}

	public void run(String args[]) {
		lasttime = System.currentTimeMillis();

		System.err.println("Creating a logger ...");
		Logger logger = Logger.getLogger(TestProjectManager.class.getName());
		logger.setLevel(Level.INFO);
		System.err
				.println("Logger is class=" + logger.getClass().getName()
						+ ", name=" + logger.getName() + ", level="
						+ logger.getLevel());

		System.out.println("TestProjectManager");
		System.out.println("==================");
		System.out.println();

		String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

		Properties props = new Properties();

		Properties env = System.getProperties();

		props.put(Context.INITIAL_CONTEXT_FACTORY, env
				.get(Context.INITIAL_CONTEXT_FACTORY));
		props.put(Context.PROVIDER_URL, ldapURL);

		String instance = null;
		String organism = null;
		boolean testmove = false;
		boolean enumeratecontigs = false;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-testmove"))
				testmove = true;

			if (args[i].equalsIgnoreCase("-contigs"))
				enumeratecontigs = true;
		}

		if (instance == null || organism == null) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();

			ArcturusInstance ai = new ArcturusInstance(props, instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			adb.setLogger(logger);

			report();

			adb.preloadAllAssemblies();
			adb.preloadAllProjects();

			displayAssemblies(adb, enumeratecontigs);

			if (testmove) {
				Set assemblies = adb.getAllAssemblies();

				Assembly[] assemblyArray = (Assembly[]) assemblies
						.toArray(new Assembly[0]);

				Arrays.sort(assemblyArray, byname);

				Set projects1 = assemblyArray[0].getProjects();

				Project[] project1Array = (Project[]) projects1
						.toArray(new Project[0]);

				for (int i = 0; i < project1Array.length; i++) {
					try {
						project1Array[i].setAssembly(assemblyArray[1], true);
					} catch (java.sql.SQLException sqle) {
						if (sqle.getErrorCode() == MySQLErrorCode.ER_DUP_ENTRY)
							System.err
									.println("Duplicate key violation when moving project "
											+ project1Array[i].getName()
											+ " (ID="
											+ project1Array[i].getID()
											+ ") to assembly "
											+ assemblyArray[1].getName());
						else
							System.err.println("SQLException(\""
									+ sqle.getMessage() + ", ErrorCode="
									+ sqle.getErrorCode() + ")");
					}
				}

				displayAssemblies(adb, false);

				Set projects2 = assemblyArray[1].getProjects();

				Project[] project2Array = (Project[]) projects2
						.toArray(new Project[0]);

				for (int i = 0; i < project2Array.length; i++) {
					try {
						project2Array[i].setAssembly(assemblyArray[0], true);
					} catch (java.sql.SQLException sqle) {
						if (sqle.getErrorCode() == MySQLErrorCode.ER_DUP_ENTRY)
							System.err
									.println("Duplicate key violation when moving project "
											+ project2Array[i].getName()
											+ " (ID="
											+ project2Array[i].getID()
											+ ") to assembly "
											+ assemblyArray[0].getName());
						else
							System.err.println("SQLException(\""
									+ sqle.getMessage() + ", ErrorCode="
									+ sqle.getErrorCode() + ")");
					}
				}

				displayAssemblies(adb, false);
			}

			report();
		} catch (java.sql.SQLException sqle) {
			System.err.println("SQLException(\"" + sqle.getMessage()
					+ "\", SQLState=" + sqle.getSQLState() + ", ErrorCode="
					+ sqle.getErrorCode() + ")");
			sqle.printStackTrace();
			System.exit(1);
		} catch (javax.naming.NamingException ne) {
			ne.printStackTrace();
			System.exit(1);
		}
	}

	public void displayAssemblies(ArcturusDatabase adb, boolean enumeratecontigs) {
		Set assemblies = adb.getAllAssemblies();

		Assembly[] assemblyArray = (Assembly[]) assemblies
				.toArray(new Assembly[0]);

		Arrays.sort(assemblyArray, byname);

		for (int i = 0; i < assemblyArray.length; i++) {
			Assembly assembly = assemblyArray[i];

			System.out.println("ASSEMBLY: name=" + assembly.getName()
					+ ", updated=" + assembly.getUpdated());

			Set projects = assembly.getProjects();

			Project[] projectArray = (Project[]) projects
					.toArray(new Project[0]);

			Arrays.sort(projectArray, byname);

			for (int j = 0; j < projectArray.length; j++) {
				Project project = projectArray[j];
				Assembly projasm = project.getAssembly();

				Set contigs = null;

				if (enumeratecontigs) {
					try {
						contigs = project.getContigs(true);
					} catch (SQLException sqle) {
						sqle.printStackTrace();
					}
				}

				System.out.println("\tPROJECT: name="
						+ project.getName()
						+ ", updated="
						+ project.getUpdated()
						+ ((enumeratecontigs && contigs != null) ? ", "
								+ contigs.size() + " contigs" : "")
						+ ", assembly="
						+ (projasm == null ? "(NULL)" : projasm.getName()));

				int[] minlens = { 0, 1, 2, 5, 10, 20, 50, 100 };

				for (int k = 0; k < minlens.length; k++) {
					int minlen = 1000 * minlens[k];

					ProjectSummary summary = null;

					try {
						summary = project.getProjectSummary(minlen);
					} catch (SQLException sqle) {
						sqle.printStackTrace();
					}

					if (summary != null) {
						System.out.println();
						System.out.println("\tSUMMARY for contigs of "
								+ minlens[k] + "kb or longer");
						System.out.println("\t\tNumber of Contigs:        "
								+ summary.getNumberOfContigs());
						System.out.println("\t\tNumber of Reads:          "
								+ summary.getNumberOfReads());
						System.out.println("\t\tTotal Consensus Length:   "
								+ summary.getTotalConsensusLength());
						System.out.println("\t\tMean Consensus Length:    "
								+ summary.getMeanConsensusLength());
						System.out.println("\t\tSigma Consensus Length:   "
								+ summary.getSigmaConsensusLength());
						System.out.println("\t\tMaximum Consensus Length: "
								+ summary.getMaximumConsensusLength());
					}
				}
				System.out.println();
			}

			System.out.println();
		}
	}

	public void report() {
		long timenow = System.currentTimeMillis();

		System.out.println("******************** REPORT ********************");
		System.out.println("Time: " + (timenow - lasttime));

		lasttime = timenow;

		Runtime runtime = Runtime.getRuntime();

		System.out.println("Memory (kb): (free/total) " + runtime.freeMemory()
				/ 1024 + "/" + runtime.totalMemory() / 1024);
		System.out.println("************************************************");
		System.out.println();
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		// ps.println();
		// ps.println("OPTIONAL PARAMETERS:");
		ps.println();
		ps.println("JAVA OPTIONS:");
		ps
				.println("\tverbose\t\tProduce verbose output (boolean, default false)");
	}

	class ByName implements Comparator {
		public int compare(Object o1, Object o2) throws ClassCastException {
			if (o1 instanceof Core && o2 instanceof Core) {
				String name1 = ((Core) o1).getName();
				String name2 = ((Core) o2).getName();

				return name1.compareToIgnoreCase(name2);
			} else
				throw new ClassCastException();
		}

		public boolean equals(Object obj) {
			return (obj instanceof ByName && this == obj);
		}
	}
}
