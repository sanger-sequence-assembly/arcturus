package uk.ac.sanger.arcturus.utils;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import javax.net.SocketFactory;

public class LDAPSocketFactory extends SocketFactory {
	public Socket createSocket() throws IOException {
		System.err.println("LDAPSocketFactory.createSocket() invoked");
		return super.createSocket();
	}
	
	public Socket createSocket(String host, int port) throws IOException,
			UnknownHostException {
		System.err.println("LDAPSocketFactory.createSocket(" + host + "," + port + ") invoked");
		
		InetAddress[] addrs = InetAddress.getAllByName(host);
		String errors = null;
		
		for (InetAddress addr : addrs) {
			try {
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
		InetAddress[] addrs = InetAddress.getAllByName(host);
		String errors = null;
		
		Socket socket = null;
		
		for (InetAddress addr : addrs) {
			try {
				if (socket == null)
					socket = new Socket(addr, port, localAddr, localPort);
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
