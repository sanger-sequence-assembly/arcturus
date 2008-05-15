package uk.ac.sanger.arcturus.snpdetection;

import java.io.PrintStream;
import java.sql.*;
import java.util.List;
import java.util.Vector;
import java.util.zip.DataFormatException;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Contig;

public class SNPDetectorDemo implements SNPProcessor {
	private ArcturusDatabase adb;
	private ReadGroup[] readGroups;
	private SNPDetector detector;

	private int flags = ArcturusDatabase.CONTIG_TO_CALCULATE_CONSENSUS
			| ArcturusDatabase.CONTIG_SEQUENCE_AUXILIARY_DATA;

	private Connection conn = null;

	public SNPDetectorDemo(String[] args) throws NamingException, SQLException {
		String instance = null;
		String organism = null;

		List<String> groupNames = new Vector<String>();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-group"))
				groupNames.add(args[++i]);
		}

		if (instance == null || organism == null || groupNames.isEmpty()) {
			printUsage(System.err);
			System.exit(1);
		}

		System.err.println("Creating an ArcturusInstance for " + instance);
		System.err.println();

		ArcturusInstance ai = null;

		ai = ArcturusInstance.getInstance(instance);

		System.err.println("Creating an ArcturusDatabase for " + organism);
		System.err.println();

		adb = ai.findArcturusDatabase(organism);

		adb.getSequenceManager().setCacheing(false);

		conn = adb.getConnection();

		if (conn == null) {
			System.err.println("Connection is undefined");
			printUsage(System.err);
			System.exit(1);
		}

		readGroups = new ReadGroup[groupNames.size()];

		for (int i = 0; i < groupNames.size(); i++)
			readGroups[i] = ReadGroup.createReadGroup(adb, groupNames.get(i));

		detector = new SNPDetector(readGroups);
	}

	private void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("REPEATED PARAMETERS");
		ps.println("\t-group\t\t{readname|ligation|clone}=name read grouping specification");
	}

	public void run() throws SQLException, DataFormatException {
		Statement stmt = conn.createStatement();

		String query = "select contig_id from CURRENTCONTIGS";

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int contig_id = rs.getInt(1);

			System.err.print("Fetching contig " + contig_id + " ...");

			Contig contig = adb.getContigByID(contig_id, flags);

			System.err.println(" DONE");

			try {
				detector.processContig(contig, this);
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

		rs.close();

		stmt.close();
	}

	private static final String TAB = "\t";

	public void processSNP(Contig contig, int contig_position,
			char defaultBase, int defaultScore, int defaultReads, Base base) {
		System.out.println(contig_position + TAB + defaultBase + " (Q="
				+ defaultScore + ", N=" + defaultReads + ")" + TAB
				+ base.read.getName() + TAB + base.read_position + TAB
				+ base.base + TAB + base.quality + TAB + base.readGroup.getName());
	}

	public static void main(String[] args) {
		try {
			SNPDetectorDemo demo = new SNPDetectorDemo(args);
			demo.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
		System.exit(0);
	}
}
