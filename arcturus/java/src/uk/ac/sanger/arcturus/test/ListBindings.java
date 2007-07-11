package uk.ac.sanger.arcturus.test;

import java.util.*;
import javax.naming.*;
import javax.naming.directory.*;

public class ListBindings {
	public void run() throws NamingException {
		Properties props = new Properties();
		
		props.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		props.put(Context.PROVIDER_URL, "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk");

		DirContext rootctx = new InitialDirContext(props);
		
		enumerate("", rootctx);
	}
	
	private void enumerate(String prefix, Context context) throws NamingException {
		System.out.println(prefix + "Enumerating " + context);
		
		prefix += "\t";
		
		NamingEnumeration ne = context.listBindings("");
		
		while (ne != null && ne.hasMore()) {
			Binding bd = (Binding) ne.next();
			
			String name = bd.getName();
			
			Object object = bd.getObject();
			
			System.out.println(prefix + name + " --> " + object);
			
			if (object instanceof Context)
				enumerate(prefix, (Context)object);
		}
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
