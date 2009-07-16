package uk.ac.sanger.arcturus.gui.organismtree;

import java.util.Collections;
import java.util.NoSuchElementException;
import java.util.Vector;

import javax.naming.Binding;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.sql.DataSource;
import javax.swing.tree.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Organism;

public class OrganismTreeModel extends DefaultTreeModel {
	private OrganismTreeNodeComparator comparator = new OrganismTreeNodeComparator();

	public OrganismTreeModel(ArcturusInstance[] instances)
			throws NamingException {
		super(null);
		
		if (instances == null)
			return;

		DefaultMutableTreeNode root = null;
		
		if (instances.length == 1) {
			root = createInstanceNode(instances[0]);
		} else {
			root = new DefaultMutableTreeNode("Arcturus", true);

			for (int i = 0; i < instances.length; i++)
				addInstance(instances[i], root);
		}
		
		setRoot(root);
	}
	
	private DefaultMutableTreeNode createInstanceNode(ArcturusInstance instance) throws NamingException {
		DirContext context = instance.getDirContext();

		DefaultMutableTreeNode instanceNode = new InstanceNode(context,
				instance.getName());

		addChildNodes(context, instanceNode, instance);	
		
		return instanceNode;
	}

	private void addInstance(ArcturusInstance instance,
			DefaultMutableTreeNode root) throws NamingException {
		DefaultMutableTreeNode instanceNode = createInstanceNode(instance);

		root.add(instanceNode);
	}

	private void addChildNodes(DirContext context,
			DefaultMutableTreeNode root, ArcturusInstance instance) throws NamingException {
		Vector<OrganismTreeNode> children = new Vector<OrganismTreeNode>();

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
						(DataSource) object, instance);
				children.add(new OrganismNode(organism));
			} else if (object instanceof DirContext) {
				InstanceNode node = new InstanceNode((DirContext) object,
						name);
				children.add(node);

				addChildNodes((DirContext) object, node, instance);
			} else
				Arcturus.logWarning(
						"Expecting a DataSource or Context, got a "
								+ object.getClass().getName(),
						new Exception("Unexpected LDAP entry"));
		}

		Collections.sort(children, comparator);

		for (OrganismTreeNode node : children)
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
