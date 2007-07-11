package uk.ac.sanger.arcturus.test;

import java.io.PrintStream;
import java.util.Collections;
import java.util.Vector;

import javax.naming.NamingException;
import javax.swing.*;
import javax.swing.tree.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Organism;
import uk.ac.sanger.arcturus.gui.organismtable.OrganismComparator;

public class TestInstanceTree {
	private OrganismComparator comparator = new OrganismComparator(OrganismComparator.BY_NAME, false);

	public void run(final ArcturusInstance[] instances) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				createUI(instances);
			}
		});
	}

	private void createUI(ArcturusInstance[] instances) {
		JFrame frame = new JFrame("Minerva");
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

		JTree tree = createInstanceTree(instances);

		JScrollPane scrollpane = new JScrollPane(tree);

		frame.getContentPane().add(scrollpane);

		frame.pack();
		frame.setVisible(true);
	}

	private JTree createInstanceTree(ArcturusInstance[] instances) {
		InstanceTreeModel model = new InstanceTreeModel(instances);

		return new JTree(model);
	}

	class InstanceTreeModel extends DefaultTreeModel {
		public InstanceTreeModel(ArcturusInstance[] instances) {
			super(new DefaultMutableTreeNode("Arcturus", true));

			DefaultMutableTreeNode root = (DefaultMutableTreeNode) getRoot();

			for (int i = 0; i < instances.length; i++)
				addInstance(instances[i], root);
		}

		private void addInstance(ArcturusInstance instance,
				DefaultMutableTreeNode root) {
			DefaultMutableTreeNode instanceNode = new DefaultMutableTreeNode(
					new InstanceProxy(instance), true);

			root.add(instanceNode);

			Vector<Organism> organisms = null;

			try {
				organisms = instance.getAllOrganisms();
			} catch (NamingException e) {
				Arcturus.logWarning("Error whilst enumerating organisms for "
						+ instance.getName(), e);
			}

			if (organisms == null)
				return;

			Collections.sort(organisms, comparator);

			for (Organism organism : organisms)
				instanceNode.add(new DefaultMutableTreeNode(new OrganismProxy(
						organism), false));
		}
	}

	class InstanceProxy {
		private ArcturusInstance instance;

		public InstanceProxy(ArcturusInstance instance) {
			this.instance = instance;
		}

		public ArcturusInstance getInstance() {
			return instance;
		}

		public String toString() {
			return instance.getName();
		}
	}

	class OrganismProxy {
		private Organism organism;

		public OrganismProxy(Organism organism) {
			this.organism = organism;
		}

		public Organism getOrganism() {
			return organism;
		}

		public String toString() {
			return organism.getName() + " (" + organism.getDescription() + ")";
		}
	}

	public static void main(final String[] args) {
		String instances = null;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instances"))
				instances = args[++i];
		}

		if (instances == null) {
			showUsage(System.err);
			System.exit(1);
		}

		String inames[] = instances.split(",");

		ArcturusInstance ai[] = new ArcturusInstance[inames.length];

		boolean failed = false;

		for (int i = 0; i < inames.length; i++) {
			System.out.println(inames[i]);
			try {
				ai[i] = ArcturusInstance.getInstance(inames[i]);
			} catch (NamingException e) {
				failed = true;
				System.err.println("Failed to find instance " + inames[i]);
				e.printStackTrace();
			}
		}

		if (failed)
			System.exit(2);

		TestInstanceTree tit = new TestInstanceTree();
		tit.run(ai);
	}

	private static void showUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps
				.println("\t-instances\tA comma-separated list of instances to display");
	}
}
