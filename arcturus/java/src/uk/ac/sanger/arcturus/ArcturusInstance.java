package uk.ac.sanger.arcturus;

import javax.naming.*;
import javax.naming.directory.*;
import java.util.*;
import java.sql.*;
import javax.sql.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Organism;

/**
 * This class represents an Arcturus instance, which is a set of Arcturus
 * databases whose details are stored as DataSource objects in an LDAP
 * directory.
 */

public class ArcturusInstance implements Iterator {
	protected final DirContext context;
	protected final String name;

	/**
	 * Constructs an Arcturus instance using LDAP parameters specified from the
	 * Arcturus global properties.
	 * 
	 * @param name
	 *            the name of the LDAP sub-directory, relative to the root
	 *            context specified via the java.naming.provider.url system
	 *            property.
	 */

	protected ArcturusInstance(String name) throws NamingException {
		this(null, name);
	}

	/**
	 * Constructs an Arcturus instance using LDAP parameters specified in the
	 * given Properties.
	 * 
	 * @param props
	 *            the Properties object which contains the LDAP parameters
	 *            java.naming.provider.url and java.naming.factory.initial. If
	 *            this is null, then the Arctrus global properties will be used
	 *            instead.
	 * 
	 * @param name
	 *            the name of the LDAP sub-directory, relative to the root
	 *            context specified via the java.naming.provider.url property.
	 */

	protected ArcturusInstance(Properties props, String name)
			throws NamingException {
		if (props == null)
			props = Arcturus.getProperties();

		DirContext rootcontext = new InitialDirContext(props);

		context = (name == null) ? rootcontext : (DirContext) rootcontext
				.lookup("cn=" + name);

		this.name = name;
	}

	/**
	 * Returns an Arcturus instance using LDAP parameters specified from the
	 * Arcturus global properties.
	 * 
	 * @param name
	 *            the name of the LDAP sub-directory, relative to the root
	 *            context specified via the java.naming.provider.url system
	 *            property.  If this is null, then the Arcturus global properties
	 *            arcturus.instance or arcturus.default.instance will be examined.
	 *            If either of these properties is defined, it will be used.
	 *            Otherwise, null is returned.
	 * 
	 * @return a new ArcturusInstance object.
	 */

	public static ArcturusInstance getInstance(String name)
			throws NamingException {
		if (name == null)
			name = Arcturus.getProperty("arcturus.instance");

		if (name == null)
			name = Arcturus.getProperty("arcturus.default.instance");

		if (name == null)
			return null;
		
		Properties arcturusProps = Arcturus.getProperties();

		return new ArcturusInstance(arcturusProps, name);
	}
	
	/**
	 * Returns an ArcturusInstance object using the name defined in either
	 * the arcturus.instance or arcturus.default.instance global properties.
	 * If neither of these is defined, null is returned.
	 * 
	 * @return a new ArcturusInstance object.
	 * @throws NamingException
	 */
	public static ArcturusInstance getDefaultInstance() throws NamingException {
		return getInstance(null);
	}

	/**
	 * Returns the name which was used to create this object.
	 * 
	 * @return the name which was used to create this object.
	 */

	public String getName() {
		return name;
	}

	/**
	 * Creates a new Arcturus database object by searching the instance's LDAP
	 * directory for an entry whose CN matches the specified name.
	 * 
	 * @param name
	 *            the name of the entry in the instance's LDAP directory.
	 * 
	 * @return a new ArcturusDatabase object.
	 */

	public ArcturusDatabase findArcturusDatabase(String name)
			throws NamingException, SQLException {
		if (name == null)
			return null;
		
		String cn = "cn=" + name;

		DataSource ds = (DataSource) context.lookup(cn);

		String description = getDescription(name);

		return new ArcturusDatabase(ds, description, name);
	}
	
	/**
	 * Creates a new ActurusDatabase object using the organism name specified
	 * in the Arcturus global property "arcturus.organism".  If this property is
	 * not defined, then null is returned.
	 * 
	 * @return a new ArcturusDatabase object.
	 * @throws NamingException
	 * @throws SQLException
	 */
	
	public ArcturusDatabase getDefaultDatabase()
		throws NamingException, SQLException {
		String organism = Arcturus.getProperty("arcturus.organism");

		return findArcturusDatabase(organism);
	}

