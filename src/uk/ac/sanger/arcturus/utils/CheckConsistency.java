package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.OrganismChooserPanel;

import java.sql.*;
import java.io.*;
import java.text.MessageFormat;

import javax.swing.JOptionPane;

public class CheckConsistency {
	protected CheckConsistencyListener listener = null;
	
	protected String[][] tests = {
			{
					"Do all contigs have the correct number of mappings?",

					"select C.contig_id,nreads,count(*) as mapping_count"
							+ " from CONTIG C, MAPPING M where C.contig_id=M.contig_id"
							+ " group by contig_id having nreads != mapping_count",

					"Contig {0,number,#} has nreads={1,number,#} but {2,number,#} mappings"
			},
					
			{
					"Are there any orphan contigs?",
					
					"select contig_id,C.created,length,name" + 
					" from CONTIG C left join PROJECT P using(project_id)" +
					" where C.nreads = 0",
					
					"Contig {0,number,#} created at {1,time} on {1,date}, length {2,number,#}bp, in project {3}, has nreads=0"						
			},

			{
					"Do all mappings correspond to contigs?",
					
					"select mapping_id,seq_id,MAPPING.contig_id"
							+ " from MAPPING left join CONTIG using(contig_id)"
							+ " where CONTIG.contig_id is null",
							
					"Mapping {0,number,#} for sequence {1,number,#} refers to non-existent contig {2,number,#}"
			},

			{
					"Do all contig-to-sequence mappings have valid sequence data?",

					"select contig_id,mapping_id,MAPPING.seq_id"
							+ " from MAPPING left join SEQUENCE using(seq_id)"
							+ " where sequence is null or quality is null",

					"Mapping {1,number,#} in contig {0,number,#} has undefined sequence {2,number,#}"
			},
			
			{
					"Do all mappings have a corresponding read?",

					"select contig_id,mapping_id,MAPPING.seq_id"
							+ " from MAPPING left join (SEQ2READ,READINFO)"
							+ " on (MAPPING.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id)"
							+ " where readname is null",

					"Mapping {1,number,#} in contig {0,number,#} has sequence {2,number,#}"
							+ " with undefined read"
			},
			
			{
					"Do all sequences have quality clipping data?",

					"select SEQUENCE.seq_id from SEQUENCE left join QUALITYCLIP"
							+ " using(seq_id) where QUALITYCLIP.seq_id is null",

					"Sequence {0,number,#} has no quality clipping data"
			},
			
			{
					"Do all sequences have a corresponding sequence-to-read mapping?",

					"select SEQUENCE.seq_id from SEQUENCE left join SEQ2READ"
							+ " using (seq_id)"
							+ " where SEQ2READ.seq_id is null",

					"Sequence {0,number,#} has no associated sequence-to-read mapping"
			},
			
			{
					"Do all sequences with a sequence-to-read mapping have a valid read?",

					"select SEQUENCE.seq_id,SEQ2READ.read_id from SEQUENCE left join (SEQ2READ,READINFO)"
							+ " on (SEQUENCE.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id)"
							+ " where readname is null and SEQ2READ.read_id is not null",

					"Sequence {0,number,#} has no associated read (read_id is {1,number,#})"
			},
			
			{
					"Do all reads have valid sequence data?",

					"select READINFO.read_id,readname from READINFO left join (SEQ2READ,SEQUENCE)"
							+ " on (READINFO.read_id = SEQ2READ.read_id and SEQ2READ.seq_id = SEQUENCE.seq_id)"
							+ " where sequence is null or quality is null",

					"Read {0,number,#} ({1}) has no associated sequence"
			},
			
			{
					"Do all reads have a template?",

					"select read_id,readname from READINFO left join TEMPLATE"
							+ " using (template_id) where name is null",

					"Read {0,number,#} ({1}) has no associated template"
			},
			
			{
					"Do all templates have a ligation?",

					"select template_id,TEMPLATE.name from TEMPLATE left join LIGATION using (ligation_id)"
							+ " where LIGATION.name is null",

					"Template {0,number,#} ({1}) has no associated ligation"
			},
			
			{
					"Do all ligations have a clone?",

					"select ligation_id,LIGATION.name from LIGATION left join CLONE using(clone_id)"
							+ " where CLONE.name is null",

					"Ligation {0,number,#} ({1}) has no associated clone"
			}

	};

	public void checkConsistency(ArcturusDatabase adb, CheckConsistencyListener listener)
		throws SQLException {
		this.listener = listener;
		Connection conn = adb.getPooledConnection(this);
		checkConsistency(conn);
		conn.close();
		this.listener = null;
	}

	protected void checkConsistency(Connection conn) throws SQLException {
		Statement stmt = conn.createStatement();

		for (int i = 0; i < tests.length; i++) {
			notifyListener(tests[i][0]);
			notifyListener("");

			MessageFormat format = new MessageFormat(tests[i][2]);

			int rows = doQuery(stmt, tests[i][1], format);

			String message;

			switch (rows) {
				case 0:
					message = "PASSED";
					break;

				case 1:
					message = "\n*** FAILED : 1 inconsistency ***";
					break;

				default:
					message = "\n*** FAILED : " + rows + " inconsistencies ***";
					break;
			}

			notifyListener(message);
			notifyListener("");
			notifyListener("--------------------------------------------------------------------------------");
		}
	}

	protected int doQuery(Statement stmt, String query, MessageFormat format)
			throws SQLException {
		ResultSet rs = stmt.executeQuery(query);

		ResultSetMetaData rsmd = rs.getMetaData();

		int rows = 0;
		int cols = rsmd.getColumnCount();

		Object[] args = format != null ? new Object[cols] : null;

		while (rs.next()) {
			for (int col = 1; col <= cols; col++)
				args[col - 1] = rs.getObject(col);

			notifyListener(format.format(args));

			rows++;
		}

		return rows;
	}

	protected void notifyListener(String message) {
		if (listener != null)
			listener.report(message);
	}
	
	public interface CheckConsistencyListener {
		public void report(String message);
	}

	public static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
	}

	public static void main(String args[]) {
		String instance = null;
		String organism = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
		}

		if (instance == null || organism == null) {
			OrganismChooserPanel orgpanel = new OrganismChooserPanel();

			int result = orgpanel.showDialog(null);

			if (result == JOptionPane.OK_OPTION) {
				instance = orgpanel.getInstance();
				organism = orgpanel.getOrganism();
			}
		}

		if (instance == null || instance.length() == 0 || organism == null
				|| organism.length() == 0) {
			printUsage(System.err);
			System.exit(1);
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			CheckConsistency cc = new CheckConsistency();

			CheckConsistencyListener listener = new CheckConsistencyListener() {
				public void report(String message) {
					System.out.println(message);
				}
				
			};
			
			cc.checkConsistency(adb, listener);

			System.exit(0);
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}
}
