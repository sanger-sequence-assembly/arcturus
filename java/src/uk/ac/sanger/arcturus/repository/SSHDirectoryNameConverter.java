package uk.ac.sanger.arcturus.repository;
import uk.ac.sanger.arcturus.jobrunner.SimpleJobRunnerClient;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

/** 
  * This class implement a DirectoryNameConverter using `pfind` via ssh
  */

public class SSHDirectoryNameConverter implements DirectoryNameConverter {
  private String instanceName;

  public SSHDirectoryNameConverter(String instanceName) {
    this.instanceName = instanceName;
  }
  public String convertMetaDirectoryToAbsolutePath (String organismName, String projectName, String metaDirectoryName) throws ArcturusDatabaseException {

		final String host = Arcturus.getProperty("jobplacer.host");
		final String utilsDir = System.getProperty("arcturus.home", "/software/arcturus") + "/utils/";
    final String shellcommand = utilsDir + "convertprojectdirectory ";
    final String command = shellcommand + " -instance " + instanceName +
                                          " -organism " + organismName +
                                          " -project " + projectName +
                                          " -metadir " + metaDirectoryName +""; 

    String result =  SimpleJobRunnerClient.executeRemoteCommand(host, null, command);

    return result;
  }

  public String convertAbsolutePathToMetaDirectory (String organismName, String projectName, String absolutePath) throws ArcturusDatabaseException {
		final String host = Arcturus.getProperty("jobplacer.host");
		final String utilsDir = System.getProperty("arcturus.home", "/software/arcturus") + "/utils/";
    final String shellcommand = utilsDir + "convertprojectdirectory ";
    final String command = shellcommand + " -instance " + instanceName +
                                          " -organism " + organismName +
                                          " -project " + projectName +
                                          " -directory '" + absolutePath + "'";

    String result =  SimpleJobRunnerClient.executeRemoteCommand(host,null , command);

    return result;
  }
}
