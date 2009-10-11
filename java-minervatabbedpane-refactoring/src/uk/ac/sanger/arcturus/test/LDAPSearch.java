package uk.ac.sanger.arcturus.test;

import java.util.*;
import javax.naming.*;
import javax.naming.directory.*;

import com.mysql.jdbc.jdbc2.optional.MysqlDataSource;

public class LDAPSearch {
	private DirContext rootctx;
	
	public LDAPSearch(Properties props) throws NamingException {
		rootctx = new InitialDirContext(props);
	}
	
	public void run(String ctxname, String key) throws NamingException {
		SearchControls controls = new SearchControls();
		
		controls.setReturningObjFlag(true);
		controls.setSearchScope(SearchControls.SUBTREE_SCOPE);
		controls.setDerefLinkFlag(true);
		
		String filter = "(&(objectClass=javaNamingReference)(" + key + "))";
		
		NamingEnumeration<SearchResult> ne = rootctx.search(ctxname, filter, controls);
		
		while (ne.hasMore()) {
			SearchResult res = ne.next();
			
			String classname = res.getClassName();
			
			Object obj = res.getObject();
			
			String name = res.getName();
			
			System.out.println("Name:\t\t" + name);
			System.out.println("Classname:\t" + classname);
			System.out.println("isRelative:\t" + (res.isRelative() ? "yes" : "no"));
			
			Attributes attrs = res.getAttributes();
			
			Attribute attr = attrs.get("cn");
			
			if (attr != null) {
				Object value = attr.get();
				System.out.println("cn:\t\t" + value);
			}
			
			attr = attrs.get("description");
			
			if (attr != null) {
				Object value = attr.get();
				System.out.println("Description:\t" + value);
			}
			 
			if (obj != null && obj instanceof MysqlDataSource) {
				MysqlDataSource ds = (MysqlDataSource)obj;
				
				System.out.println("Host:\t\t" + ds.getServerName());
				System.out.println("Port:\t\t" + ds.getPortNumber());
				System.out.println("Database:\t" + ds.getDatabaseName());
			}
			
			System.out.println();
		}
	}
	
	public static void main(String[] args) {
		String ctxname = null;
		String key = null;
		String url = null;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-name"))
				ctxname = args[++i];
			else if (args[i].equalsIgnoreCase("-key"))
				key = args[++i];
			else if (args[i].equalsIgnoreCase("-url"))
				url = args[++i];
			else
				System.err.println("Unknown option: \"" + args[i] + "\"");
		}
		
		if (ctxname == null)
			ctxname = "";
		
		if (url == null)
			url = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";
		
		if (key == null) {
			System.err.println("Usage: LDAPSearch -key key [-name ctxname] [-url url]");
			System.exit(1);
		}
		
		Properties props = new Properties();
		
		props.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		props.put(Context.PROVIDER_URL, url);
		
		try {
			LDAPSearch ls = new LDAPSearch(props);
			ls.run(ctxname, key);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

}
