package uk.ac.sanger.arcturus.jobrunner;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class SimpleJobRunnerClient implements JobRunnerClient {
  private String stdout="";
  private String stderr="";
  private String status ="";
  private int returnCode= 1;

  public boolean synchronous() {
    return true;
  }

  public String getStdout() {
    return stdout;
  }

  public String getStderr() {
    return stderr;
  }

  public String getStatus() {
    return status;
  }

  public int getReturnCode() {
    return returnCode;
  }

  public void appendToStdout(String text) {
    stdout += text;
  }

  public void appendToStderr(String text) {
    stderr += text;
  }

  public void setStatus(String text) {
    status += status;
  };

  public void done(int returnCode) {
    this.returnCode = returnCode;
  }

  /**
    * Short way to call a remote command and get the result string
    * to have a finest control about errors and status code, don't use this method;
   */
  public static String  executeRemoteCommand(String hostname, String workingDirectory, String command)
  throws ArcturusDatabaseException {
    SimpleJobRunnerClient client = new SimpleJobRunnerClient();
    JobRunner runner = new JobRunner(hostname, workingDirectory, command, client);

    try {
      runner.execute();
      runner.get();

      if (client.getReturnCode() == 0 || (client.getReturnCode() == 9999 && client.getStderr().length() == 0)) //9999 = return code was null ???
        return client.getStdout();
    }
    catch (InterruptedException ex) {
      throw new ArcturusDatabaseException(ex, "Interruption exception occured while running command [" + command + "]");
    }
    catch (java.util.concurrent.ExecutionException ex) {
      throw new ArcturusDatabaseException(ex, "exception occured while running command [" + command + "] + [" + ex.toString() + "]");
    }

    // We shouldn't be there
    throw new ArcturusDatabaseException(null, "error occured while running command [" + command + "]\nerror = ["+client.getStderr() +"]\nstatus= [" + client.getStatus() + "]\nout= [ " + client.getStdout() + "]\nerror code = " + client.getReturnCode()    );

  }
}
