package uk.ac.sanger.arcturus.jobrunner;

public interface JobRunnerClient {
	public void appendToStdout(String text);
	public void appendToStderr(String text);
	public void setStatus(String text);
	public void done(int returnCode);

  public boolean synchronous(); // tell wether or not the previous methods should be call in the background thread or in EventDispatcer one (false)
}
