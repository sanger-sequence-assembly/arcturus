package uk.ac.sanger.arcturus.test;

import java.io.PrintStream;
import java.util.Collections;
import java.util.NoSuchElementException;
import java.util.Vector;
import java.util.Comparator;

import javax.naming.Binding;
import javax.naming.Context;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.sql.DataSource;
import javax.swing.*;
import javax.swing.event.TreeSelectionEvent;
import javax.swing.event.TreeSelectionListener;
import javax.swing.tree.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Organism;

import com.mysql.jdbc.jdbc2.optional.MysqlDataSource;

public class TestInstanceTree {
	private JTree tree = null;

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

		try {
			tree = createInstanceTree(instances);
		} catch (NamingException e) {
			e.printStackTrace();
			System.exit(1);
		}

		tree.getSelectionModel().setSelectionMode(
				TreeSelectionModel.SINGLE_TREE_SELECTION);

		JScrollPane scrollpane = new JScrollPane(tree);

		final JLabel label = new JLabel();

		tree.addTreeSelectionListener(new TreeSelectionListener() {
			public void valueChanged(TreeSelectionEvent e) {
				DefaultMutableTreeNode node = (DefaultMutableTreeNode) tree
						.getLastSelectedPathComponent();

				if (node == null)
					return;

				String text = node instanceof OrganismNode ? ((OrganismNode) node)
						.getURL()
						: node.toString();

				label.setText(text);
			}
		});

		JSplitPane splitpane = new JSplitPane(JSplitPane.VERTICAL_SPLIT,
				scrollpane, label);

		frame.getContentPane().add(splitpane);

		frame.pack();
		frame.setVisible(true);
	}

	private JTree createInstanceTree(ArcturusInstance[] instances)
			throws NamingException {
		InstanceTreeModel model = new InstanceTreeModel(instances);

		return new JTree(model);
	}

	class InstanceTreeModel extends DefaultTreeModel {
		private MinervaTreeNodeComparator comparator = new MinervaTreeNodeComparator();

		public InstanceTreeModel(ArcturusInstance[] instances)
				throws NamingException {
			super(new DefaultMutableTreeNode("Arcturus", true));

			DefaultMutableTreeNode root = (DefaultMutableTreeNode) getRoot();

			for (int i = 0; i < instances.length; i++)
				addInstance(instances[i], root);
		}

		private void addInstance(ArcturusInstance instance,
				DefaultMutableTreeNode root) throws NamingException {
			DirContext context = instance.getDirContext();

			DefaultMutableTreeNode instanceNode = new InstanceNode(context,
					instance.getName());

			root.add(instanceNode);

			addChildNodes(context, instanceNode);
		}

		private void addChildNodes(DirContext context,
				DefaultMutableTreeNode root) throws NamingException {
			Vector<MinervaTreeNode> children = new Vector<MinervaTreeNode>();

			NamingEnumeration ne = context.listBindings("");

			while (ne != null && ne.hasMore()) {
				Binding bd = (Binding) ne.next();

				String cn = bd.getName();

				String[] cnparts = cn.split("=");

				String name = cnparts[1];

				Object object = bd.getObject();

				if (object instanceof DataSource) {
					String description = getDescription(context, cn);
					Organism organism = new Organism(name, description,
							(DataSource) object);
					children.add(new OrganismNode(organism));
				} else if (object instanceof DirContext) {
					InstanceNode node = new InstanceNode((DirContext) object,
							name);
					children.add(node);

					addChildNodes((DirContext) object, node);
				} else
					Arcturus.logWarning(
							"Expecting a DataSource or Context, got a "
									+ object.getClass().getName(),
							new Exception("Unexpected LDAP entry"));
			}

			Collections.sort(children, comparator);

			for (MinervaTreeNode node : children)
				root.add(node);
		}

		private String getDescription(DirContext context, String name)
				throws NamingException {
			String cn = name;

			String attrnames[] = { "description" };

			Attributes attrs = context.getAttributes(cn, attrnames);

			Attribute description = attrs.get(attrnames[0]);

			if (description == null)
				return null;

			String desc = null;

			try {
				desc = (String) description.get();
			} catch (NoSuchElementException nsee) {
			}

			return desc;
		}
	}

	class MinervaTreeNodeComparator implements Comparator<MinervaTreeNode> {
		public int compare(MinervaTreeNode node1, MinervaTreeNode node2) {
			if (node1 instanceof InstanceNode && node2 instanceof OrganismNode)
				return -1;
			else if (node1 instanceof OrganismNode
					&& node2 instanceof InstanceNode)
				return 1;
			else
				return node1.getName().compareTo(node2.getName());
		}
	}

	class MinervaTreeNode extends DefaultMutableTreeNode {
		private String name;

		public MinervaTreeNode(Object userObject, boolean allowsChildren,
				String name) {
			super(userObject, allowsChildren);
			this.name = name;
		}

		public String getName() {
			return name;
		}

		public String toString() {
			return name;
		}
	}

	class InstanceNode extends MinervaTreeNode {
		public InstanceNode(DirContext context, String name) {
			super(context, true, name);
		}
	}

	class OrganismNode extends MinervaTreeNode {
		private Organism organism;

		public OrganismNode(Organism organism) {
			super(organism, false, organism.getName());
			this.organism = organism;
		}

		public Organism getOrganism() {
			return organism;
		}

		public String toString() {
			return organism.getName() + " (" + organism.getDescription() + ")";
		}

		public String getURL() {
			DataSource ds = organism.getDataSource();

			if (ds instanceof MysqlDataSource)
				return ((MysqlDataSource) ds).getURL();
			else
				return ds.toString();
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
