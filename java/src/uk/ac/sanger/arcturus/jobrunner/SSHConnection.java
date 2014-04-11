// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
		
		String message = "Failed to get an SSH connection.\n";

		for (int j = 0; j < sshdir.length; j++) {
			for (int i = 0; i < pkfiles.length; i++) {
				keyfile = new File(sshdir[j], pkfiles[i]);
				
				message += "Checking " + keyfile + " : ";

				if (keyfile.exists()) {
					try {
						if (conn.authenticateWithPublicKey(username, keyfile,
								keyfilePass))
							return conn;
						else
							message += "cannot authenticate with this key.\n";
					}
					catch (IOException ioe) {
						message += "encountered an exception of type " + ioe.getClass().getName() +
							" (" + ioe.getMessage() + ")\n";
					}
				} else {
					message += "does not exist.\n";
					keyfile = null;
				}
			}
		}

		conn.close();
		
		throw new IOException(message);

		/*
		if (keyfile == null)
			throw new IOException(
					"Could not find any key files to to authenticate an SSH connection.");
		else
			throw new IOException("Found a key file ("
					+ keyfile.getAbsolutePath()
					+ "), but failed to authenticate an SSH connection.");
		*/
	}
}
