package uk.ac.sanger.arcturus.test;

import java.util.*;
import javax.naming.*;
import javax.naming.directory.*;

import com.mysql.jdbc.jdbc2.optional.MysqlDataSource;

public class ListBindings {
	public void run() throws NamingException {
		Properties props = new Properties();
		
		props.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		props.put(Context.PROVIDER_URL, "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk");

		DirContext rootctx = new InitialDirContext(props);
		
		boolean useListBindings = Boolean.getBoolean("useListBindings");
		
		if (useListBindings)
			enumerate("", rootctx);
		else {
			System.out.println("Enumerating root context");
			enumerate2("", rootctx);
		}
	}
	
	private void enumerate(String prefix, DirContext context) throws NamingException {
		System.out.println(prefix + "Enumerating " + context);
		
		prefix += "\t";
		
		NamingEnumeration ne = context.listBindings("");
		
		while (ne != null && ne.hasMore()) {
			Binding bd = (Binding) ne.next();
			
			String name = bd.getName();
			
			Object object = bd.getObject();
			
			System.out.println(prefix + name + " --> " + object);
			
			if (object instanceof DirContext)
				enumerate(prefix, (DirContext)object);
		}
	}
	
	private void enumerate2(String prefix, DirContext context) throws NamingException {
		prefix += "\t";
		
		String filter = "(cn=*)";
		
		SearchControls cons = new SearchControls();
		
		cons.setReturningObjFlag(true);
		cons.setSearchScope(SearchControls.ONELEVEL_SCOPE);
		cons.setDerefLinkFlag(true);
		
		NamingEnumeration<SearchResult> ne = context.search("", filter, cons);
		
		while (ne != null && ne.hasMore()) {
			SearchResult res = ne.next();
			
			Object object = res.getObject();
			
			Attributes attrs = res.getAttributes();
			
			String cn = getStringAttribute(attrs, "cn");
			
			String description = getStringAttribute(attrs, "description");

			String objstr;
			
			if (object instanceof DirContext)
				objstr = "DirContext";
			else if (object instanceof MysqlDataSource) {
				MysqlDataSource ds = (MysqlDataSource)object;
				
				objstr = "DataSource[host=" + ds.getServerName() + ", port=" + ds.getPortNumber() +
					", database=" + ds.getDatabaseName() + "]";
			} else
				objstr = object.toString();

			System.out.println(prefix + cn +
					(description == null ? "" : " \"" + description + "\"") +
					" --> " + objstr);
			
			if (object instanceof DirContext)
				enumerate2(prefix, (DirContext)object);
		}
	}
	
	private String getStringAttribute(Attributes attrs, String key) throws NamingException {
		Attribute attr = attrs.get(key);
		
		if (attr == null)
			return null;
		
		Object value = attr.get();
		
		return (value instanceof String) ? (String)value : value.toString();
	}
	
	public static void main(String[] args) {
		ListBindings lb = new ListBindings();
		
		try {
			lb.run();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
