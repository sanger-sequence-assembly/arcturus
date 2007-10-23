package uk.ac.sanger.arcturus.jobrunner;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;

import javax.swing.SwingWorker;


import ch.ethz.ssh2.ChannelCondition;
import ch.ethz.ssh2.Connection;
import ch.ethz.ssh2.Session;

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
			isAuthenticated = conn.authenticateWithPublicKey(username, keyfile,
					keyfilePass);
		}

		if (isAuthenticated == false)
			throw new IOException("Authentication failed.");

		Session sess = conn.openSession();

		if (workingDirectory != null)
			command = "cd " + workingDirectory + "; " + command;

		startTime = System.currentTimeMillis();

		sess.execCommand("/bin/sh -c '" + command + "'");

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
		client.done(rc);
	}
}
