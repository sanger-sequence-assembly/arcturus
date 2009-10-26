package uk.ac.sanger.arcturus.utils;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import javax.net.SocketFactory;

public class LDAPSocketFactory extends SocketFactory {
	private static final LDAPSocketFactory instance = new LDAPSocketFactory();
	
	private boolean debug = true;
	
	public void setDebugging(boolean debug) {
		this.debug = debug;
	}
	
	public boolean isDebugging() {
		return debug;
	}
	
	public static SocketFactory getDefault() {
		return instance;
	}
	
	public Socket createSocket() throws IOException {
		return super.createSocket();
	}
	
	public Socket createSocket(String host, int port) throws IOException,
			UnknownHostException {
		if (debug)
			System.err.println("LDAPSocketFactory.createSocket(" + host + ", " + port + ")");
		
		InetAddress[] addrs = InetAddress.getAllByName(host);
		
		if (debug)
			System.err.println(host + " resolves to " + addrs.length + " IP addresses");
		
		String errors = null;
		
		for (InetAddress addr : addrs) {
			try {
				if (debug)
					System.err.println("Trying " + addr);
				
				Socket socket = new Socket(addr, port);
				if (socket != null)
					return socket;
			}
			catch (IOException ioe) {
				if (errors == null)
					errors = "";
				
				errors += "A " + ioe.getClass().getName() + " occurred when trying to connect to " +
					addr + " : " + ioe.getMessage() + "\n";
			}
		}
		
		throw new IOException(errors);
	}

	public Socket createSocket(InetAddress addr, int port) throws IOException {
		return new Socket(addr, port);
	}

	public Socket createSocket(String host, int port, InetAddress localAddr, int localPort)
			throws IOException, UnknownHostException {
		if (debug)
			System.err.println("LDAPSocketFactory.createSocket(" + host + ", " + port + ")");

		InetAddress[] addrs = InetAddress.getAllByName(host);
		
		if (debug)
			System.err.println(host + " resolves to " + addrs.length + " IP addresses");
		
		String errors = null;
		
		for (InetAddress addr : addrs) {
			try {
				Socket socket = new Socket(addr, port, localAddr, localPort);
				if (socket != null)
					return socket;
			}
			catch (IOException ioe) {
				if (errors == null)
					errors = "";
				
				errors += "A " + ioe.getClass().getName() + " occurred when trying to connect to " +
					addr + " : " + ioe.getMessage() + "\n";				
			}
		}
		
		throw new IOException(errors);
	}

	public Socket createSocket(InetAddress host, int port, InetAddress localAddr,
			int localPort) throws IOException {
		return new Socket(host, port, localAddr, localPort);
	}
}
