package uk.ac.sanger.arcturus.jobrunner;

import java.io.*;

import uk.ac.sanger.arcturus.Arcturus;

public class JobPlacer {
	private String[] command = new String[3];
	
	public JobPlacer() throws Exception {
		String prefix = Arcturus.getProperty("jobplacer.prefix");
		
		if (prefix == null)
			throw new Exception("Unable to find jobplacer.prefix in Arcturus properties");
		
		String host = Arcturus.getProperty("jobplacer.host");
		
		if (prefix == null)
			throw new Exception("Unable to find jobplacer.host in Arcturus properties");
		
		String cmd = Arcturus.getProperty("jobplacer.command");
		
		if (prefix == null)
			throw new Exception("Unable to find jobplacer.command in Arcturus properties");
		
		command[0] = prefix;
		command[1] = host;
		command[2] = cmd;		
	}

	public JobPlacer(String prefix, String host, String cmd) {
		command[0] = prefix;
		command[1] = host;
		command[2] = cmd;
	}

	public static final int INVALID = 9999;

	private int rc = INVALID;
	private Runtime runtime = Runtime.getRuntime();

	public String findHost() throws Exception {
		rc = INVALID;

		Process process = runtime.exec(command);

		BufferedReader br = new BufferedReader(new InputStreamReader(process
				.getInputStream()));

		String host = null;
		String line;

		while ((line = br.readLine()) != null) {
			if (host == null)
				host = line.trim();
		}

		try {
			rc = process.waitFor();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}

		if (rc == 0 && host != null)
			return host;
		else
			throw new Exception("Failed to find a host using \"" + command[2] + "\"");
	}

	public int getExitValue() {
		return rc;
	}

    public static final void main(String[] args) {
	try {
	    JobPlacer placer = new JobPlacer();
	    String host = placer.findHost();
	    System.out.println("findHost returned " + host);
	}
	catch (Exception e) {
	    e.printStackTrace();
	}
	finally {
	    System.exit(0);
	}
    }
}