	private String getDescription(String name) throws NamingException {
		String cn = name.startsWith("cn=") ? name : "cn=" + name;

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

	protected NamingEnumeration ne;
	ArcturusDatabase nextADB;

	/**
	 * Returns an iterator which allows client programs to iterate over all of
	 * the Arcturus database objects in this instance's LDAP directory.
	 * 
	 * @return an iterator, which is actually a reference to the current object.
	 */

	public Iterator iterator() {
		try {
			ne = context.listBindings("");
			nextADB = getNextADB(ne);
		} catch (NamingException ne) {
			ne = null;
			nextADB = null;
		} catch (SQLException sqle) {
			ne = null;
			nextADB = null;
		}

		return this;
	}

	/**
	 * When this object is being used as an Iterator, returns true if there are
	 * more Arcturus database objects to iterate over.
	 * 
	 * @return true if there are more Arcturus database objects to iterate over,
	 *         false otherwise.
	 */

	public boolean hasNext() {
		return (nextADB != null);
	}

	/**
	 * When this object is being used as an Iterator, returns the next Arcturus
	 * database object.
	 * 
	 * @return the next Arcturus database object in this instance. The value can
	 *         be cast to an ArcturusDatabase.
	 */

	public Object next() throws NoSuchElementException {
		if (nextADB == null)
			throw new NoSuchElementException();

		ArcturusDatabase adb = nextADB;

		try {
			nextADB = getNextADB(ne);
		} catch (NamingException ne) {
			nextADB = null;
		} catch (SQLException sqle) {
			nextADB = null;
		}

		return (Object) adb;
	}

	/**
	 * This method is mandated by the Iterator interface, but it is not
	 * implemented.
	 * 
	 * @throws UnsupportedOperationException
	 *             in all circumstances. Use the deleteArcturusDatabase method
	 *             instead.
	 */

	public void remove() throws UnsupportedOperationException {
		throw new UnsupportedOperationException(
				"Use deleteArcturusDatabase(String name) instead");
	}

	private ArcturusDatabase getNextADB(NamingEnumeration ne)
			throws NamingException, SQLException {
		while (ne != null && ne.hasMore()) {
			Binding bd = (Binding) ne.next();

			String name = bd.getName();

			int i = name.indexOf('=');

			if (i >= 0)
				name = name.substring(i + 1);

			Object object = bd.getObject();

			if (object instanceof DataSource) {
				String description = getDescription(name);

				return new ArcturusDatabase((DataSource) object, description,
						name);
			}
		}

		return null;
	}

	/**
	 * Returns a Vector of all of the organisms in this instance.
	 * 
	 * @return a Vector of all of the organisms in this instance.
	 */

	public Vector getAllOrganisms() throws NamingException {
		NamingEnumeration enumeration = context.listBindings("");

		if (enumeration == null)
			return null;

		Vector zoo = new Vector();

		while (enumeration.hasMore()) {
			Binding bd = (Binding) enumeration.next();

			String name = bd.getName();

			int i = name.indexOf('=');

			if (i >= 0)
				name = name.substring(i + 1);

			Object object = bd.getObject();

			if (object instanceof DataSource) {
				String description = getDescription(name);

				if (description != null)
					zoo
							.add(new Organism(name, description,
									(DataSource) object));
			}
		}

		return zoo;
	}

	/**
	 * Adds a new Arcturus database to this instance's LDAP directory.
	 * 
	 * @param adb
	 *            the Arcturus database which is to be added.
	 * 
	 * @param name
	 *            the CN name of the new entry. If an entry exists with this
	 *            name, it will be superseded by the new entry.
	 */

	public void putArcturusDatabase(ArcturusDatabase adb, String name)
			throws NamingException {
		String cn = "cn=" + name;

		String description = adb.getDescription();

		BasicAttributes attrs = (description == null) ? null
				: new BasicAttributes("description", description);

		DataSource ds = adb.getDataSource();

		try {
			context.bind(cn, ds, attrs);
		} catch (NameAlreadyBoundException nabe) {
			context.rebind(cn, ds, attrs);
		}
	}

	/**
	 * Returns a string representation of the object, in a format suitable for
	 * printing.
	 * 
	 * @return a string representation of the object.
	 */

	public String toString() {
		return "ArcturusInstance[name=" + name + "]";
	}
}
