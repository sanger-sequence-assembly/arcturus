package uk.ac.sanger.arcturus.test;

import java.util.Properties;

import javax.naming.NamingException;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.utils.LDAPSocketFactory;

public class TestLDAPSocketFactory {	
	public static void main(String[] args) {
		Properties props = Arcturus.getProperties();
		
		String serverName = System.getProperty("java.naming.provider.url",
				"ldap://ldapfoo.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk");
		
		props.put("java.naming.provider.url",serverName);

		props.put("java.naming.ldap.factory.socket", "uk.ac.sanger.arcturus.utils.LDAPSocketFactory");
		
		LDAPSocketFactory factory = (LDAPSocketFactory) LDAPSocketFactory.getDefault();		
		factory.setDebugging(true);

		try {
			@SuppressWarnings("unused")
			DirContext rootcontext = new InitialDirContext(props);
		} catch (NamingException e) {
			e.printStackTrace();
			System.exit(1);
		}
		
		System.exit(0);
	}

}
