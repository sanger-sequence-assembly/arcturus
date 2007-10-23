package uk.ac.sanger.arcturus.jobrunner;

import java.io.*;

public class JobPlacer {
	private String[] command = new String[3];

	public JobPlacer(String prefix, String host, String cmd) {

		command[0] = prefix;
		command[1] = host;
		command[2] = cmd;
	}

	public static final int INVALID = 9999;

	private int rc = INVALID;
	private Runtime runtime = Runtime.getRuntime();

	public String findHost() throws IOException {
		rc = INVALID;

		Process process = runtime.exec(command);

		BufferedReader br = new BufferedReader(new InputStreamReader(process
				.getInputStream()));

		String host = null;
		String line;

		while ((line = br.readLine()) != null) {
			if (host == null)
				host = line;
		}

		try {
			rc = process.waitFor();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}

		return rc == 0 ? host : null;
	}

	public int getExitValue() {
		return rc;
	}
}
