package uk.ac.sanger.arcturus.utils;

import java.io.*;
import java.sql.SQLException;
import java.util.zip.DataFormatException;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ContigProcessor;
import uk.ac.sanger.arcturus.database.ProjectLockException;

public class ProjectExporter {
	public static void main(String[] args) {
		ProjectExporter exporter = new ProjectExporter();

		try {
			exporter.run(args);
		} catch (Exception e) {
			Arcturus.logSevere(e);
		} finally {
			System.exit(0);
		}
	}

	public void run(String[] args) throws NamingException, SQLException,
			IOException, DataFormatException {
		String instanceName = null;
		String organismName = null;
		String cafFileName = null;
		String projectList = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instanceName = args[++i];
			else if (args[i].equalsIgnoreCase("-organism"))
				organismName = args[++i];
			else if (args[i].equalsIgnoreCase("-caf"))
				cafFileName = args[++i];
			else if (args[i].equalsIgnoreCase("-projects"))
				projectList = args[++i];
			else if (args[i].equalsIgnoreCase("-help")) {
				printUsage(null, System.err);
				return;
			} else {
				System.err.println("Unknown option: \"" + args[i] + "\"");
				return;
			}
		}

		if (instanceName == null || organismName == null || cafFileName == null
				|| projectList == null) {
			printUsage("One or more mandatory parameters were missing",
					System.err);
			System.exit(1);
		}

		ArcturusInstance ai = ArcturusInstance.getInstance(instanceName);
		ArcturusDatabase adb = ai.findArcturusDatabase(organismName);

		File file = new File(cafFileName);

		PrintWriter pw = new PrintWriter(new BufferedWriter(
				new FileWriter(file)));

		String[] projects = projectList.split(",");

		Processor processor = new Processor(adb, pw);

		for (int i = 0; i < projects.length; i++) {
			Project project = adb.getProjectByName(null, projects[i]);

			if (project == null) {
				System.err.println("Project \"" + projects[i]
						+ "\" does not exist.");
			} else {
				exportProject(project, processor);
			}
		}
	}

	class Processor extends ContigCAFWriter implements ContigProcessor {
		private PrintWriter mypw;

		public Processor(ArcturusDatabase adb, PrintWriter pw)
				throws SQLException {
			super(adb);
			this.mypw = pw;
		}

		public boolean processContig(Contig contig) {
			System.err.println("Contig " + contig.getID() + " ("
					+ contig.getLength() + " bp, " + contig.getReadCount()
					+ " reads)");
			
			int rc;

			try {
				rc = writeContigAsCAF(contig, mypw);
			} catch (Exception e) {
				Arcturus.logSevere(e);
				return false;
			}

			return rc == OK;
		}
	}

	private void exportProject(Project project, Processor processor)
			throws SQLException, DataFormatException {

		ArcturusDatabase adb = project.getArcturusDatabase();

		try {
			adb.lockProjectForExport(project);
		} catch (ProjectLockException ple) {
			System.err.println("Could not lock project \"" + project.getName()
					+ "\": " + ple.getMessage());
			return;
		}

		System.err.println("Exporting project " + project.getName());

		adb.processContigsByProject(project.getID(),
				ArcturusDatabase.CONTIG_BASIC_DATA, processor);

		try {
			adb.unlockProjectForExport(project);
		} catch (ProjectLockException ple) {
			System.err.println("Could not unlock project \""
					+ project.getName() + "\": " + ple.getMessage());
		}
	}

	private void printUsage(String message, PrintStream ps) {
		if (message != null) {
			ps.println(message);
			ps.println();
		}

		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tThe name of the Arcturus instance");
		ps.println("\t-organism\tThe name of the organism");
		ps.println("\t-projects\tA comma-separated list of projects to export");
		ps.println("\t-caf\t\tThe name of the CAF file to write");
	}
}
