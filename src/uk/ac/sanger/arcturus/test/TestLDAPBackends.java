package uk.ac.sanger.arcturus.test;

import java.io.IOException;
import java.net.*;

public class TestLDAPBackends {
	private static final String DEFAULT_HOSTNAME = "ldap.internal.sanger.ac.uk";
	private static final int DEFAULT_PORT = 389;
	
	public static void main(String[] args) {
		TestLDAPBackends tester = new TestLDAPBackends();
		tester.run(args);
		System.exit(0);
	}
	
	public void run(String[] args) {
		String hostname = DEFAULT_HOSTNAME;
		int port = DEFAULT_PORT;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-host"))
				hostname = args[++i];
			else if (args[i].equalsIgnoreCase("-port"))
				port = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-help")) {
				System.err.println("Usage: java " + getClass().getName() + " [-host hostname] [-port port]");
				System.exit(0);
			}			
		}
		
		try {
			InetAddress[] addrs = InetAddress.getAllByName(hostname);
			
			System.out.println("Found " + addrs.length + " IP addresses for " + hostname + "\n");
			
			for (int i = 0; i < addrs.length; i++) {
				String[] words = addrs[i].toString().split("/");
				
				System.out.print("Trying port " + port + " on " + words[1] + " ... ");

				Socket socket = null;
				
				try {
					socket = new Socket(addrs[i], port);
					System.out.println("OK");
				}
				catch (IOException ioe) {
					System.out.println("FAILED: " + ioe.getClass().getName() + " : " + ioe.getMessage());
				}
				
				if (socket != null)
					socket.close();
			}
		} catch (Exception e) {
			e.printStackTrace();
		}		
	}

}
