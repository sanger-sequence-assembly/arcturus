package uk.ac.sanger.arcturus.jobrunner;

import com.trilead.ssh2.*;
import java.io.File;
import java.io.IOException;

public class SSHConnection {
	public static Connection getConnection(String hostname) throws IOException {
		Connection conn = new Connection(hostname);

		conn.connect();

		boolean isAuthenticated = false;

		File home = new File(System.getProperty("user.home"));
		File sshdir = new File(home, ".ssh");
		
		String keyfilePass = null;
		String username = System.getProperty("user.name");
		
		String[] pkfiles = { "id_dsa", "id_rsa" };
		
		for (int i = 0; i < pkfiles.length && !isAuthenticated; i++) {
			File keyfile = new File(sshdir, pkfiles[i]);
			
			System.err.println("Trying keyfile " + keyfile.getAbsolutePath());
			
			if (keyfile.exists())
				isAuthenticated = conn.authenticateWithPublicKey(username, keyfile,
						keyfilePass);
		}

		if (isAuthenticated == false)
			throw new IOException("Authentication failed.");
		
		return conn;
	}
}
