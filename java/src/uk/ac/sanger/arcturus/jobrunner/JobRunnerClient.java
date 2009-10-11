package uk.ac.sanger.arcturus.jobrunner;

public interface JobRunnerClient {
	public void appendToStdout(String text);
	public void appendToStderr(String text);
	public void setStatus(String text);
	public void done(int returnCode);
}
