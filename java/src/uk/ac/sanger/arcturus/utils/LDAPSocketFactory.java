package uk.ac.sanger.arcturus.utils;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import javax.net.SocketFactory;

import uk.ac.sanger.arcturus.Arcturus;

public class LDAPSocketFactory extends SocketFactory {
	private static final LDAPSocketFactory instance = new LDAPSocketFactory();
	
	private boolean debug = Arcturus.getBoolean("LDAPSocketFactory.debug");
	
	public void setDebugging(boolean debug) {
		this.debug = debug;
	}
	
	public boolean isDebugging() {
		return debug;
	}
	
	public static SocketFactory getDefault() {
		return instance;
	}
	
	public Socket createSocket(String host, int port) throws IOException,
			UnknownHostException {
		return createSocket(host, port, null, 0);
	}

	public Socket createSocket(String host, int port, InetAddress localAddr, int localPort)
			throws IOException, UnknownHostException {
		if (debug)
			System.err.println("LDAPSocketFactory\n\tcreateSocket(" + host + ", " + port + 
					", " + localAddr + ", " + localPort + ")");

		InetAddress[] addrs = InetAddress.getAllByName(host);
		
		if (debug)
			System.err.println("\t" + host + " resolves to " + addrs.length + " IP addresses");
		
		String errors = null;
		
		for (InetAddress addr : addrs) {
			try {
				if (debug)
					System.err.println("\t" + "Trying " + addr);
				
				Socket socket = (localAddr == null) ?
						new Socket(addr, port) : new Socket(addr, port, localAddr, localPort);
				
				if (socket != null)
					return socket;
			}
			catch (IOException ioe) {
				if (errors == null)
					errors = "";
				
				String message = "A " + ioe.getClass().getName() + " occurred when trying to connect to " +
				addr + " : " + ioe.getMessage();
				
				errors += message + "\n";
				
				if (debug)
					System.err.println("\t" + message);
			}
		}
		
		throw new IOException(errors);
	}

	public Socket createSocket(InetAddress addr, int port) throws IOException {
		return new Socket(addr, port);
	}

	public Socket createSocket(InetAddress host, int port, InetAddress localAddr,
			int localPort) throws IOException {
		return new Socket(host, port, localAddr, localPort);
	}
}
