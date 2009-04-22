package uk.ac.sanger.arcturus.jobrunner;

import com.trilead.ssh2.*;
import java.io.File;
import java.io.IOException;

public class SSHConnection {
	public static Connection getConnection(String hostname) throws IOException {
		Connection conn = new Connection(hostname);

		conn.connect();

		File home = new File(System.getProperty("user.home"));
		
		// We should also look in the "My Documents" folder on Windows systems,
		// as the user may have mistakenly installed the key file there.
		File mydocs = new File(home, "My Documents");

		File sshdir1 = new File(home, ".ssh");
		File sshdir2 = new File(mydocs, ".ssh");

		File[] sshdir = { sshdir1, sshdir2 };

		String keyfilePass = null;
		String username = System.getProperty("user.name");

		String[] pkfiles = { "id_dsa", "id_rsa" };

		File keyfile = null;

		for (int j = 0; j < sshdir.length; j++) {
			for (int i = 0; i < pkfiles.length; i++) {
				keyfile = new File(sshdir[j], pkfiles[i]);

				if (keyfile.exists()) {
					if (conn.authenticateWithPublicKey(username, keyfile,
							keyfilePass))
						return conn;
				} else
					keyfile = null;
			}
		}

		conn.close();

		if (keyfile == null)
			throw new IOException(
					"Could not find any key files to to authenticate an SSH connection.");
		else
			throw new IOException("Found a key file ("
					+ keyfile.getAbsolutePath()
					+ "), but failed to authenticate an SSH connection.");
	}
}
