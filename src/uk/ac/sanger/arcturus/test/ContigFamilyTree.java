package uk.ac.sanger.arcturus.test;

import java.io.PrintStream;
import java.util.Set;
import java.util.HashSet;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

public class ContigFamilyTree {
	private ArcturusDatabase adb;

	public static void main(String args[]) {
		ContigFamilyTree cft = new ContigFamilyTree();

		cft.run(args);

		System.exit(0);
	}

	public void run(String args[]) {
		System.out.println("ContigFamilyTree");
		System.out.println("================");
		System.out.println();

		String instance = null;
		String organism = null;
		int parent_id = 0;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-contig"))
				parent_id = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-help")) {
				showUsage(System.err);
				System.exit(0);
			}
		}

		if (instance == null || organism == null || parent_id < 1) {
			showUsage(System.err);
			System.exit(1);
		}

		try {
			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			adb = ai.findArcturusDatabase(organism);

			Contig parent = adb.getContigByID(parent_id);

			if (parent == null) {
				System.out.println("No contig exists with ID = " + parent_id);
				return;
			}

			System.out.println("Parent contig: " + parent);

			Set<ContigAndLevel> children = getCurrentChildren(parent, 0);

			if (children == null || children.isEmpty()) {
				System.out.println("Contig " + parent_id + " has no children");
			} else {
				System.out.println("CHILDREN:");

				for (ContigAndLevel cal : children) {
					System.out.println("\tContig " + cal.getContig().getID()
							+ " at level " + cal.getLevel());
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	private Set<ContigAndLevel> getCurrentChildren(Contig parent, int level)
			throws SQLException {
		Set<ContigAndLevel> resultSet = new HashSet<ContigAndLevel>();

		Set<Contig> children = adb.getChildContigs(parent);

		if (children == null || children.isEmpty()) {
			if (level > 0)
				resultSet.add(new ContigAndLevel(parent, level));
		} else {
			for (Contig child : children)
				resultSet.addAll(getCurrentChildren(child, level + 1));
		}

		return resultSet;
	}

	class ContigAndLevel {
		private Contig contig;
		private int level;
		private int hash;

		public ContigAndLevel(Contig contig, int level) {
			this.contig = contig;
			this.level = level;

			hash = contig.getID() << 8 + level;
		}

		public Contig getContig() {
			return contig;
		}

		public int getLevel() {
			return level;
		}

		public boolean equals(Object o) {
			if (o instanceof ContigAndLevel) {
				ContigAndLevel that = (ContigAndLevel) o;
				return that != null
						&& that.contig.getID() == this.contig.getID()
						&& that.level == this.level;
			} else
				return false;
		}

		public int hashCode() {
			return hash;
		}
	}

	private void showUsage(PrintStream ps) {
		ps.println("You forgot a parameter, stupid");
	}
}
