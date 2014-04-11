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

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;

import javax.swing.SwingWorker;

import com.trilead.ssh2.*;

import uk.ac.sanger.arcturus.Arcturus;

public class JobRunner extends SwingWorker<Void, JobOutput> {
	protected String hostname;

	protected String workingDirectory;

	protected String command;

	protected JobRunnerClient client;

	protected Integer rc = null;

	protected long startTime;

	public JobRunner(String hostname, String workingDirectory, String command,
			JobRunnerClient client) {
		this.hostname = hostname;
		this.workingDirectory = workingDirectory;
		this.command = command;
		this.client = client;
	}

	protected Void doInBackground() throws Exception {
		Connection conn = null;
		
		try {
			conn = SSHConnection.getConnection(hostname);
		}
		catch (IOException ioe) {
			Arcturus.logWarning("Failed to get an SSH connection", ioe);
			throw ioe;
		}

		Session sess = null;
		
		try {
			sess = conn.openSession();
		}
		catch (IOException ioe) {
			Arcturus.logWarning("Failed to open an SSH session", ioe);
			throw ioe;
		}

		if (workingDirectory != null)
			command = "cd " + workingDirectory + "; " + command;

		startTime = System.currentTimeMillis();

		try {
			sess.execCommand("/bin/sh -c '" + command + "'");
		}
		catch (IOException ioe) {
			Arcturus.logWarning("Failed to execute command \"" + command + "\" in the SSH session", ioe);
			throw ioe;
		}

		processStreams(sess);

		conn.close();

		return null;
	}

	protected void processStreams(Session sess) throws IOException {
		InputStream stdout = sess.getStdout();
		InputStream stderr = sess.getStderr();

		byte[] buffer = new byte[8192];

		while (true) {
			if ((stdout.available() == 0) && (stderr.available() == 0)) {
				/*
				 * Even though currently there is no data available, it may be
				 * that new data arrives and the session's underlying channel is
				 * closed before we call waitForCondition(). This means that EOF
				 * and STDOUT_DATA (or STDERR_DATA, or both) may be set
				 * together.
				 */

				int conditions = sess.waitForCondition(
						ChannelCondition.STDOUT_DATA
								| ChannelCondition.STDERR_DATA
								| ChannelCondition.EOF, 2000);

				/* Wait no longer than 2 seconds (= 2000 milliseconds) */

				if ((conditions & ChannelCondition.TIMEOUT) != 0) {
					long timeNow = System.currentTimeMillis();

					long runtime = timeNow - startTime;

					String text = "Running for " + (runtime/1000) + " seconds";
					JobOutput output = new JobOutput(JobOutput.STATUS, text);
					publish(output);
				}

				/*
				 * Here we do not need to check separately for CLOSED, since
				 * CLOSED implies EOF
				 */

				if ((conditions & ChannelCondition.EOF) != 0) {
					/* The remote side won't send us further data... */

					if ((conditions & (ChannelCondition.STDOUT_DATA | ChannelCondition.STDERR_DATA)) == 0) {
						/*
						 * ... and we have consumed all data in the local
						 * arrival window.
						 */
						break;
					}
				}

				/* OK, either STDOUT_DATA or STDERR_DATA (or both) is set. */

				// You can be paranoid and check that the library is not
				// going nuts:
				// if ((conditions & (ChannelCondition.STDOUT_DATA |
				// ChannelCondition.STDERR_DATA)) == 0)
				// throw new IllegalStateException("Unexpected condition
				// result (" + conditions + ")");
			}

			/*
			 * If you below replace "while" with "if", then the way the output
			 * appears on the local stdout and stder streams is more "balanced".
			 * Addtionally reducing the buffer size will also improve the
			 * interleaving, but performance will slightly suffer. OKOK, that
			 * all matters only if you get HUGE amounts of stdout and stderr
			 * data =)
			 */

			while (stdout.available() > 0) {
				int len = stdout.read(buffer);
				if (len > 0) {
					String text = new String(buffer, 0, len);
					JobOutput output = new JobOutput(JobOutput.STDOUT, text);
					publish(output);
				}
			}

			while (stderr.available() > 0) {
				int len = stderr.read(buffer);
				if (len > 0) {
					String text = new String(buffer, 0, len);
					JobOutput output = new JobOutput(JobOutput.STDERR, text);
					publish(output);
				}
			}
		}

		rc = sess.getExitStatus();

		sess.close();
	}

	protected void process(List<JobOutput> chunks) {
		for (JobOutput output : chunks)
			processOutput(output);
	}

	protected void processOutput(JobOutput output) {
		String text = output.getText();

		switch (output.getType()) {
		case JobOutput.STDOUT:
			client.appendToStdout(text);
			break;

		case JobOutput.STDERR:
			client.appendToStderr(text);
			break;

		case JobOutput.STATUS:
			client.setStatus(text);
			break;

		default:
			throw new IllegalArgumentException("Unknown type code ("
					+ output.getType() + ") for JobOutput");
		}
	}

	protected void done() {
		long timeNow = System.currentTimeMillis();

		long runtime = timeNow - startTime;

		String message = "Done"
				+ (rc != null ? " with exit code " + rc
						: " (no exit code available)") + " after " + (runtime/1000)
				+ " seconds";
		
		client.setStatus(message);
		
		int irc = rc != null ? rc.intValue() : 9999;
		
		client.done(irc);
	}
}
