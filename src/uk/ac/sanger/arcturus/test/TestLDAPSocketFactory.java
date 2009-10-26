package uk.ac.sanger.arcturus.test;

import java.util.Properties;

import javax.naming.NamingException;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;

import uk.ac.sanger.arcturus.Arcturus;

public class TestLDAPSocketFactory {	
	public static void main(String[] args) {
		Properties props = Arcturus.getProperties();

		try {
			@SuppressWarnings("unused")
			DirContext rootcontext = new InitialDirContext(props);
		} catch (NamingException e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

}
