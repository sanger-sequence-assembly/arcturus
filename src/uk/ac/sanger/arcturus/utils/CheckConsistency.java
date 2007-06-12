package uk.ac.sanger.arcturus.utils;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.io.*;

import javax.swing.*;
import java.awt.*;

public class CheckConsistency {
	protected String[][] queries = {
			{
					"Do all contigs have the correct number of mappings?",

					"select contig_id,nreads,count(*) as mapping_count"
							+ " from CONTIG left join MAPPING using(contig_id)"
							+ " group by contig_id having nreads != mapping_count" },
			{
					"Do all contig-to-sequence mappings have valid sequence data?",

					"select CONTIG.contig_id,MAPPING.mapping_id from CONTIG left join (MAPPING,SEQUENCE)"
							+ " on (CONTIG.contig_id = MAPPING.contig_id and MAPPING.seq_id = SEQUENCE.seq_id)"
							+ " where sequence is null or quality is null;" },
			{
					"Do all mappings have a corresponding read_id?",

					"select mapping_id from MAPPING left join SEQ2READ using(seq_id) where read_id is null" },
			{
					"Do all sequences have quality clipping data?",

					"select SEQUENCE.seq_id from SEQUENCE left join QUALITYCLIP"
							+ " using(seq_id) where QUALITYCLIP.seq_id is null" },
			{
					"Do all sequences have a corresponding read?",

					"select SEQUENCE.seq_id from SEQUENCE left join (SEQ2READ,READINFO)"
							+ " on (SEQUENCE.seq_id = SEQ2READ.seq_id and SEQ2READ.read_id = READINFO.read_id)"
							+ " where readname is null" },
			{
					"Do all reads have valid sequence data?",

					"select READINFO.read_id,readname from READINFO left join (SEQ2READ,SEQUENCE)"
							+ " on (READINFO.read_id = SEQ2READ.read_id and SEQ2READ.seq_id = SEQUENCE.seq_id)"
							+ " where sequence is null or quality is null" },
			{
					"Do all reads have a template?",

					"select read_id,readname from READINFO left join TEMPLATE"
							+ " using (template_id) where name is null" },
			{
					"Do all templates have a ligation?",

					"select template_id,TEMPLATE.name from TEMPLATE left join LIGATION using (ligation_id)"
							+ " where LIGATION.name is null" },
			{
					"Do all ligations have a clone?",

					"select ligation_id,LIGATION.name from LIGATION left join CLONE using(clone_id)"
							+ " where CLONE.name is null" }

	};

	public void execute(String[] args) {
		String instance = null;
		String organism = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
		}

		if (instance == null || organism == null) {
			OrganismPanel orgpanel = new OrganismPanel();

			int result = JOptionPane.showConfirmDialog(null, orgpanel,
					"Specify instance and organism",
					JOptionPane.OK_CANCEL_OPTION, JOptionPane.QUESTION_MESSAGE);

			if (result == JOptionPane.OK_OPTION) {
				instance = orgpanel.getInstance();
				organism = orgpanel.getOrganism();
			}
		}

		if (instance == null || instance.length() == 0 || organism == null || organism.length() == 0) {
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

			checkConsistency(adb);
		} catch (Exception e) {
			Arcturus.logSevere(e);
			System.exit(1);
		}
	}

	protected void checkConsistency(ArcturusDatabase adb) throws SQLException {
		Connection conn = adb.getPooledConnection(this);
		checkConsistency(conn);
	}

	protected void checkConsistency(Connection conn) throws SQLException {
		Statement stmt = conn.createStatement();

		for (int i = 0; i < queries.length; i++) {
			System.out.println(queries[i][0]);
			boolean ok = doQuery(stmt, queries[i][1]);
			System.out.println(ok ? "PASSED" : "*** FAILED ***");
		}
	}

	protected boolean doQuery(Statement stmt, String query) throws SQLException {
		ResultSet rs = stmt.executeQuery(query);

		ResultSetMetaData rsmd = rs.getMetaData();

		int rows = 0;
		int cols = rsmd.getColumnCount();

		while (rs.next()) {
			if (rows == 0) {
				for (int col = 1; col <= cols; col++) {
					if (col > 1)
						System.out.print("\t");
					System.out.print(rsmd.getColumnLabel(col));
				}

				System.out.println();
			}

			rows++;

			for (int col = 1; col <= cols; col++) {
				String value = rs.getString(col);
				if (col > 1)
					System.out.print("\t");
				System.out.print(value);
			}

			System.out.println();
		}

		return rows == 0;
	}

	class OrganismPanel extends JPanel {
		protected JTextField instance = null;
		protected JTextField organism = null;

		public OrganismPanel() {
			super(new GridBagLayout());
			GridBagConstraints c = new GridBagConstraints();

			c.insets = new Insets(2, 2, 2, 2);

			c.anchor = GridBagConstraints.WEST;
			c.gridwidth = GridBagConstraints.REMAINDER;
			c.weightx = 0.0;

			add(new JLabel("Please specify the instance and organism"), c);

			c.gridwidth = 1;
			c.anchor = GridBagConstraints.EAST;
			c.fill = GridBagConstraints.NONE;
			c.weightx = 0.0;
			add(new JLabel("Username:"), c);

			c.anchor = GridBagConstraints.EAST;
			c.fill = GridBagConstraints.HORIZONTAL;
			c.gridwidth = GridBagConstraints.REMAINDER;
			c.weightx = 1.0;
			instance = new JTextField("pathogen", 20);
			add(instance, c);

			c.gridwidth = 1;
			c.fill = GridBagConstraints.NONE;
			c.anchor = GridBagConstraints.EAST;
			c.weightx = 0.0;

			add(new JLabel("Organism:"), c);

			c.anchor = GridBagConstraints.EAST;
			c.fill = GridBagConstraints.HORIZONTAL;
			c.gridwidth = GridBagConstraints.REMAINDER;
			c.weightx = 1.0;
			organism = new JTextField("", 20);
			add(organism, c);
		}

		public String getInstance() {
			return instance.getText();
		}

		public String getOrganism() {
			return organism.getText();
		}
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
	}

	public static void main(String args[]) {
		CheckConsistency cc = new CheckConsistency();
		cc.execute(args);
		System.exit(0);
	}
}
