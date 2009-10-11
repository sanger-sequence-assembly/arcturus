package uk.ac.sanger.arcturus.test;

import java.net.InetAddress;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import javax.management.MBeanServer;
import javax.management.remote.*;

public class JMXServerTest {
	public static void main(String[] args) {
		JMXServerTest tester = new JMXServerTest();

		try {
			tester.run();
		} catch (IOException ioe) {
			ioe.printStackTrace();
		}

		System.exit(0);
	}

	public void run() throws IOException {
		String hostname = InetAddress.getLocalHost().getHostName();
		
		System.err.println("InetAddress.getLocalHost().getHostName() returned " + hostname);
		
		InetAddress addr = InetAddress.getByName(hostname);
		
		System.err.println("InetAddress.getByName(" + hostname + ") returned " + addr);
		
		String url = "service:jmx:jmxmp://" + hostname + "/";
		
		System.err.println("URL is " + url);

		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();

		JMXServiceURL jurl = new JMXServiceURL(url);

		JMXConnectorServer server = JMXConnectorServerFactory
				.newJMXConnectorServer(jurl, null, mbs);

		server.start();

		jurl = server.getAddress();

		System.err.println("JMX URL is " + jurl);
	}
}
