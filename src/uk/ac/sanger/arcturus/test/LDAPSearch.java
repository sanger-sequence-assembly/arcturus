package uk.ac.sanger.arcturus.test;

import java.util.*;
import javax.naming.*;
import javax.naming.directory.*;

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
			
			System.out.println("Name:\t" + name);
			System.out.println("Classname:\t" + classname);
			if (obj != null) {
				System.out.println(obj);
			}
			System.out.println();
		}
	}
	
	public static void main(String[] args) {
		if (args.length < 2) {
			System.err.println("Usage: LDAPSearch context-name key");
			System.exit(1);
		}
		
		String ctxname = args[0];
		String key = args[1];
		
		Properties props = new Properties();
		
		props.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		props.put(Context.PROVIDER_URL, "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk");

		
		try {
			LDAPSearch ls = new LDAPSearch(props);
			ls.run(ctxname, key);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

}
