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
		
		int foundFiles = 0;
		
		for (int i = 0; i < pkfiles.length && !isAuthenticated; i++) {
			File keyfile = new File(sshdir, pkfiles[i]);
			
			if (keyfile.exists()) {
				foundFiles++;
			
				if (conn.authenticateWithPublicKey(username, keyfile, keyfilePass))
						return conn;
			}
		}
		
		if (foundFiles == 0)
			throw new IOException("Could not find any key files to to authenticate an SSH connection.");

		if (isAuthenticated == false)
			throw new IOException("Found a key file, but failed to authenticate an SSH connection.");
		
		conn.close();
		
		return null;
	}
}
