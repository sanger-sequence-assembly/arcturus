package uk.ac.sanger.arcturus;

import javax.naming.*;
import javax.naming.directory.*;
import java.util.*;
import java.sql.*;
import javax.sql.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ArcturusInstance implements Iterator {
    protected final DirContext context;
    protected final String name;

    public ArcturusInstance(String name) throws NamingException {
	this(null, name);
    }

    public ArcturusInstance(Properties props, String name)
	throws NamingException {
	if (props == null)
	    props = System.getProperties();

	DirContext rootcontext = new InitialDirContext(props);

	context = (name == null) ? rootcontext : (DirContext)rootcontext.lookup("cn=" + name);

	this.name = name;
    }

    public ArcturusDatabase findArcturusDatabase(String name)
	throws NamingException {
	String cn = "cn=" + name;

	DataSource ds = (DataSource)context.lookup(cn);

	String description = getDescription(name);

	return new ArcturusDatabase(ds, description, name);
    }

    private String getDescription(String name) throws NamingException {
	String cn = name.startsWith("cn=") ? name : "cn=" + name;

	String attrnames[] = {"description"};

	Attributes attrs = context.getAttributes(cn, attrnames);

	Attribute description = attrs.get(attrnames[0]);

	String desc = null;

	try {
	    desc = (String)description.get();
	}
	catch (NoSuchElementException nsee) {}

	return desc;
    }

    protected NamingEnumeration ne;
    ArcturusDatabase nextADB;

    public Iterator iterator() {
	try {
	    ne = context.listBindings("");
	    nextADB = getNextADB(ne);
	}
	catch (NamingException ne) {
	    ne = null;
	    nextADB = null;
	}

	return this;
    }

    public boolean hasNext() {
	return (nextADB != null);
    }

    public Object next() throws NoSuchElementException {
	if (nextADB == null)
	    throw new NoSuchElementException();

	ArcturusDatabase adb = nextADB;

	try {
	    nextADB = getNextADB(ne);
	}
	catch (NamingException ne) {
	    nextADB = null;
	}

	return (Object)adb;
    }

    public void remove() throws UnsupportedOperationException {
	throw new UnsupportedOperationException("Use deleteArcturusDatabase(String name) instead");
    }

    private ArcturusDatabase getNextADB(NamingEnumeration ne) throws NamingException {
	while (ne != null && ne.hasMore()) {
	    Binding bd = (Binding)ne.next();

	    String name = bd.getName();

	    int i = name.indexOf('=');

	    if (i >= 0)
		name = name.substring(i + 1);

	    Object object = bd.getObject();

	    if (object instanceof DataSource) {
		String description = getDescription(name);

		return new ArcturusDatabase((DataSource)object, description, name);
	    }
	}

	return null;
    }

    public void putArcturusDatabase(ArcturusDatabase adb, String name) throws NamingException {
	String cn = "cn=" + name;

	String description = adb.getDescription();

	BasicAttributes attrs = (description == null) ? null : new BasicAttributes("description", description);

	DataSource ds = adb.getDataSource();

	try {
	    context.bind(cn, ds, attrs);
	}
	catch (NameAlreadyBoundException nabe) {
	    context.rebind(cn, ds, attrs);
	}
    }

    public String toString() { return "ArcturusInstance[name=" + name + "]"; }
}
